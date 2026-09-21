// Pastilles de statut : une seule implémentation (`lib/ui/status_badge.dart`),
// aux tons des planches — fond pâle, texte foncé de la même teinte.
//
// Il en existait deux : l'ancienne (`widgets/status_badge.dart`) prenait une
// couleur de fond arbitraire et en dérivait le texte, si bien que « Actif »
// n'avait pas le même vert selon l'écran. Ces tests figent la correspondance
// statut → ton et le rendu de la teinte libre.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uniflow/theme/app_theme.dart';
import 'package:uniflow/ui/status_badge.dart';

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('StatusBadge.toneFor', () {
    test('statuts d’annuaire', () {
      expect(StatusBadge.toneFor('Actif'), BadgeTone.success);
      expect(StatusBadge.toneFor('ACTIVE'), BadgeTone.success);
      expect(StatusBadge.toneFor('En attente'), BadgeTone.warning);
      expect(StatusBadge.toneFor('Suspendu'), BadgeTone.danger);
      expect(StatusBadge.toneFor('Inactif'), BadgeTone.danger);
    });

    test('types de séance, sigle ou nom complet', () {
      expect(StatusBadge.toneFor('CM'), BadgeTone.primary);
      expect(StatusBadge.toneFor('Cours magistral'), BadgeTone.primary);
      expect(StatusBadge.toneFor('TD'), BadgeTone.teal);
      expect(StatusBadge.toneFor('Travaux dirigés'), BadgeTone.teal);
      expect(StatusBadge.toneFor('TP'), BadgeTone.warning);
      expect(StatusBadge.toneFor('Travaux pratiques'), BadgeTone.warning);
    });

    test('publication d’une réunion', () {
      expect(StatusBadge.toneFor('Publiée'), BadgeTone.success);
      expect(StatusBadge.toneFor('Non publiée'), BadgeTone.warning);
    });

    test('inconnu : neutre, jamais une couleur inventée', () {
      expect(StatusBadge.toneFor('UE'), BadgeTone.neutral);
      expect(StatusBadge.toneFor('L2'), BadgeTone.neutral);
      expect(StatusBadge.toneFor(''), BadgeTone.neutral);
    });
  });

  testWidgets('fromStatus construit le badge avec le ton déduit',
      (tester) async {
    await tester.pumpWidget(_host(StatusBadge.fromStatus('Suspendu')));
    final badge = tester.widget<StatusBadge>(find.byType(StatusBadge));
    expect(badge.tone, BadgeTone.danger);
    expect(badge.color, isNull);
    expect(find.text('Suspendu'), findsOneWidget);
  });

  testWidgets('tinted : fond à 15 % et texte de la teinte pleine',
      (tester) async {
    const tint = Color(0xFF0D9488);
    await tester
        .pumpWidget(_host(const StatusBadge.tinted(label: 'TD', color: tint)));

    final container = tester.widget<Container>(find.descendant(
        of: find.byType(StatusBadge), matching: find.byType(Container)));
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, tint.withValues(alpha: 0.15));

    final text = tester.widget<Text>(find.text('TD'));
    expect(text.style?.color, tint);
  });

  testWidgets('le point coloré précède le libellé quand `dot` est vrai',
      (tester) async {
    await tester.pumpWidget(_host(const StatusBadge(
        label: 'En écoute', tone: BadgeTone.success, dot: true)));
    // Deux `Container` : la pilule et le point.
    expect(
        find.descendant(
            of: find.byType(StatusBadge), matching: find.byType(Container)),
        findsNWidgets(2));
  });
}
