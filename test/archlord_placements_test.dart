// Placements d'Archlord dans l'application : « À propos » des Paramètres et
// la note de l'écran Conférences. Le dialogue du panneau de connexion est
// couvert par `auth_layout_test.dart`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniflow/app_info.dart';
import 'package:uniflow/screens/management_screens.dart';
import 'package:uniflow/widgets/uni/archlord_mascot.dart';

import 'layout_test_support.dart';

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

void main() {
  setUpAll(loadTestEnv);

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
        expect(find.textContaining('version ${AppInfo.version}'), findsOneWidget);
        expect(find.text(AppInfo.publisherPitch), findsOneWidget);
        expect(find.byType(ArchlordUniFistBump), findsOneWidget);
        expect(find.byType(ArchlordMascot), findsOneWidget);
      });
    }

    testWidgets('les Paramètres embarquent « À propos »', (tester) async {
      await _pump(tester, const SettingsScreen(), const Size(1280, 800));
      // Le panneau est en bas de page : on le fait défiler dans la vue.
      await tester.scrollUntilVisible(find.byType(AboutPanel), 200);
      expect(find.byType(AboutPanel), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('ConferencesScreen', () {
    testWidgets('sans réunion, Archlord rappelle que le serveur est local',
        (tester) async {
      await _pump(tester, const ConferencesScreen(), const Size(1280, 800));
      expect(find.byType(ArchlordMascot), findsOneWidget);
      expect(find.textContaining('aucun Internet requis'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
