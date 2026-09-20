import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/appwrite_models.dart';
import '../models/classroom.dart';
import '../models/student.dart';
import '../models/teacher.dart';
import '../models/teaching_unit.dart';
import '../repositories/academic_repository.dart';
import '../repositories/reference_repository.dart';
import 'auth_provider.dart';

/// Annuaire académique Appwrite, joint aux profils `users` (pseudo, photo).
///
/// C'est la source unique des écrans « Étudiants » et « Enseignants » : ils
/// affichaient auparavant des listes codées en dur.
final directoryProvider = FutureProvider<List<AcademicDirectoryEntry>>((ref) {
  // Recalculé à chaque changement de compte : les caches du compte précédent
  // survivaient à la déconnexion.
  ref.watch(currentUserProvider.select((u) => u?.id));
  return ref.watch(academicRepositoryProvider).getDirectory();
});

/// Inscriptions actives étudiant → cours, partagées par l'appel et les notes.
final enrollmentsProvider = FutureProvider<List<AcademicEnrollment>>((ref) {
  // Recalculé à chaque changement de compte : les caches du compte précédent
  // survivaient à la déconnexion.
  ref.watch(currentUserProvider.select((u) => u?.id));
  return ref.watch(academicRepositoryProvider).getEnrollments();
});

/// Étudiants et délégués **dans le périmètre** de l'utilisateur connecté.
///
/// L'administration voit tout ; un enseignant voit les inscrits à ses cours ;
/// un délégué sa promotion. Le filtre est appliqué ici, à la source, pour que
/// l'écran, la recherche et l'export lisent la même liste — le propriétaire a
/// demandé que « chaque utilisateur ne voie que ceux qui le concernent ».
final studentsProvider = FutureProvider<List<Student>>((ref) async {
  final directory = await ref.watch(directoryProvider.future);
  final scope = await ref.watch(visibilityScopeProvider.future);
  final all = directory
      .where((entry) => entry.role == 'STUDENT' || entry.role == 'DELEGATE')
      .toList();
  final visible = scope.filterStudents<AcademicDirectoryEntry>(
    all,
    (e) => e.userId,
    programOf: (e) => e.program,
    levelOf: (e) => e.level,
  );
  return visible.map(Student.fromDirectory).toList();
});

final teachersProvider = FutureProvider<List<Teacher>>((ref) async {
  final directory = await ref.watch(directoryProvider.future);
  final scope = await ref.watch(visibilityScopeProvider.future);
  final all = directory.where((entry) => entry.role == 'TEACHER').toList();
  return scope
      .filterTeachers<AcademicDirectoryEntry>(all, (e) => e.userId)
      .map(Teacher.fromDirectory)
      .toList();
});

/// Cours dans le périmètre : tous pour l'administration, les siens pour un
/// enseignant, ceux de sa promotion pour un apprenant.
final scopedCoursesProvider = FutureProvider<List<AcademicCourse>>((ref) async {
  final courses = await ref.watch(academicRepositoryProvider).getCourses();
  final scope = await ref.watch(visibilityScopeProvider.future);
  if (scope.seesEveryone) return courses;
  return courses.where((c) => scope.myCourseIds.contains(c.id)).toList();
});

/// Unités d'enseignement, lues dans `academic_courses` et complétées du nombre
/// d'inscriptions de `academic_enrollments`.
final teachingUnitsProvider = FutureProvider<List<TeachingUnit>>((ref) async {
  final repository = ref.watch(academicRepositoryProvider);
  final courses = await ref.watch(scopedCoursesProvider.future);
  final enrollments = await repository.getEnrollmentCounts();
  return courses
      .map((course) => TeachingUnit.fromCourse(
            course,
            inscrits: enrollments[course.id] ?? 0,
          ))
      .toList();
});

