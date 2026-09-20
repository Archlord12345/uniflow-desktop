import 'appwrite_models.dart';
import 'user_role.dart';

/// Qui lit la grille, et donc ce qu'elle a le droit de montrer.
enum ScheduleScopeKind {
  /// Étudiant ou délégué : la filière et le niveau **du profil**, verrouillés.
  learner,

  /// Enseignant : uniquement ses propres séances.
  teacher,

  /// Administration d'université ou plateforme : filière et niveau choisis
  /// dans la barre d'outils.
  selectable,

  /// Compte personnel : pas d'emploi du temps universitaire.
  personal,
}

/// Choix faits dans la barre d'outils. Filière et niveau ne sont pris en
/// compte que pour un périmètre [ScheduleScopeKind.selectable] ; le semestre
/// vaut pour tout le monde.
class ScheduleSelection {
  final String program;
  final String level;
  final String semester;

  const ScheduleSelection(
      {this.program = '', this.level = '', this.semester = ''});

  ScheduleSelection copyWith(
          {String? program, String? level, String? semester}) =>
      ScheduleSelection(
        program: program ?? this.program,
        level: level ?? this.level,
        semester: semester ?? this.semester,
      );
}

/// Périmètre de lecture de l'emploi du temps.
///
/// Symptôme corrigé le 2026-09-20 : un étudiant ICT4D L1 voyait sur le desktop
/// les séances de biochimie et de botanique — la grille chargeait toute la
/// collection `academic_schedules`. Le périmètre est désormais déduit du
/// compte : un étudiant ne voit que **sa** filière et **son** niveau, et rien
/// d'autre ; si son profil n'en porte pas, il ne voit rien plutôt que tout.
class ScheduleScope {
  final ScheduleScopeKind kind;
  final String program;
  final String level;
  final String semester;

  const ScheduleScope({
    required this.kind,
    this.program = '',
    this.level = '',
    this.semester = '',
  });

  /// Filière et niveau imposés par le profil, non modifiables.
  bool get locked => kind == ScheduleScopeKind.learner;

  /// Étudiant dont le profil ne porte pas de filière **ou** pas de niveau :
  /// on n'affiche rien, et on le dit.
  bool get incomplete =>
      kind == ScheduleScopeKind.learner && (program.isEmpty || level.isEmpty);

  /// Administration sans filière choisie : la grille attend une sélection
  /// plutôt que d'empiler les centaines de séances de la faculté.
  bool get needsSelection =>
      kind == ScheduleScopeKind.selectable && program.isEmpty;

  /// Rien à charger : profil incomplet, sélection absente ou compte personnel.
  bool get empty =>
      incomplete || needsSelection || kind == ScheduleScopeKind.personal;

  /// « ICT4D · Licence 1 », « Mes séances »…
  String get label {
    switch (kind) {
      case ScheduleScopeKind.teacher:
        return 'Mes séances';
      case ScheduleScopeKind.personal:
        return 'Espace personnel';
      case ScheduleScopeKind.learner:
      case ScheduleScopeKind.selectable:
        final parts = <String>[
          if (program.isNotEmpty) program,
          if (level.isNotEmpty) directoryLevelLabel(level),
        ];
        return parts.isEmpty ? 'Toutes les filières' : parts.join(' · ');
    }
  }

  ScheduleScope copyWith({String? semester}) => ScheduleScope(
        kind: kind,
        program: program,
        level: level,
        semester: semester ?? this.semester,
      );
}

