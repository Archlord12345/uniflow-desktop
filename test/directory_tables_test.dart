// Tableaux Étudiants, UE, Salles et Programmes sur `AppDataTable` (planches
// partie 2) :
// même en-tête, même pied de décompte, mêmes icônes d'action que le tableau
// des enseignants. Le balayage de `layout_test.dart` mesure ces écrans avec
// des listes vides ; ici les lignes sont remplies et mesurées sur plusieurs
// largeurs, car c'est une colonne d'actions trop étroite qui débordait.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uniflow/models/appwrite_models.dart';
import 'package:uniflow/models/classroom.dart';
import 'package:uniflow/models/program_tree.dart';
import 'package:uniflow/models/student.dart';
import 'package:uniflow/models/teaching_unit.dart';
import 'package:uniflow/providers/directory_provider.dart';
import 'package:uniflow/providers/program_provider.dart';
import 'package:uniflow/screens/classrooms_screen.dart';
import 'package:uniflow/screens/programs_screen.dart';
import 'package:uniflow/screens/students_screen.dart';
import 'package:uniflow/screens/teaching_units_screen.dart';
import 'package:uniflow/screens/teachers_screen.dart';
import 'package:uniflow/ui/app_button.dart';
import 'package:uniflow/ui/app_data_table.dart';
import 'package:uniflow/ui/status_badge.dart';
import 'package:uniflow/ui/table_action_icon.dart';
import 'package:uniflow/widgets/app_top_bar.dart';
import 'package:uniflow/widgets/data_state_view.dart';

import 'layout_test_support.dart';

Student _student(String name, {String statut = 'Actif', String? username}) =>
    Student(
      id: name,
      matricule: '2023${name.length}',
      fullName: name,
      email: '${name.toLowerCase().replaceAll(' ', '.')}@uy1.cm',
      programme: 'Informatique',
      niveau: 'Licence 2',
      statut: statut,
      statutColor: Colors.green,
      inscritLe: '12/09/2023',
      avatarColor: Colors.blue,
      username: username,
    );

TeachingUnit _unit(String code, String intitule, {String type = 'CM'}) =>
    TeachingUnit(
      id: code,
      code: code,
      intitule: intitule,
      semestre: '',
      departement: 'Informatique',
      niveau: 'L3',
      type: type,
      enseignant: 'Pr. Awa Ndiaye',
      credits: 6,
      heures: 60,
      inscrits: 42,
      placesTotal: 0,
      statut: '',
    );

Classroom _room(
  String nom, {
  String referenceId = 'ref',
  String type = 'AMPHI',
  String batiment = 'Bloc pédagogique',
}) =>
    Classroom(
      nom: nom,
      creneaux: 12,
      cours: 4,
      type: type,
      capacite: 300,
      batiment: batiment,
      referenceId: referenceId,
    );

