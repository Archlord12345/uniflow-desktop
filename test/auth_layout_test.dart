import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniflow/screens/login_screen.dart';
import 'package:uniflow/screens/register_screen.dart';
import 'package:uniflow/widgets/auth_chrome.dart';

import 'layout_test_support.dart';

/// Les écrans d'authentification s'adaptent à la fenêtre : plus de carte
/// fixe de ~570×320 flottant au milieu d'un 1024×576 (capture du propriétaire,
/// 2026-09-20). Ici : aucun débordement, formulaire jamais plus étroit que
/// 360 px, bascule une/deux colonnes autour de 900 px, titre qui grandit.
const List<Size> _sizes = [
  Size(800, 600),
  Size(1366, 768),
  Size(1920, 1080),
  Size(2560, 1440),
];

Future<void> _pump(WidgetTester tester, Widget screen, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(data: MediaQueryData(size: size), child: host(screen)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

double _formWidth(WidgetTester tester) =>
    tester.getSize(find.byKey(const Key('auth-form'))).width;

double _titleSize(WidgetTester tester) {
  final text = tester.widget<Text>(find.byKey(const Key('auth-title')));
  return text.style!.fontSize!;
}

bool _isTwoColumns(WidgetTester tester) {
  final hero = tester.widget<AuthHeroPanel>(find.byType(AuthHeroPanel));
  return !hero.compact;
}

void main() {
  setUpAll(loadTestEnv);

  final screens = <String, Widget>{
    'Connexion': const LoginScreen(),
    'Inscription': const RegisterScreen(),
  };

  for (final entry in screens.entries) {
    for (final size in _sizes) {
      testWidgets(
          '${entry.key} en ${size.width.toInt()}×${size.height.toInt()} : '
          'pas de débordement, formulaire ≥ 360 px', (tester) async {
        await _pump(tester, entry.value, size);
        expect(tester.takeException(), isNull);
        expect(_formWidth(tester), greaterThanOrEqualTo(360));
        expect(_formWidth(tester), lessThanOrEqualTo(560));
      });
    }

    testWidgets('${entry.key} : une colonne sous 900 px, deux au-dessus',
        (tester) async {
      await _pump(tester, entry.value, const Size(880, 700));
      expect(_isTwoColumns(tester), isFalse);
      await _pump(tester, entry.value, const Size(920, 700));
      expect(_isTwoColumns(tester), isTrue);
    });

    testWidgets('${entry.key} : le titre grandit avec la fenêtre',
        (tester) async {
      await _pump(tester, entry.value, const Size(800, 600));
      final small = _titleSize(tester);
      await _pump(tester, entry.value, const Size(1366, 768));
      final medium = _titleSize(tester);
      await _pump(tester, entry.value, const Size(2560, 1440));
      final large = _titleSize(tester);
      expect(small, lessThan(medium));
      expect(medium, lessThan(large));
      expect(small, 24);
      expect(large, 40);
    });
  }

  test('AuthScale : paliers de largeur', () {
    expect(AuthScale.forWidth(800), AuthScale.compact);
    expect(AuthScale.forWidth(900), AuthScale.regular);
    expect(AuthScale.forWidth(1399), AuthScale.regular);
    expect(AuthScale.forWidth(1400), AuthScale.large);
    expect(AuthScale.forWidth(1900), AuthScale.huge);
    expect(AuthScale.formWidth(800, 800), 360);
    expect(AuthScale.formWidth(2560, 1408), 560);
    // Bornée à 90 % d'une colonne étroite.
    expect(AuthScale.formWidth(1366, 300), closeTo(270, 0.01));
  });
}
