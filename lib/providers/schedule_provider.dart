import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/appwrite_models.dart';
import '../models/schedule_event.dart';
import '../models/schedule_scope.dart';
import '../repositories/academic_repository.dart';
import 'auth_provider.dart';

/// Décalage en semaines par rapport à la semaine courante : 0 = cette semaine,
/// -1 = la précédente, 1 = la suivante. Les créneaux de `academic_schedules`
/// sont hebdomadaires et se répètent, seule la date des colonnes change.
final weekOffsetProvider = StateProvider<int>((ref) => 0);

/// Choix de la barre d'outils (filière, niveau, semestre). Remis à zéro au
/// changement de compte : la sélection d'une administration ne doit pas
/// survivre à la connexion d'un étudiant.
final scheduleSelectionProvider = StateProvider<ScheduleSelection>((ref) {
  ref.watch(currentUserProvider.select((u) => u?.id));
  return const ScheduleSelection();
});

/// Périmètre de lecture : filière + niveau du profil pour un étudiant ou un
/// délégué (verrouillés), ses séances pour un enseignant, la sélection de la
/// barre d'outils pour l'administration et la plateforme.
final scheduleScopeProvider = Provider<ScheduleScope>((ref) {
  return scheduleScopeFor(
    ref.watch(currentUserProvider),
    ref.watch(scheduleSelectionProvider),
  );
});

/// Emploi du temps de la semaine affichée, reconstruit depuis Appwrite.
///
/// Aucune donnée n'est simulée : les créneaux viennent de `academic_schedules`
/// **filtrés côté serveur sur le périmètre** (index `schedule_program_level`),
/// puis joints en mémoire aux cours de `academic_courses` pour les séances
/// anciennes sans intitulé dénormalisé — une seule requête par collection,
/// pas une par créneau.
final scheduleWeekProvider = FutureProvider<ScheduleWeek>((ref) async {
  // Recalculé à chaque changement de compte : les caches du compte précédent
  // survivaient à la déconnexion.
  final user = ref.watch(currentUserProvider);
  final repository = ref.watch(academicRepositoryProvider);
  final offset = ref.watch(weekOffsetProvider);
  final scope = ref.watch(scheduleScopeProvider);

  final weekStart = _mondayOf(DateTime.now()).add(Duration(days: 7 * offset));

  if (scope.empty) {
    return ScheduleWeek(
        weekStart: weekStart, events: const [], scopeLabel: scope.label);
  }

  final loaded = await _loadScopedSchedules(repository, scope, user);
  final coursesById = {for (final course in loaded.courses) course.id: course};
  final coursesByCode = {
    for (final course in loaded.courses) course.code: course
  };

  final semesters = semestersOf(loaded.schedules);
  final schedules = scope.semester.isEmpty
      ? loaded.schedules
      : loaded.schedules
          .where((s) => s.semester.trim().toUpperCase() == scope.semester)
          .toList();

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

    // Les champs dénormalisés de la séance priment : ils décrivent ce créneau
    // précis (groupe, enseignant du TD…), le cours n'est qu'un repli.
    final title = schedule.courseName.isNotEmpty
        ? schedule.courseName
        : course?.name.isNotEmpty == true
            ? course!.name
            : (schedule.courseCode.isEmpty ? 'Cours' : schedule.courseCode);

    events.add(
      ScheduleEvent(
        title: title,
        type: _sessionType(schedule.type ?? course?.type),
        dayIndex: dayIndex,
        startHour: startHour,
        endHour: endHour,
        salle: schedule.classroom,
        enseignant: _teacherLabel(schedule, course),
        groupe: _groupLabel(schedule, course),
        description: course?.description ?? '',
      ),
    );
  }

  return ScheduleWeek(
    weekStart: weekStart,
    events: events,
    unplacedCount: unplaced,
    scopeLabel: scope.label,
    semesters: semesters,
  );
});

class _ScopedSchedules {
  final List<AcademicSchedule> schedules;
  final List<AcademicCourse> courses;
  const _ScopedSchedules(this.schedules, this.courses);
}

/// Charge séances et cours du périmètre, et rien d'autre.
Future<_ScopedSchedules> _loadScopedSchedules(
  AcademicRepository repository,
  ScheduleScope scope,
  UniFlowUser? user,
) async {
  switch (scope.kind) {
    case ScheduleScopeKind.learner:
      final courses = await repository.getCoursesFor(
          program: scope.program, level: scope.level);
      final schedules = await repository.getSchedulesFor(
          program: scope.program, level: scope.level);
      // Ceinture et bretelles : le filtre serveur est la règle, ce second
      // passage écarte tout document qui ne porterait pas le bon périmètre.
      return _ScopedSchedules(
        schedulesWithin(schedules,
            program: scope.program,
            level: scope.level,
            coursesById: {for (final c in courses) c.id: c}),
        courses,
      );

    case ScheduleScopeKind.selectable:
      final courses = await repository.getCoursesFor(
          program: scope.program,
          level: scope.level.isEmpty ? null : scope.level);
      final schedules = await repository.getSchedulesFor(
          program: scope.program,
          level: scope.level.isEmpty ? null : scope.level);
      return _ScopedSchedules(schedules, courses);

    case ScheduleScopeKind.teacher:
      if (user == null) return const _ScopedSchedules([], []);
      final courses = await repository.getCourses();
      final coursesById = {for (final c in courses) c.id: c};
      final byName =
          await repository.getSchedulesTaughtBy(nameTokens(user.name));
      final ownCourseIds = courses
          .where((c) => c.teacherId != null && c.teacherId == user.id)
          .map((c) => c.id);
      final byCourse = await repository.getSchedulesForCourses(ownCourseIds);
      final merged = <String, AcademicSchedule>{
        for (final s in byName) s.id: s,
        for (final s in byCourse) s.id: s,
      };
      return _ScopedSchedules(
        schedulesTaughtBy(merged.values,
            teacher: user, coursesById: coursesById),
        courses,
      );

    case ScheduleScopeKind.personal:
      return const _ScopedSchedules([], []);
  }
}

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

String _teacherLabel(AcademicSchedule schedule, AcademicCourse? course) {
  final own = schedule.teacherName.trim();
  if (own.isNotEmpty) return own;
  final name = course?.teacherName?.trim();
  return (name == null || name.isEmpty) ? '—' : name;
}

/// « Licence 2 · Informatique · Groupe A » : le niveau et la filière de la
/// séance (ou du cours, à défaut) et son groupe. Un champ absent est omis.
String _groupLabel(AcademicSchedule schedule, AcademicCourse? course) {
  final level = schedule.level.isNotEmpty ? schedule.level : course?.level;
  final program =
      schedule.program.isNotEmpty ? schedule.program : course?.program;
  final parts = <String>[
    if (level != null && level.isNotEmpty) directoryLevelLabel(level),
    if (program != null && program.isNotEmpty) program,
    if (schedule.group.trim().isNotEmpty) schedule.group.trim(),
  ];
  return parts.isEmpty ? '—' : parts.join(' · ');
}
