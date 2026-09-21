// Tableau des enseignants sur `AppDataTable` (planche « Enseignants ») :
// en-tête en petites majuscules, pied avec le décompte réel, statut en
// pastille au ton déduit, état vide commun.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uniflow/models/teacher.dart';
import 'package:uniflow/providers/directory_provider.dart';
import 'package:uniflow/screens/teachers_screen.dart';
import 'package:uniflow/ui/app_data_table.dart';
import 'package:uniflow/ui/status_badge.dart';
import 'package:uniflow/widgets/data_state_view.dart';

import 'layout_test_support.dart';

Teacher _teacher(String name, {String statut = 'Actif', String? username}) =>
    Teacher(
      id: name,
      fullName: name,
      email: '${name.toLowerCase().replaceAll(' ', '.')}@uy1.cm',
      departement: 'Informatique',
      statut: statut,
      statutColor: Colors.green,
      avatarColor: Colors.blue,
      username: username,
    );

Future<void> _pump(WidgetTester tester, List<Teacher> teachers) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host(
    const TeachersScreen(),
    overrides: [teachersProvider.overrideWith((ref) async => teachers)],
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUpAll(loadTestEnv);

  testWidgets('en-tête, lignes, pastilles et décompte', (tester) async {
    await _pump(tester, [
      _teacher('Awa Ndiaye', username: 'awa'),
      _teacher('Paul Biya', statut: 'Suspendu'),
    ]);

    expect(find.byType(AppDataTable<Teacher>), findsOneWidget);
    expect(find.text('NOM COMPLET'), findsOneWidget);
    expect(find.text('STATUT'), findsOneWidget);

    expect(find.text('Pr. Awa Ndiaye'), findsOneWidget);
    expect(find.text('@awa'), findsOneWidget);
    // Sans pseudo, l'email sert de repli.
    expect(find.text('paul.biya@uy1.cm'), findsOneWidget);

    final badges = tester.widgetList<StatusBadge>(find.byType(StatusBadge));
    expect(badges.map((b) => b.tone),
        containsAll([BadgeTone.success, BadgeTone.danger]));

    expect(find.text('2 enseignants'), findsOneWidget);
  });

  testWidgets('recherche sans résultat : état vide commun dans le tableau',
      (tester) async {
    await _pump(tester, [_teacher('Awa Ndiaye')]);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();

    expect(find.byType(DataEmptyView), findsOneWidget);
    expect(find.text('Aucun enseignant ne correspond à « zzz ».'),
        findsOneWidget);
    expect(find.text('0 enseignant'), findsOneWidget);
    // L'en-tête reste visible au-dessus de l'état vide.
    expect(find.text('NOM COMPLET'), findsOneWidget);
  });

  // Le balayage de `layout_test.dart` mesure les écrans avec des listes vides :
  // les lignes du tableau n'y sont jamais peintes. On les mesure ici, avec un
  // nom long et un email long, sur les largeurs que le balayage utilise.
  for (final width in const [420.0, 760.0, 1024.0, 1440.0]) {
    testWidgets('des lignes remplies ne débordent pas en ${width.toInt()} px',
        (tester) async {
      tester.view.physicalSize = Size(width, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(
        const TeachersScreen(),
        overrides: [
          teachersProvider.overrideWith((ref) async => [
                _teacher('Nghomsi Feukouo Ravel Archlord de Yaoundé'),
                _teacher('Aliyatou Rachid Oumou Tourab',
                    username: 'aliyatou.rachid.oumou'),
              ]),
        ],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    });
  }

  test('AppTableFooter.count accorde le nom', () {
    expect(AppTableFooter.count(0, 'salle'), '0 salle');
    expect(AppTableFooter.count(1, 'salle'), '1 salle');
    expect(AppTableFooter.count(3, 'salle'), '3 salles');
    expect(AppTableFooter.count(2, 'UE', 'UE'), '2 UE');
  });
}
