import 'package:flutter/material.dart';

/// Un module (UE) au sein d'un semestre d'un programme.
class CurriculumModule {
  final String name;
  final String type;       // ex: "Majeur", "Outil", "Optionnel"
  final Color typeColor;
  final int credits;

  const CurriculumModule({
    required this.name,
    required this.type,
    required this.typeColor,
    required this.credits,
  });
}

/// Un semestre du curriculum d'un programme (ex: "Semestre 1 (S1)").
/// [modules] est vide tant que le semestre n'a pas été déplié — voir
/// [ProgramNode.mockSemesters] pour un exemple avec S1 rempli et S2 vide,
/// fidèle à l'état "replié" affiché sur la maquette.
class CurriculumSemester {
  final String label;         // ex: "Semestre 1 (S1)"
  final int totalModules;
  final int totalEcts;
  final List<CurriculumModule> modules;

  const CurriculumSemester({
    required this.label,
    required this.totalModules,
    required this.totalEcts,
    this.modules = const [],
  });
}

/// Un programme (ex: "Licence Informatique"), feuille de l'arborescence,
/// affiché en détail dans le panneau de droite quand sélectionné.
class ProgramNode {
  final String name;
  final String code;          // ex: "INF-LIC"
  final String id;            // ex: "INF-L-02"
  final bool isActive;
  final String niveau;        // ex: "Licence (L1, L2, L3)"
  final String duree;         // ex: "3 Ans (6 Semestres)"
  final String responsable;
  final int studentsCount;
  final int ueCount;
  final List<CurriculumSemester> semesters;

  const ProgramNode({
    required this.name,
    required this.code,
    required this.id,
    required this.niveau,
    required this.duree,
    required this.responsable,
    required this.studentsCount,
    required this.ueCount,
    this.isActive = true,
    this.semesters = const [],
  });
}

/// Un département au sein d'une faculté (ex: "Département d'Informatique"),
/// contient une liste de programmes.
class DepartmentNode {
  final String name;
  final List<ProgramNode> programs;

  const DepartmentNode({required this.name, required this.programs});
}

/// Une faculté (ex: "Faculté des Sciences"), racine de l'arborescence,
/// contient une liste de départements.
class FacultyNode {
  final String name;
  final List<DepartmentNode> departments;

  const FacultyNode({required this.name, required this.departments});
}

/// Jeu de données factices reproduisant la maquette "Programmes & Facultés",
/// en attendant le branchement à une vraie source de données.
class ProgramTreeData {
  ProgramTreeData._();

  static const ProgramNode licenceInformatique = ProgramNode(
    name: 'Licence Informatique',
    code: 'INF-LIC',
    id: 'INF-L-02',
    isActive: true,
    niveau: 'Licence (L1, L2, L3)',
    duree: '3 Ans (6 Semestres)',
    responsable: 'M. Youssef El Khatabi',
    studentsCount: 342,
    ueCount: 48,
    semesters: [
      CurriculumSemester(
        label: 'Semestre 1 (S1)',
        totalModules: 8,
        totalEcts: 30,
        modules: [
          CurriculumModule(
            name: "Introduction à l'Algorithmique",
            type: 'Majeur',
            typeColor: Color(0xFFDCEBFF),
            credits: 6,
          ),
          CurriculumModule(
            name: 'Architecture des Ordinateurs',
            type: 'Majeur',
            typeColor: Color(0xFFDCEBFF),
            credits: 5,
          ),
          CurriculumModule(
            name: 'Mathématiques Discrètes 1',
            type: 'Outil',
            typeColor: Color(0xFFF1E4FF),
            credits: 4,
          ),
        ],
      ),
      // Semestre 2 volontairement vide : sur la maquette il est affiché
      // "replié", avec un message invitant à cliquer pour voir le détail.
      CurriculumSemester(
        label: 'Semestre 2 (S2)',
        totalModules: 7,
        totalEcts: 30,
        modules: [],
      ),
    ],
  );

  static const List<FacultyNode> faculties = [
    FacultyNode(
      name: 'Faculté des Sciences',
      departments: [
        DepartmentNode(
          name: "Département d'Informatique",
          programs: [
            licenceInformatique,
            ProgramNode(
              name: 'Master Data Science',
              code: 'DS-MAS',
              id: 'INF-M-01',
              niveau: 'Master (M1, M2)',
              duree: '2 Ans (4 Semestres)',
              responsable: 'Mme. Amina Fassi',
              studentsCount: 96,
              ueCount: 22,
            ),
            ProgramNode(
              name: 'Ingénierie Logicielle',
              code: 'IL-LIC',
              id: 'INF-L-05',
              niveau: 'Licence (L1, L2, L3)',
              duree: '3 Ans (6 Semestres)',
              responsable: 'M. Karim Benjelloun',
              studentsCount: 210,
              ueCount: 44,
            ),
          ],
        ),
        DepartmentNode(
          name: 'Département de Mathématiques',
          programs: [
            ProgramNode(
              name: 'Licence Mathématiques',
              code: 'MATH-LIC',
              id: 'MATH-L-01',
              niveau: 'Licence (L1, L2, L3)',
              duree: '3 Ans (6 Semestres)',
              responsable: 'M. Hicham Zerouali',
              studentsCount: 128,
              ueCount: 40,
            ),
          ],
        ),
      ],
    ),
    FacultyNode(
      name: 'Faculté des Lettres',
      departments: [
        DepartmentNode(
          name: 'Département de Langues',
          programs: [
            ProgramNode(
              name: 'Licence Langues Appliquées',
              code: 'LANG-LIC',
              id: 'LANG-L-01',
              niveau: 'Licence (L1, L2, L3)',
              duree: '3 Ans (6 Semestres)',
              responsable: 'Mme. Nadia Idrissi',
              studentsCount: 174,
              ueCount: 36,
            ),
          ],
        ),
      ],
    ),
    FacultyNode(
      name: "Faculté d'Économie et Gestion",
      departments: [
        DepartmentNode(
          name: 'Département de Gestion',
          programs: [
            ProgramNode(
              name: 'Licence Management',
              code: 'MGT-LIC',
              id: 'MGT-L-01',
              niveau: 'Licence (L1, L2, L3)',
              duree: '3 Ans (6 Semestres)',
              responsable: 'M. Omar Tazi',
              studentsCount: 256,
              ueCount: 42,
            ),
          ],
        ),
      ],
    ),
  ];
}
