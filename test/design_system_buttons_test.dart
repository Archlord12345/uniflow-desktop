import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniflow/screens/login_screen.dart';
import 'package:uniflow/screens/management_screens.dart';
import 'package:uniflow/screens/register_screen.dart';
import 'package:uniflow/theme/app_theme.dart';
import 'package:uniflow/ui/app_button.dart';
import 'package:uniflow/widgets/motion.dart';
import 'package:uniflow/widgets/uni/uni_scenes.dart';

import 'layout_test_support.dart';

/// Fin de la passe design system : plus aucun bouton Material brut
/// (`TextButton`, `FilledButton`, `OutlinedButton`, `ElevatedButton`) sur les
/// écrans et dans leurs dialogues. Chaque écran en gardait un ou deux — les
/// actions des dialogues surtout — et ils ne se ressemblaient pas : texte bleu
/// sans bordure ici, pilule Material 3 là, rayon différent des voisins.
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

void _expectNoMaterialButtons() {
  expect(find.byType(TextButton), findsNothing);
  expect(find.byType(FilledButton), findsNothing);
  expect(find.byType(OutlinedButton), findsNothing);
  expect(find.byType(ElevatedButton), findsNothing);
}

void main() {
  setUpAll(loadTestEnv);

  group('Authentification', () {
    testWidgets(
        'Connexion : inscription en AppButton, lien « oublié » sans '
        'TextButton', (tester) async {
      await _pump(tester, const LoginScreen(), const Size(1366, 768));
      _expectNoMaterialButtons();
      expect(find.widgetWithText(AppButton, 'Créer un compte étudiant'),
          findsOneWidget);
      expect(find.text('Mot de passe oublié ?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Connexion : le dialogue « Mot de passe oublié » n\'a que des '
        'AppButton', (tester) async {
      await _pump(tester, const LoginScreen(), const Size(1366, 768));
      await tester.tap(find.text('Mot de passe oublié ?'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Mot de passe oublié'), findsOneWidget);
      _expectNoMaterialButtons();
      expect(
          find.widgetWithText(AppButton, 'Envoyer l\'email'), findsOneWidget);
      expect(
          find.widgetWithText(AppButton, 'J\'ai déjà le lien'), findsOneWidget);

      await tester.tap(find.widgetWithText(AppButton, 'Annuler'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Mot de passe oublié'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Inscription : « S\'inscrire sur le web » en AppButton',
        (tester) async {
      await _pump(tester, const RegisterScreen(), const Size(1366, 768));
      _expectNoMaterialButtons();
      expect(find.widgetWithText(AppButton, 'S\'inscrire sur le web'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Conférences', () {
    testWidgets(
        'le dialogue « Nouvelle réunion » : Annuler / Ouvrir en '
        'AppButton', (tester) async {
      await _pump(tester, const ConferencesScreen(), const Size(1440, 900));
      await tester.tap(find.text('Nouvelle conférence'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Nouvelle réunion'), findsOneWidget);
      _expectNoMaterialButtons();
      expect(find.widgetWithText(AppButton, 'Ouvrir'), findsOneWidget);

      await tester.tap(find.widgetWithText(AppButton, 'Annuler'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Nouvelle réunion'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Retours et secours', () {
    testWidgets('ResultView : les deux actions sont des AppButton actifs',
        (tester) async {
      var primary = 0;
      var secondary = 0;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ResultView(
            success: true,
            title: 'Réunion terminée',
            message: 'La feuille de présence est enregistrée.',
            actionLabel: 'Continuer',
            onAction: () => primary++,
            secondaryLabel: 'Retour',
            onSecondary: () => secondary++,
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      _expectNoMaterialButtons();
      expect(find.byType(AppButton), findsNWidgets(2));

      await tester.tap(find.widgetWithText(AppButton, 'Continuer'));
      await tester.tap(find.widgetWithText(AppButton, 'Retour'));
      expect(primary, 1);
      expect(secondary, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('UniCrashScreen : « Réessayer » reste utilisable sans thème',
        (tester) async {
      // L'écran de secours se peint dans un arbre cassé, sans `MaterialApp` :
      // le bouton du design system doit s'en contenter.
      var retried = 0;
      await tester.pumpWidget(
          UniCrashScreen(details: 'Boom', onRetry: () => retried++));
      await tester.pump(const Duration(milliseconds: 300));
      _expectNoMaterialButtons();
      await tester.tap(find.widgetWithText(AppButton, 'Réessayer'));
      expect(retried, 1);
      expect(tester.takeException(), isNull);
    });
  });
}
