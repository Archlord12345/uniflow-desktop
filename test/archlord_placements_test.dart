// Placements d'Archlord et d'Uni dans l'application : le dialogue du panneau
// de connexion, la note de l'écran Conférences, « À propos » des Paramètres.
//
// Trois fenêtres de bureau courantes (portable 13", écran large, Full HD) et
// le texte agrandi : aucun placement ne doit déborder, et chaque bulle doit
// rester lisible — elle est peinte en blanc sur les fonds bleus du panneau
// de marque, son texte doit donc contraster avec le blanc, pas avec le bleu.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniflow/app_info.dart';
import 'package:uniflow/screens/login_screen.dart';
import 'package:uniflow/screens/management_screens.dart';
import 'package:uniflow/screens/register_screen.dart';
import 'package:uniflow/widgets/auth_chrome.dart';
import 'package:uniflow/widgets/uni/archlord_mascot.dart';
import 'package:uniflow/widgets/uni/mascot_dialogue.dart';
import 'package:uniflow/widgets/uni/uni_mascot.dart';

import 'layout_test_support.dart';

/// Les trois fenêtres demandées pour la vérification des mascottes.
const List<Size> _desktopSizes = [
  Size(1280, 800),
  Size(1440, 900),
  Size(1920, 1080),
];

Future<void> _pump(WidgetTester tester, Widget screen, Size size,
    {double scale = 1.0}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
      child: host(screen),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Rapport de contraste WCAG entre deux couleurs opaques.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final light = la > lb ? la : lb;
  final dark = la > lb ? lb : la;
  return (light + 0.05) / (dark + 0.05);
}

/// Couleur effective du texte de la première bulle trouvée : celle que
/// `UniBubble` impose via `DefaultTextStyle`, ou celle du `Text` s'il en a une.
Color _bubbleTextColor(WidgetTester tester) {
  final textFinder = find
      .descendant(of: find.byType(UniBubble).first, matching: find.byType(Text))
      .first;
  final text = tester.widget<Text>(textFinder);
  return text.style?.color ??
      DefaultTextStyle.of(tester.element(textFinder)).style.color!;
}

/// Une bulle blanche (c'est ce que peint `UniBubble`) dont le texte atteint
/// le seuil AA du texte courant, 4,5:1.
void _expectLegibleBubble(WidgetTester tester) {
  expect(find.byType(UniBubble), findsWidgets);
  final ratio = _contrast(_bubbleTextColor(tester), Colors.white);
  expect(ratio, greaterThanOrEqualTo(4.5),
      reason:
          'texte de bulle trop pâle sur fond blanc (${ratio.toStringAsFixed(1)}:1)');
}

void main() {
  setUpAll(loadTestEnv);

  group('Panneau de connexion : Archlord et Uni discutent', () {
    for (final screen in <String, Widget>{
      'Connexion': const LoginScreen(),
      'Inscription': const RegisterScreen(),
    }.entries) {
      for (final size in _desktopSizes) {
        for (final scale in const [1.0, 1.3]) {
          testWidgets(
              '${screen.key} en ${size.width.toInt()}×${size.height.toInt()} '
              '(texte ×$scale) : dialogue présent, lisible, sans débordement',
              (tester) async {
            await _pump(tester, screen.value, size, scale: scale);
            expect(tester.takeException(), isNull);
            expect(find.byType(MascotDialogue), findsOneWidget);
            expect(find.byType(ArchlordMascot), findsOneWidget);
            expect(find.byType(UniMascot), findsOneWidget);
            // Archlord ouvre : c'est le fondateur qui accueille, Uni guide
            // ensuite. La première réplique doit donc être la sienne.
            expect(kAuthMascotDialogue.first.who, MascotSpeaker.archlord);
            expect(find.text(kAuthMascotDialogue.first.text), findsOneWidget);
            _expectLegibleBubble(tester);
          });
        }
      }
    }

    testWidgets('les répliques tiennent chacune dans une bulle de 260 px',
        (tester) async {
      await _pump(tester, const LoginScreen(), const Size(1280, 800));
      for (var i = 0; i < kAuthMascotDialogue.length; i++) {
        expect(find.text(kAuthMascotDialogue[i].text), findsOneWidget);
        expect(tester.getSize(find.byType(UniBubble).first).width,
            lessThanOrEqualTo(260 + 8));
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(MascotDialogue));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }
    });
  });

  group('ConferencesScreen', () {
    for (final size in _desktopSizes) {
      for (final scale in const [1.0, 1.3]) {
        testWidgets(
            'sans réunion, Archlord rappelle que le serveur est local — '
            '${size.width.toInt()}×${size.height.toInt()} (texte ×$scale)',
            (tester) async {
          await _pump(tester, const ConferencesScreen(), size, scale: scale);
          expect(tester.takeException(), isNull);
          expect(find.byType(ArchlordMascot), findsOneWidget);
          expect(find.textContaining('aucun Internet requis'), findsOneWidget);
          _expectLegibleBubble(tester);
        });
      }
    }
  });

  group('AboutPanel', () {
    for (final size in const [Size(420, 900), Size(1280, 800)]) {
      testWidgets(
          'en ${size.width.toInt()} px : version, éditeur, scène du poing, '
          'sans débordement', (tester) async {
        await _pump(
          tester,
          const SingleChildScrollView(child: AboutPanel()),
          size,
        );
        expect(tester.takeException(), isNull);
        expect(
            find.textContaining('version ${AppInfo.version}'), findsOneWidget);
        expect(find.text(AppInfo.publisherPitch), findsOneWidget);
        expect(find.byType(ArchlordUniFistBump), findsOneWidget);
        expect(find.byType(ArchlordMascot), findsOneWidget);
        _expectLegibleBubble(tester);
      });
    }

    for (final size in _desktopSizes) {
      for (final scale in const [1.0, 1.3]) {
        testWidgets(
            'les Paramètres embarquent « À propos » — '
            '${size.width.toInt()}×${size.height.toInt()} (texte ×$scale)',
            (tester) async {
          await _pump(tester, const SettingsScreen(), size, scale: scale);
          // Le panneau est en bas de page : on le fait défiler dans la vue.
          await tester.scrollUntilVisible(find.byType(AboutPanel), 200);
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.byType(AboutPanel), findsOneWidget);
          expect(find.byType(ArchlordUniFistBump), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
