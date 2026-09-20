import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/appwrite_models.dart';
import '../models/program_tree.dart';
import '../models/reference_models.dart';
import '../repositories/academic_repository.dart';
import '../repositories/reference_repository.dart';
import 'auth_provider.dart';

/// Arborescence des programmes : université > filière > niveau.
///
/// Le squelette vient du référentiel `academic_programs` (une filière et ses
/// niveaux existent même sans UE saisie — c'est ce que l'administration doit
/// voir pour préparer une rentrée), les UE et les effectifs viennent de
/// `academic_courses` et `academic_enrollments`. Les cours dont la filière
/// n'est pas au référentiel apparaissent quand même : rien n'est perdu.
final programTreeProvider = FutureProvider<List<FacultyNode>>((ref) async {
  // Recalculé à chaque changement de compte : les caches du compte précédent
  // survivaient à la déconnexion.
  ref.watch(currentUserProvider.select((u) => u?.id));
  final repository = ref.watch(academicRepositoryProvider);
  final courses = await repository.getCourses();
  final enrollments = await repository.getEnrollmentCounts();
  final reference = await ref.watch(academicReferenceProvider.future);
  return buildProgramTree(courses, enrollments, reference: reference);
});

/// Regroupe les UE par université > filière > niveau, puis remonte
/// l'arborescence en triant chaque niveau alphabétiquement.
List<FacultyNode> buildProgramTree(
  List<AcademicCourse> courses,
  Map<String, int> enrollments, {
  AcademicReference reference = const AcademicReference(),
}) {
  const unknownUniversity = 'Université non renseignée';
  const unknownProgram = 'Filière non renseignée';
  const unknownLevel = 'Niveau non renseigné';

  final grouped = <String, Map<String, Map<String, List<AcademicCourse>>>>{};
  // Squelette du référentiel : chaque filière active, avec ses niveaux
  // déclarés, sous le nom de son université.
  for (final program in reference.programs.where((p) => p.active)) {
    final university = reference.universityByCode(program.universityCode)?.name ?? program.universityCode;
    final levels = grouped
        .putIfAbsent(university, () => {})
        .putIfAbsent(program.code, () => {});
    for (final level in program.levels) {
      levels.putIfAbsent(level, () => []);
    }
  }
  for (final course in courses) {
    final university =
        course.university.trim().isEmpty ? unknownUniversity : course.university.trim();
    final program =
        course.program.trim().isEmpty ? unknownProgram : course.program.trim();
    final level = course.level.trim().isEmpty ? unknownLevel : course.level.trim();

    grouped
        .putIfAbsent(university, () => {})
        .putIfAbsent(program, () => {})
        .putIfAbsent(level, () => [])
        .add(course);
  }

  final universities = grouped.keys.toList()..sort();
  final faculties = <FacultyNode>[];

  for (final university in universities) {
    final programs = grouped[university]!;
    final programNames = programs.keys.toList()..sort();
    final departments = <DepartmentNode>[];

    for (final program in programNames) {
      final levels = programs[program]!;
      final levelCodes = levels.keys.toList()..sort();
      final nodes = <ProgramNode>[];

      for (final level in levelCodes) {
        final levelCourses = levels[level]!;
        final teachers = <String>{
          for (final course in levelCourses)
            if ((course.teacherName ?? '').trim().isNotEmpty) course.teacherName!.trim(),
        }.toList()
          ..sort();

        nodes.add(ProgramNode(
          name: directoryLevelLabel(level),
          program: program,
          code: level,
          studentsCount: levelCourses.fold<int>(
            0,
            (sum, course) => sum + (enrollments[course.id] ?? 0),
          ),
          ueCount: levelCourses.length,
          teachers: teachers,
          modules: [
            for (final course in levelCourses)
              CurriculumModule(
                name: course.name.trim().isEmpty ? course.code : course.name,
                code: course.code,
                type: _moduleType(course.type),
                typeColor: _moduleTypeColor(course.type),
                credits: course.credits ?? 0,
              ),
          ],
        ));
      }

      final referenceProgram = reference.programByCode(program);
      departments.add(DepartmentNode(
        name: referenceProgram == null || referenceProgram.name.isEmpty
            ? program
            : '${referenceProgram.name} ($program)',
        programs: nodes,
      ));
    }

    faculties.add(FacultyNode(name: university, departments: departments));
  }

  return faculties;
}

/// Libellé du type de séance ; « UE » quand la base ne le renseigne pas, pour
/// ne pas laisser une pastille vide.
String _moduleType(String? type) {
  final value = (type ?? '').trim();
  return value.isEmpty ? 'UE' : value.toUpperCase();
}

/// Teintes pastel associées aux types de séance, reprises de la charte.
Color _moduleTypeColor(String? type) {
  switch ((type ?? '').trim().toUpperCase()) {
    case 'CM':
      return const Color(0xFFDCEBFF);
    case 'TD':
      return const Color(0xFFDFF5E4);
    case 'TP':
      return const Color(0xFFFFF0DC);
    default:
      return const Color(0xFFF1E4FF);
  }
}