/// Périmètre d'un compte, compte tenu des choix de la barre d'outils.
ScheduleScope scheduleScopeFor(UniFlowUser? user, ScheduleSelection selection) {
  final semester = selection.semester.trim().toUpperCase();
  if (user == null) {
    return ScheduleScope(
        kind: ScheduleScopeKind.selectable, semester: semester);
  }
  if (user.isPersonal) {
    return ScheduleScope(kind: ScheduleScopeKind.personal, semester: semester);
  }
  if (user.isPlatform || user.userRole == UserRole.admin) {
    return ScheduleScope(
      kind: ScheduleScopeKind.selectable,
      program: selection.program.trim(),
      level: selection.level.trim().toUpperCase(),
      semester: semester,
    );
  }
  if (user.userRole == UserRole.teacher) {
    return ScheduleScope(kind: ScheduleScopeKind.teacher, semester: semester);
  }
  return ScheduleScope(
    kind: ScheduleScopeKind.learner,
    program: (user.program ?? '').trim(),
    level: (user.level ?? '').trim().toUpperCase(),
    semester: semester,
  );
}

/// Ne garde que les séances du périmètre. Le filtre serveur fait déjà ce
/// travail ; celui-ci rattrape les anciens documents sans `program`/`level`
/// (on lit alors la filière du cours joint) et tout ce qu'un cache aurait
/// pu mélanger.
List<AcademicSchedule> schedulesWithin(
  Iterable<AcademicSchedule> schedules, {
  required String program,
  required String level,
  Map<String, AcademicCourse> coursesById = const {},
}) {
  final wantedProgram = program.trim().toUpperCase();
  final wantedLevel = level.trim().toUpperCase();
  bool same(String a, String b) => a.trim().toUpperCase() == b;

  return schedules.where((schedule) {
    var scheduleProgram = schedule.program;
    var scheduleLevel = schedule.level;
    if (scheduleProgram.isEmpty || scheduleLevel.isEmpty) {
      final course = coursesById[schedule.courseId];
      if (course == null) return false;
      if (scheduleProgram.isEmpty) scheduleProgram = course.program;
      if (scheduleLevel.isEmpty) scheduleLevel = course.level;
    }
    if (wantedProgram.isNotEmpty && !same(scheduleProgram, wantedProgram)) {
      return false;
    }
    if (wantedLevel.isNotEmpty && !same(scheduleLevel, wantedLevel)) {
      return false;
    }
    return true;
  }).toList();
}

/// Titres et initiales qui ne distinguent personne : « Dr NKOUMOU » et
/// « Pr. Nkoumou J. » désignent la même personne.
const _ignoredNameTokens = {'dr', 'pr', 'prof', 'm', 'mme', 'mlle', 'mr'};

/// Jetons significatifs d'un nom (minuscules, sans accents ni ponctuation).
Set<String> nameTokens(String? name) {
  const accents = {
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'î': 'i',
    'ï': 'i',
    'ô': 'o',
    'ö': 'o',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
  };
  final buffer = StringBuffer();
  for (final rune in (name ?? '').toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(accents[char] ?? char);
  }
  return buffer
      .toString()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((t) => t.length >= 2 && !_ignoredNameTokens.contains(t))
      .toSet();
}

/// Séances d'un enseignant : celles de ses cours (`teacherId`) ou dont
/// `teacherName` partage un nom avec le compte — l'orthographe en base n'est
/// pas toujours celle du compte, on accepte les deux pistes.
List<AcademicSchedule> schedulesTaughtBy(
  Iterable<AcademicSchedule> schedules, {
  required UniFlowUser teacher,
  Map<String, AcademicCourse> coursesById = const {},
}) {
  final own = nameTokens(teacher.name);
  bool nameMatches(String? candidate) {
    if (own.isEmpty) return false;
    return nameTokens(candidate).any(own.contains);
  }

  return schedules.where((schedule) {
    final course = coursesById[schedule.courseId];
    if (course?.teacherId != null && course!.teacherId == teacher.id) {
      return true;
    }
    return nameMatches(schedule.teacherName) ||
        nameMatches(course?.teacherName);
  }).toList();
}

/// Semestres présents, dans l'ordre (« S1 » avant « S2 »).
List<String> semestersOf(Iterable<AcademicSchedule> schedules) {
  final values = <String>{
    for (final schedule in schedules)
      if (schedule.semester.trim().isNotEmpty)
        schedule.semester.trim().toUpperCase(),
  }.toList()
    ..sort();
  return values;
}
