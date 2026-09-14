import 'package:flutter/material.dart';

/// Une unité d'enseignement d'un programme, telle qu'elle existe dans
/// `academic_courses`.
class CurriculumModule {
  final String name;
  final String code;

  /// Type de séance (CM, TD, TP…), ou « UE » quand la base ne le précise pas.
  final String type;
  final Color typeColor;
  final int credits;

  const CurriculumModule({
    required this.name,
    required this.code,
    required this.type,
    required this.typeColor,
    required this.credits,
  });
}

/// Un niveau d'études d'une filière : la feuille de l'arborescence.
///
/// La base ne décrit pas de « programme » unique — chaque UE porte une filière
/// (`program`) et un niveau (`level`). La feuille regroupe donc les UE d'un
/// même couple filière / niveau, et les compteurs affichés sont ceux de ce
/// groupe.
class ProgramNode {
  /// Libellé du niveau, ex. « Licence 2 ».
  final String name;

  /// Filière, ex. « Informatique ».
  final String program;

  /// Code du niveau, ex. « L2 ».
  final String code;

  final int studentsCount;
  final int ueCount;

  /// Enseignants distincts intervenant sur les UE de ce niveau.
  final List<String> teachers;

  final List<CurriculumModule> modules;

  const ProgramNode({
    required this.name,
    required this.program,
    required this.code,
    required this.studentsCount,
    required this.ueCount,
    this.teachers = const [],
    this.modules = const [],
  });
}

/// Une filière au sein d'une université, qui regroupe ses niveaux.
class DepartmentNode {
  final String name;
  final List<ProgramNode> programs;

  const DepartmentNode({required this.name, required this.programs});
}

/// Une université, racine de l'arborescence.
class FacultyNode {
  final String name;
  final List<DepartmentNode> departments;

  const FacultyNode({required this.name, required this.departments});
}
