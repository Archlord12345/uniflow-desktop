// Grille de notes de l'enseignant sur `AppDataTable` : une colonne par
// évaluation, moyenne pondérée à droite, pied avec le décompte, et défilement
// horizontal (via `minWidth`) plutôt que débordement quand la fenêtre est
// étroite. L'ancienne `DataTable` Material avait ses propres en-têtes et
// densité, différents de tous les autres tableaux du bureau.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uniflow/models/appwrite_models.dart';
import 'package:uniflow/providers/directory_provider.dart';
import 'package:uniflow/repositories/management_repository.dart';
import 'package:uniflow/screens/academic_management_screens.dart';
import 'package:uniflow/services/appwrite_service.dart';
import 'package:uniflow/services/uniflow_api.dart';
import 'package:uniflow/ui/app_button.dart';
import 'package:uniflow/ui/app_data_table.dart';
import 'package:uniflow/widgets/data_state_view.dart';

import 'layout_test_support.dart';

const _courseId = 'c1';

/// `GradesApi.roster` appelle la Function : on le court-circuite avec une
/// liste en mémoire pour que la grille se peigne sans réseau.
class _FakeGradesApi extends GradesApi {
  final GradeRoster _roster;
  _FakeGradesApi(this._roster) : super(UniFlowApi(AppwriteService()));

  @override
  Future<GradeRoster> roster(String courseId) async => _roster;
}

AcademicGrade _grade(String studentId, String title, double score,
        {double max = 20, double coefficient = 1}) =>
    AcademicGrade(
      id: '$studentId-$title',
      studentId: studentId,
      courseId: _courseId,
      courseCode: 'INF101',
      evaluationTitle: title,
      score: score,
      maxScore: max,
      coefficient: coefficient,
    );

GradeRoster _roster({
  List<RosterStudent> students = const [
    RosterStudent(userId: 's1', name: 'Awa Ndiaye', matricule: '21T001'),
    RosterStudent(userId: 's2', name: 'Paul Biya'),
  ],
  List<AcademicGrade> grades = const [],
}) =>
    GradeRoster(
      courseId: _courseId,
      courseCode: 'INF101',
      courseName: 'Algorithmique',
      students: students,
      grades: grades,
    );

Future<void> _pump(WidgetTester tester, GradeRoster roster,
    {Size size = const Size(1280, 800)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host(
    const GradesManagementScreen(),
    overrides: [
      scopedCoursesProvider.overrideWith((ref) async => [
            AcademicCourse(
              id: _courseId,
              code: 'INF101',
              name: 'Algorithmique',
              university: 'UY1',
              program: 'INFO',
              level: 'L1',
            ),
          ]),
      selectedCourseIdProvider.overrideWith((ref) => _courseId),
      gradesApiProvider.overrideWithValue(_FakeGradesApi(roster)),
    ],
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUpAll(loadTestEnv);

  testWidgets('colonnes par évaluation, moyenne pondérée et décompte',
      (tester) async {
    await _pump(
      tester,
      _roster(grades: [
        _grade('s1', 'CC1', 12),
        // Sur 10, coefficient 2 : ramené à 20 avant pondération.
        _grade('s1', 'TP', 8, max: 10, coefficient: 2),
        _grade('s2', 'CC1', 7),
      ]),
    );

    expect(find.byType(AppDataTable<RosterStudent>), findsOneWidget);
    expect(find.text('APPRENANT'), findsOneWidget);
    expect(find.text('CC1'), findsOneWidget);
    expect(find.text('TP'), findsOneWidget);
    expect(find.text('MOYENNE'), findsOneWidget);

    expect(find.text('Awa Ndiaye · 21T001'), findsOneWidget);
    expect(find.text('Paul Biya'), findsOneWidget);

    // Awa : (12/20·20·1 + 8/10·20·2) / 3 = (12 + 32) / 3 = 14,67.
    expect(find.text('14.67'), findsOneWidget);
    // Paul : une seule note, 7/20.
    expect(find.text('7.00'), findsOneWidget);
    // Paul n'a pas de TP : la case vide reste cliquable et affiche « — ».
    expect(find.text('—'), findsOneWidget);

    expect(find.text('2 apprenants'), findsOneWidget);
    // L'action d'en-tête est le bouton du design system.
    expect(find.widgetWithText(AppButton, 'Nouvelle évaluation'),
        findsOneWidget);
  });

  testWidgets('sans apprenant : état vide commun', (tester) async {
    await _pump(tester, _roster(students: const []));
    expect(find.byType(DataEmptyView), findsOneWidget);
    expect(find.text('Aucun apprenant inscrit à ce cours.'), findsOneWidget);
  });

  // Six évaluations sur une fenêtre de 420 px : la grille doit défiler, pas
  // déborder (« A RenderFlex overflowed » était le symptôme de la `DataTable`).
  for (final width in const [420.0, 760.0, 1024.0, 1440.0]) {
    testWidgets('six évaluations ne débordent pas en ${width.toInt()} px',
        (tester) async {
      const titles = ['CC1', 'CC2', 'TP1', 'TP2', 'Projet', 'Examen'];
      await _pump(
        tester,
        _roster(grades: [
          for (final t in titles) _grade('s1', t, 15),
          for (final t in titles) _grade('s2', t, 9),
        ]),
        size: Size(width, 720),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(AppDataTable<RosterStudent>), findsOneWidget);
    });
  }
}