/// Salles déduites de l'emploi du temps (aucune collection `classrooms`).
/// Salles : le référentiel `classrooms` d'abord (toutes les salles déclarées,
/// occupées ou non), enrichi des créneaux d'emploi du temps ; les salles qui
/// n'apparaissent que dans un emploi du temps sont conservées.
final classroomsProvider = FutureProvider<List<Classroom>>((ref) async {
  // Recalculé à chaque changement de compte : les caches du compte précédent
  // survivaient à la déconnexion.
  ref.watch(currentUserProvider.select((u) => u?.id));
  final scheduled = await ref.watch(academicRepositoryProvider).getClassrooms();
  final reference = await ref.watch(academicReferenceProvider.future);
  if (reference.classrooms.isEmpty) return scheduled;
  final byName = {for (final room in scheduled) room.nom.toLowerCase(): room};
  final merged = <Classroom>[];
  final seen = <String>{};
  for (final room in reference.classrooms.where((r) => r.active)) {
    final usage =
        byName[room.code.toLowerCase()] ?? byName[room.name.toLowerCase()];
    seen.add(room.code.toLowerCase());
    if (usage != null) seen.add(usage.nom.toLowerCase());
    merged.add(Classroom(
      nom: room.displayName,
      creneaux: usage?.creneaux ?? 0,
      cours: usage?.cours ?? 0,
      type: room.kind,
      capacite: room.capacity,
      batiment: room.building,
      referenceId: room.id,
    ));
  }
  for (final room in scheduled) {
    if (!seen.contains(room.nom.toLowerCase())) merged.add(room);
  }
  merged.sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
  return merged;
});

/// Filières et niveaux réellement présents en base, pour les sélecteurs de
/// l'administration. Rien n'est codé en dur sur « ICT4D » ou « L1 » : d'autres
/// filières de l'UY1 vont être injectées et doivent apparaître sans mise à
/// jour de l'application.
final programOptionsProvider = FutureProvider<ProgramOptions>((ref) async {
  // Recalculé à chaque changement de compte : les caches du compte précédent
  // survivaient à la déconnexion.
  ref.watch(currentUserProvider.select((u) => u?.id));
  final courses = await ref.watch(academicRepositoryProvider).getCourses();
  return ProgramOptions.fromCourses(courses);
});

class ProgramOptions {
  final List<String> universities;
  final List<String> programs;
  final List<String> levels;

  /// Niveaux disponibles par filière.
  final Map<String, List<String>> levelsByProgram;

  const ProgramOptions({
    required this.universities,
    required this.programs,
    required this.levels,
    required this.levelsByProgram,
  });

  static const List<String> _levelOrder = ['L1', 'L2', 'L3', 'M1', 'M2', 'D'];

  static int _levelRank(String level) {
    final index = _levelOrder.indexOf(level.toUpperCase());
    return index < 0 ? _levelOrder.length : index;
  }

  factory ProgramOptions.fromCourses(List<AcademicCourse> courses) {
    final universities = <String>{};
    final programs = <String>{};
    final levels = <String>{};
    final byProgram = <String, Set<String>>{};
    for (final course in courses) {
      if (course.university.trim().isNotEmpty) {
        universities.add(course.university.trim());
      }
      if (course.program.trim().isNotEmpty) programs.add(course.program.trim());
      if (course.level.trim().isNotEmpty) levels.add(course.level.trim());
      if (course.program.trim().isNotEmpty && course.level.trim().isNotEmpty) {
        byProgram
            .putIfAbsent(course.program.trim(), () => {})
            .add(course.level.trim());
      }
    }
    List<String> sortedLevels(Iterable<String> values) {
      final list = values.toList();
      list.sort((a, b) => _levelRank(a).compareTo(_levelRank(b)));
      return list;
    }

    return ProgramOptions(
      universities: universities.toList()..sort(),
      programs: programs.toList()..sort(),
      levels: sortedLevels(levels),
      levelsByProgram: {
        for (final entry in byProgram.entries)
          entry.key: sortedLevels(entry.value),
      },
    );
  }

  bool get isEmpty => programs.isEmpty;
}
