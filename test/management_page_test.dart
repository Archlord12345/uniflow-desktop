// Pages de gestion (statistiques, structure, paiements, conférences) : même
// coquille que les autres écrans — en-tête `AppTopBar` fixe, d'un bord à
// l'autre, contenu défilant dessous — et états vides communs.
//
// L'en-tête était posé dans la zone défilante avec 30 px de marge : il
// apparaissait comme une carte blanche encadrée, décalée du bord, alors que
// l'annuaire et l'emploi du temps l'affichent pleine largeur.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uniflow/screens/management_screens.dart';
import 'package:uniflow/widgets/app_top_bar.dart';
import 'package:uniflow/widgets/data_state_view.dart';

import 'layout_test_support.dart';

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host(screen));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUpAll(loadTestEnv);

  testWidgets('l’en-tête est hors du défilement et touche le bord gauche',
      (tester) async {
    await _pump(tester, const StatisticsScreen());

    final topBar = find.byType(AppTopBar);
    expect(topBar, findsOneWidget);
    expect(
      find.ancestor(of: topBar, matching: find.byType(SingleChildScrollView)),
      findsNothing,
    );
    expect(tester.getTopLeft(topBar).dx, 0);
    // Pas de `Scaffold` imbriqué dans celui de la coquille (ici, du harnais).
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('Statistiques sans note : état vide commun, pas un panneau maison',
      (tester) async {
    await _pump(tester, const StatisticsScreen());
    expect(find.byType(DataEmptyView), findsOneWidget);
    expect(find.text('Aucune note saisie'), findsOneWidget);
  });

  testWidgets('Structure et Paiements : état vide commun avec titre',
      (tester) async {
    await _pump(tester, const StructureManagementScreen());
    expect(find.byType(DataEmptyView), findsOneWidget);
    expect(find.text('Structure non configurée'), findsOneWidget);

    await _pump(tester, const PaymentsManagementScreen());
    expect(find.byType(DataEmptyView), findsOneWidget);
    expect(find.text('Aucun paiement enregistré'), findsOneWidget);
  });
}
