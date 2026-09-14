import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/appwrite_models.dart';
import '../models/program_tree.dart';
import '../repositories/academic_repository.dart';

/// Arborescence des programmes, construite depuis les UE réellement
/// enregistrées dans `academic_courses`.
///
/// La base ne stocke ni facultés ni départements : les trois niveaux de
/// l'arborescence sont donc l'université, la filière, puis le niveau d'études.
/// Les effectifs proviennent de `academic_enrollments`, comptés par UE.
final programTreeProvider = FutureProvider<List<FacultyNode>>((ref) async {
  final repository = ref.watch(academicRepositoryProvider);
  final courses = await repository.getCourses();
  final enrollments = await repository.getEnrollmentCounts();
  return buildProgramTree(courses, enrollments);
});

/// Regroupe les UE par université > filière > niveau, puis remonte
/// l'arborescence en triant chaque niveau alphabétiquement.
List<FacultyNode> buildProgramTree(
  List<AcademicCourse> courses,
  Map<String, int> enrollments,
) {
  const unknownUniversity = 'Université non renseignée';
  const unknownProgram = 'Filière non renseignée';
  const unknownLevel = 'Niveau non renseigné';

  final grouped = <String, Map<String, Map<String, List<AcademicCourse>>>>{};
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

      departments.add(DepartmentNode(name: program, programs: nodes));
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
