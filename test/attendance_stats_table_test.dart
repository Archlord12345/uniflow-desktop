// Onglet « Assiduité » de la page Présences : le tableau des taux était un
// `DataTable` Material, seul de son espèce dans l'application. Il passe sur
// AppDataTable, avec les moins assidus en tête et un décompte en pied.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uniflow/models/attendance_models.dart';
import 'package:uniflow/providers/analytics_provider.dart';
import 'package:uniflow/screens/attendance_screen.dart';
import 'package:uniflow/ui/app_data_table.dart';
import 'package:uniflow/widgets/data_state_view.dart';

import 'layout_test_support.dart';

StudentAttendance _student(String name,
        {required int present, required int absent, int late = 0}) =>
    StudentAttendance(
      studentId: name,
      name: name,
      matricule: '2023${name.length}',
      present: present,
      absent: absent,
      late: late,
    );

Future<void> _openStats(WidgetTester tester, List<StudentAttendance> rows,
    {double width = 1280}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host(
    const AttendanceScreen(),
    overrides: [studentAttendanceProvider.overrideWith((ref) async => rows)],
  ));
  await tester.pump();
  await tester.tap(find.text('Assiduité'));
  // Transition de l'AnimatedSwitcher puis résolution du FutureProvider.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(loadTestEnv);

  testWidgets('taux triés du moins assidu au plus assidu, décompte en pied',
      (tester) async {
    await _openStats(tester, [
      _student('Awa Ndiaye', present: 9, absent: 1),
      _student('Paul Biya', present: 2, absent: 6),
    ]);

    expect(find.byType(AppDataTable<StudentAttendance>), findsOneWidget);
    expect(find.text('APPRENANT'), findsOneWidget);
    expect(find.text('TAUX'), findsOneWidget);
    expect(find.text('2 apprenants'), findsOneWidget);

    // Paul (25 %) avant Awa (90 %).
    final paul = tester.getTopLeft(find.textContaining('Paul Biya'));
    final awa = tester.getTopLeft(find.textContaining('Awa Ndiaye'));
    expect(paul.dy, lessThan(awa.dy));

    // Le taux d'un étudiant en alerte est en rouge, celui d'un régulier en vert.
    Color colorOf(String label) =>
        tester.widget<Text>(find.text(label)).style!.color!;
    expect(colorOf('25,0%').toARGB32(), isNot(colorOf('90,0%').toARGB32()));
  });

  testWidgets('sans émargement : état vide commun', (tester) async {
    await _openStats(tester, const []);
    expect(find.byType(DataEmptyView), findsOneWidget);
    expect(find.byType(AppDataTable<StudentAttendance>), findsNothing);
  });

  for (final width in const [420.0, 760.0, 1440.0]) {
    testWidgets('lignes remplies sans débordement en ${width.toInt()} px',
        (tester) async {
      await _openStats(
        tester,
        [
          _student('Nghomsi Feukouo Ravel Archlord de Yaoundé',
              present: 12, absent: 3, late: 2),
        ],
        width: width,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