UniFlowUser _studentUser() => UniFlowUser(
      id: 'u2',
      email: 'awa@uniflow.edu',
      name: 'Awa Ndiaye',
      accountType: 'UNIVERSITY',
      role: 'STUDENT',
    );

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  required List<Override> overrides,
  UniFlowUser? user,
  double width = 1280,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host(screen, overrides: overrides, user: user));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUpAll(loadTestEnv);

  group('Étudiants', () {
    testWidgets('tableau, sélection et décompte', (tester) async {
      await _pump(tester, const StudentsScreen(), overrides: [
        studentsProvider.overrideWith((ref) async => [
              _student('Awa Ndiaye', username: 'awa'),
              _student('Paul Biya', statut: 'Inactif'),
            ]),
      ]);

      expect(find.byType(AppDataTable<Student>), findsOneWidget);
      expect(find.text('N° ÉTUDIANT'), findsOneWidget);
      expect(find.text('@awa'), findsOneWidget);
      expect(find.text('2 étudiants'), findsOneWidget);
      // Trois icônes par ligne : voir, modifier, supprimer.
      expect(find.byType(TableActionIcon), findsNWidgets(6));

      // Cocher une ligne fait apparaître la pastille de sélection ; la case
      // « tout cocher » de l'en-tête coche les deux.
      final boxes = find.byType(Checkbox);
      expect(boxes, findsNWidgets(3));
      await tester.tap(boxes.at(1));
      await tester.pump();
      expect(find.text('1 sélectionné'), findsOneWidget);

      await tester.tap(boxes.first);
      await tester.pump();
      expect(find.text('2 sélectionnés'), findsOneWidget);
      expect(tester.widget<Checkbox>(boxes.first).value, isTrue,
          reason: 'la case d\'en-tête reflète « tout coché »');
    });

    testWidgets('recherche sans résultat : état vide commun', (tester) async {
      await _pump(tester, const StudentsScreen(), overrides: [
        studentsProvider.overrideWith((ref) async => [_student('Awa Ndiaye')]),
      ]);
      await tester.enterText(find.byType(TextField).first, 'zzz');
      await tester.pump();
      expect(find.byType(DataEmptyView), findsOneWidget);
      expect(find.text('0 étudiant'), findsOneWidget);
    });
  });

  group('UE', () {
    testWidgets('en-tête AppTopBar, pastilles de type et compteurs',
        (tester) async {
      await _pump(tester, const TeachingUnitsScreen(), overrides: [
        teachingUnitsProvider.overrideWith((ref) async => [
              _unit('INF301', 'Intelligence artificielle'),
              _unit('INF302', 'Réseaux', type: 'TP'),
            ]),
      ]);

      expect(find.byType(AppTopBar), findsOneWidget);
      expect(find.text('Gestion des UE'), findsOneWidget);
      expect(find.byType(AppDataTable<TeachingUnit>), findsOneWidget);
      expect(find.text('CRÉDITS'), findsOneWidget);
      expect(find.text('INF301'), findsOneWidget);
      expect(find.text('60h'), findsNWidgets(2));
      expect(find.text('2 UE affichées'), findsOneWidget);

      final tones = tester
          .widgetList<StatusBadge>(find.byType(StatusBadge))
          .map((b) => b.tone);
      // CM → bleu primaire, TP → ambre, comme sur la planche « UE ».
      expect(tones, containsAll([BadgeTone.primary, BadgeTone.warning]));
    });
  });

  group('Salles', () {
    testWidgets('administration : colonne d\'actions pour le catalogue seul',
        (tester) async {
      await _pump(tester, const ClassroomsScreen(), overrides: [
        classroomsProvider.overrideWith((ref) async => [
              _room('Amphi 700'),
              _room('Salle fantôme', referenceId: '', type: '', batiment: ''),
            ]),
      ]);

      expect(find.byType(AppDataTable<Classroom>), findsOneWidget);
      expect(find.text('ACTIONS'), findsOneWidget);
      // Seule la salle du catalogue a ses deux icônes ; la salle qui ne vient
      // que de l'emploi du temps n'en a aucune.
      expect(find.byType(TableActionIcon), findsNWidgets(2));
      expect(find.text('Hors catalogue (emploi du temps)'), findsOneWidget);
      expect(find.text('300 places'), findsNWidgets(2));
      expect(find.text('2 salles'), findsOneWidget);
    });

    testWidgets('étudiant : pas de colonne d\'actions ni de bouton d\'ajout',
        (tester) async {
      await _pump(
        tester,
        const ClassroomsScreen(),
        user: _studentUser(),
        overrides: [
          classroomsProvider.overrideWith((ref) async => [_room('Amphi 700')]),
        ],
      );
      expect(find.text('ACTIONS'), findsNothing);
      expect(find.byType(TableActionIcon), findsNothing);
      expect(find.text('Ajouter une salle'), findsNothing);
    });
  });

  group('Programmes', () {
    FacultyNode faculty(List<CurriculumModule> modules) => FacultyNode(
          name: 'Université de Yaoundé I',
          departments: [
            DepartmentNode(name: 'Informatique', programs: [
              ProgramNode(
                name: 'Licence 3',
                program: 'Informatique',
                code: 'L3',
                studentsCount: 120,
                ueCount: modules.length,
                modules: modules,
              ),
            ]),
          ],
        );

    testWidgets('les UE du niveau sélectionné dans un AppDataTable',
        (tester) async {
      await _pump(tester, const ProgramsScreen(), overrides: [
        programTreeProvider.overrideWith((ref) async => [
              faculty(const [
                CurriculumModule(
                    name: 'Intelligence artificielle',
                    code: 'INF301',
                    type: 'CM',
                    typeColor: Colors.blue,
                    credits: 6),
                CurriculumModule(
                    name: 'Réseaux',
                    code: 'INF302',
                    type: 'TP',
                    typeColor: Colors.orange,
                    credits: 4),
              ]),
            ]),
      ]);

      expect(find.byType(AppDataTable<CurriculumModule>), findsOneWidget);
      expect(find.text('MODULE'), findsOneWidget);
      expect(find.text('CRÉDITS'), findsOneWidget);
      expect(find.text('INF301'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('niveau sans UE : état vide compact dans le tableau',
        (tester) async {
      await _pump(tester, const ProgramsScreen(), overrides: [
        programTreeProvider.overrideWith((ref) async => [faculty(const [])]),
      ]);
      expect(
          find.text('Aucune UE enregistrée pour ce niveau.'), findsOneWidget);
      expect(find.byType(DataEmptyView), findsOneWidget);
    });
  });

  // Les actions des barres de page étaient des `ElevatedButton` et
  // `OutlinedButton` avec, à chaque écran, une marge et un rayon différents ;
  // elles passent toutes par le bouton du design system.
  group('Boutons de barre de page', () {
    for (final (name, screen, count) in <(String, Widget, int)>[
      ('Enseignants', const TeachersScreen(), 2),
      ('Étudiants', const StudentsScreen(), 3),
      ('UE', const TeachingUnitsScreen(), 1),
      ('Salles', const ClassroomsScreen(), 1),
      ('Programmes', const ProgramsScreen(), 1),
    ]) {
      testWidgets('$name : AppButton uniquement', (tester) async {
        await _pump(tester, screen, overrides: const []);
        expect(find.byType(AppButton), findsNWidgets(count));
        expect(find.byType(ElevatedButton), findsNothing);
        expect(find.byType(OutlinedButton), findsNothing);
      });
    }
  });

  for (final width in const [420.0, 760.0, 1024.0, 1440.0]) {
    testWidgets('lignes remplies sans débordement en ${width.toInt()} px',
        (tester) async {
      const long = 'Nghomsi Feukouo Ravel Archlord de Yaoundé';
      await _pump(
        tester,
        const StudentsScreen(),
        width: width,
        overrides: [
          studentsProvider.overrideWith((ref) async => [
                _student(long, username: 'aliyatou.rachid.oumou.tourab'),
                _student('Awa Ndiaye', statut: 'En échange'),
              ]),
        ],
      );
      expect(tester.takeException(), isNull, reason: 'Étudiants');

      await _pump(
        tester,
        const TeachingUnitsScreen(),
        width: width,
        overrides: [
          teachingUnitsProvider.overrideWith((ref) async => [
                _unit(
                    'INF301',
                    'Intelligence artificielle et apprentissage '
                        'automatique appliqué aux systèmes distribués'),
              ]),
        ],
      );
      expect(tester.takeException(), isNull, reason: 'UE');

      await _pump(
        tester,
        const ClassroomsScreen(),
        width: width,
        overrides: [
          classroomsProvider.overrideWith((ref) async => [
                _room('Amphithéâtre 700 du bloc pédagogique principal'),
              ]),
        ],
      );
      expect(tester.takeException(), isNull, reason: 'Salles');
    });
  }
}
