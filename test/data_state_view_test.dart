// États chargement / vide / erreur partagés : tous les écrans passent par
// eux, et leur variante compacte sert dans les cartes et les colonnes
// étroites (tableau de bord, messagerie).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uniflow/theme/app_theme.dart';
import 'package:uniflow/widgets/data_state_view.dart';
import 'package:uniflow/widgets/uni/uni_mascot.dart';

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    );

double _mascotSize(WidgetTester tester) =>
    tester.widget<UniMascot>(find.byType(UniMascot)).size;

void main() {
  testWidgets('DataLoadingView : Uni réfléchit, plus petit en compact',
      (tester) async {
    await tester.pumpWidget(_host(const DataLoadingView(label: 'Chargement…')));
    await tester.pump();
    expect(find.text('Chargement…'), findsOneWidget);
    expect(tester.widget<UniMascot>(find.byType(UniMascot)).pose,
        UniPose.thinking);
    final full = _mascotSize(tester);

    await tester.pumpWidget(
        _host(const DataLoadingView(label: 'Chargement…', compact: true)));
    await tester.pump();
    expect(_mascotSize(tester), lessThan(full));
  });

  testWidgets('DataEmptyView : titre optionnel au-dessus de l’explication',
      (tester) async {
    await tester.pumpWidget(_host(const DataEmptyView(
      title: 'Aucune note saisie',
      message: 'Ajoutez des notes.',
    )));
    await tester.pump();
    expect(find.text('Aucune note saisie'), findsOneWidget);
    expect(find.text('Ajoutez des notes.'), findsOneWidget);
    expect(
        tester.widget<UniMascot>(find.byType(UniMascot)).pose, UniPose.search);

    final title = tester.widget<Text>(find.text('Aucune note saisie'));
    expect(title.style?.fontWeight, FontWeight.w700);
  });

  testWidgets('DataEmptyView sans titre : seulement le message',
      (tester) async {
    await tester.pumpWidget(_host(const DataEmptyView(message: 'Rien.')));
    await tester.pump();
    expect(find.text('Rien.'), findsOneWidget);
    // Aucun titre en gras : la mascotte peut afficher son propre texte de
    // repli, on ne compte donc pas les `Text` mais les graisses.
    final bold = tester
        .widgetList<Text>(find.byType(Text))
        .where((t) => t.style?.fontWeight == FontWeight.w700);
    expect(bold, isEmpty);
  });

  testWidgets('DataErrorView : titre personnalisable et bouton Réessayer actif',
      (tester) async {
    var retries = 0;
    await tester.pumpWidget(_host(DataErrorView(
      title: 'Statistiques indisponibles',
      error: 'HTTP 503',
      onRetry: () => retries++,
    )));
    await tester.pump();
    expect(find.text('Statistiques indisponibles'), findsOneWidget);
    expect(find.text('HTTP 503'), findsOneWidget);
    expect(
        tester.widget<UniMascot>(find.byType(UniMascot)).pose, UniPose.sorry);

    await tester.tap(find.text('Réessayer'));
    expect(retries, 1);
  });

  testWidgets('DataErrorView garde son titre par défaut', (tester) async {
    await tester.pumpWidget(
        _host(DataErrorView(error: 'x', onRetry: () {}, compact: true)));
    await tester.pump();
    expect(find.text('Lecture Appwrite impossible'), findsOneWidget);
  });

  testWidgets('compact : tient dans une carte de 180 px sans déborder',
      (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(const Center(
      child: SizedBox(
        width: 320,
        height: 180,
        child: DataEmptyView(
          compact: true,
          message: 'Aucune donnée de présence. La répartition se calcule '
              'depuis la collection « attendance_records ».',
        ),
      ),
    )));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
