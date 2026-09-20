import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/appwrite_models.dart';
import '../models/schedule_event.dart';
import '../repositories/academic_repository.dart';
import 'auth_provider.dart';

/// Décalage en semaines par rapport à la semaine courante : 0 = cette semaine,
/// -1 = la précédente, 1 = la suivante. Les créneaux de `academic_schedules`
/// sont hebdomadaires et se répètent, seule la date des colonnes change.
final weekOffsetProvider = StateProvider<int>((ref) => 0);

/// Emploi du temps de la semaine affichée, reconstruit depuis Appwrite.
///
/// Aucune donnée n'est simulée : les créneaux viennent de `academic_schedules`
/// et sont joints en mémoire aux cours de `academic_courses` pour récupérer
/// l'intitulé, l'enseignant et le niveau — une seule requête par collection,
/// pas une par créneau.
final scheduleWeekProvider = FutureProvider<ScheduleWeek>((ref) async {
  // Recalculé à chaque changement de compte : les caches du compte précédent
  // survivaient à la déconnexion.
  ref.watch(currentUserProvider.select((u) => u?.id));
  final repository = ref.watch(academicRepositoryProvider);
  final offset = ref.watch(weekOffsetProvider);

  final schedules = await repository.getSchedules();
  final courses = await repository.getCourses();
  final coursesById = {for (final course in courses) course.id: course};
  final coursesByCode = {for (final course in courses) course.code: course};

  final weekStart = _mondayOf(DateTime.now()).add(Duration(days: 7 * offset));

  final events = <ScheduleEvent>[];
  var unplaced = 0;

  for (final schedule in schedules) {
    final dayIndex = _dayIndex(schedule.dayOfWeek);
    final startHour = _hourOf(schedule.startTime);
    final endHour = _hourOf(schedule.endTime);

    // Un jour ou un horaire illisible rend le créneau impossible à positionner :
    // on l'écarte et on le compte, plutôt que de le placer au hasard.
    if (dayIndex == null ||
        dayIndex >= ScheduleWeek.dayCount ||
        startHour == null ||
        endHour == null ||
        endHour <= startHour) {
      unplaced++;
      continue;
    }

    final course =
        coursesById[schedule.courseId] ?? coursesByCode[schedule.courseCode];

    events.add(
      ScheduleEvent(
        title: course?.name.isNotEmpty == true
            ? course!.name
            : (schedule.courseCode.isEmpty ? 'Cours' : schedule.courseCode),
        type: _sessionType(schedule.type ?? course?.type),
        dayIndex: dayIndex,
        startHour: startHour,
        endHour: endHour,
        salle: schedule.classroom,
        enseignant: _teacherLabel(course),
        groupe: _groupLabel(course),
        description: course?.description ?? '',
      ),
    );
  }

  return ScheduleWeek(
    weekStart: weekStart,
    events: events,
    unplacedCount: unplaced,
  );
});

/// Lundi de la semaine contenant [date], à minuit.
DateTime _mondayOf(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

/// Index de colonne (0 = lundi … 5 = samedi), ou `null` si le jour stocké
/// n'est pas reconnu.
///
/// `dayOfWeek` est une chaîne libre : selon la source, on y trouve un nom
/// français (« Lundi »), un nom anglais (« MONDAY »), une abréviation, ou un
/// numéro. Les numéros sont lus en convention ISO (1 = lundi … 7 = dimanche) :
/// le dimanche n'a pas de colonne dans la grille et ressort donc comme non
/// placé, ce que l'écran signale.
int? _dayIndex(String raw) {
  final value = raw.trim().toUpperCase();
  if (value.isEmpty) return null;

  const byName = <String, int>{
    'LUNDI': 0,
    'MONDAY': 0,
    'MON': 0,
    'LUN': 0,
    'LUN.': 0,
    'MARDI': 1,
    'TUESDAY': 1,
    'TUE': 1,
    'MAR': 1,
    'MAR.': 1,
    'MERCREDI': 2,
    'WEDNESDAY': 2,
    'WED': 2,
    'MER': 2,
    'MER.': 2,
    'JEUDI': 3,
    'THURSDAY': 3,
    'THU': 3,
    'JEU': 3,
    'JEU.': 3,
    'VENDREDI': 4,
    'FRIDAY': 4,
    'FRI': 4,
    'VEN': 4,
    'VEN.': 4,
    'SAMEDI': 5,
    'SATURDAY': 5,
    'SAT': 5,
    'SAM': 5,
    'SAM.': 5,
  };
  final named = byName[value];
  if (named != null) return named;

  final numeric = int.tryParse(value);
  if (numeric == null) return null;
  if (numeric >= DateTime.monday && numeric <= DateTime.saturday) {
    return numeric - 1;
  }
  return null;
}

/// Heure décimale (8.5 pour 08h30), ou `null` si la valeur est illisible.
///
/// Accepte « 08:00 », « 8h00 », « 08:00:00 » et les dates ISO complètes —
/// `startTime` / `endTime` sont des chaînes, leur format dépend de la source.
double? _hourOf(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;

  final match = RegExp(r'^(\d{1,2})[:hH](\d{2})').firstMatch(value);
  if (match != null) {
    final hours = int.tryParse(match.group(1)!);
    final minutes = int.tryParse(match.group(2)!);
    if (hours == null || minutes == null || hours > 23 || minutes > 59) {
      return null;
    }
    return hours + minutes / 60;
  }

  final iso = DateTime.tryParse(value);
  if (iso != null) return iso.hour + iso.minute / 60;

  return null;
}

/// Type de séance ; par défaut CM, faute de mieux lorsque la base ne le
/// renseigne pas (la colonne `type` est optionnelle).
SessionType _sessionType(String? raw) {
  switch ((raw ?? '').trim().toUpperCase()) {
    case 'TD':
      return SessionType.td;
    case 'TP':
      return SessionType.tp;
    case 'SEMINAIRE':
    case 'SÉMINAIRE':
    case 'SEMINAR':
      return SessionType.seminaire;
    default:
      return SessionType.cm;
  }
}

String _teacherLabel(AcademicCourse? course) {
  final name = course?.teacherName?.trim();
  return (name == null || name.isEmpty) ? '—' : name;
}

/// « Licence 2 · Informatique » : le niveau et la filière du cours, tels que
/// stockés. Un champ absent est simplement omis.
String _groupLabel(AcademicCourse? course) {
  if (course == null) return '—';
  final parts = <String>[
    if (course.level.isNotEmpty) directoryLevelLabel(course.level),
    if (course.program.isNotEmpty) course.program,
  ];
  return parts.isEmpty ? '—' : parts.join(' · ');
}
