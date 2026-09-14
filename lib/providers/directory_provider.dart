import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/appwrite_models.dart';
import '../models/classroom.dart';
import '../models/student.dart';
import '../models/teacher.dart';
import '../models/teaching_unit.dart';
import '../repositories/academic_repository.dart';

/// Annuaire académique Appwrite, joint aux profils `users` (pseudo, photo).
///
/// C'est la source unique des écrans « Étudiants » et « Enseignants » : ils
/// affichaient auparavant des listes codées en dur.
final directoryProvider = FutureProvider<List<AcademicDirectoryEntry>>((ref) {
  return ref.watch(academicRepositoryProvider).getDirectory();
});

/// Étudiants et délégués, vus par l'administration.
final studentsProvider = FutureProvider<List<Student>>((ref) async {
  final directory = await ref.watch(directoryProvider.future);
  return directory
      .where((entry) => entry.role == 'STUDENT' || entry.role == 'DELEGATE')
      .map(Student.fromDirectory)
      .toList();
});

final teachersProvider = FutureProvider<List<Teacher>>((ref) async {
  final directory = await ref.watch(directoryProvider.future);
  return directory
      .where((entry) => entry.role == 'TEACHER')
      .map(Teacher.fromDirectory)
      .toList();
});

/// Unités d'enseignement, lues dans `academic_courses` et complétées du nombre
/// d'inscriptions de `academic_enrollments`.
final teachingUnitsProvider = FutureProvider<List<TeachingUnit>>((ref) async {
  final repository = ref.watch(academicRepositoryProvider);
  final courses = await repository.getCourses();
  final enrollments = await repository.getEnrollmentCounts();
  return courses
      .map((course) => TeachingUnit.fromCourse(
            course,
            inscrits: enrollments[course.id] ?? 0,
          ))
      .toList();
});

/// Salles déduites de l'emploi du temps (aucune collection `classrooms`).
final classroomsProvider = FutureProvider<List<Classroom>>((ref) {
  return ref.watch(academicRepositoryProvider).getClassrooms();
});
