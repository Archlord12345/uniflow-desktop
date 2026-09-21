// Panneau « Présence » de la console des conférences : état vide, feuille en
// direct, réunions terminées, export ; aucun débordement en 1280×800 et
// 1440×900, texte normal et agrandi.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniflow/providers/attendance_provider.dart';
import 'package:uniflow/screens/conference_attendance_panel.dart';
import 'package:uniflow/screens/management_screens.dart';
import 'package:uniflow/services/conference/attendance_export_service.dart';
import 'package:uniflow/services/conference/attendance_store.dart';
import 'package:uniflow/services/conference/conference_attendance.dart';
import 'package:uniflow/theme/app_theme.dart';
import 'package:uniflow/ui/app_button.dart';
import 'package:uniflow/ui/status_badge.dart';
import 'package:uniflow/widgets/uni/uni_mascot.dart';

import 'layout_test_support.dart';

const List<Size> _sizes = [Size(1280, 800), Size(1440, 900)];
const List<double> _scales = [1.0, 1.3];

final DateTime _t0 = DateTime(2026, 9, 21, 8, 0);
DateTime _at(int minutes) => _t0.add(Duration(minutes: minutes));

/// Réunion en cours : un connecté, un parti tôt, un invité jamais venu.
ConferenceAttendance _liveSheet() => ConferenceAttendance(
      conferenceId: 'kf-live',
      title: 'Cours de Réseaux — L3',
      hostId: 'host-1',
      hostName: 'Pr. Fouda',
      startedAt: DateTime.now().subtract(const Duration(minutes: 30)),
    )
        .recordTicket(identity: 'alice', displayName: 'Alice Kamga', userId: 'u-alice', at: DateTime.now().subtract(const Duration(minutes: 30)))
        .recordJoin(identity: 'alice', at: DateTime.now().subtract(const Duration(minutes: 29)))
        .recordJoin(identity: 'bob', displayName: 'Bob Essomba', at: DateTime.now().subtract(const Duration(minutes: 28)))
        .recordLeave(identity: 'bob', at: DateTime.now().subtract(const Duration(minutes: 25)))
        .recordTicket(identity: 'chloe', displayName: 'Chloé Mbappé', at: DateTime.now().subtract(const Duration(minutes: 20)));

ConferenceAttendance _pastSheet() => ConferenceAttendance(
      conferenceId: 'kf-past',
      title: 'TD Algorithmique — L2',
      hostId: 'host-1',
      hostName: 'Dr. Nkolo',
      startedAt: _t0,
    )
        .recordJoin(identity: 'dan', displayName: 'Dan Ekwalla', at: _at(1))
        .recordLeave(identity: 'dan', at: _at(58))
        .recordJoin(identity: 'eva', displayName: 'Eva Nkolo', at: _at(2))
        .recordLeave(identity: 'eva', at: _at(12))
        .close(at: _at(60));

/// Contrôleur de présence préchargé : le panneau se teste sans serveur média.
class _SeededLiveAttendance extends LiveAttendanceController {
  final ConferenceAttendance? seed;
  _SeededLiveAttendance(this.seed);

  @override
  ConferenceAttendance? build() {
    super.build();
    return seed;
  }
}

Future<void> _pumpAt(
  WidgetTester tester,
  Widget child, {
  required Size size,
  required double scale,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
      child: host(child, overrides: overrides),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// Le panneau seul, sans le harnais complet : `host()` instancie le client
/// Appwrite, dont l'initialisation appelle `path_provider` dès que la boucle
/// d'événements réelle tourne (`runAsync`) — et lève `MissingPluginException`
/// dans un test. Le panneau ne lit que les providers de présence.
Future<void> _pumpPanel(
  WidgetTester tester, {
  required Size size,
  double scale = 1.0,
  required List<Override> overrides,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
          data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
          child: const Scaffold(
              body: SingleChildScrollView(child: AttendancePanel())),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUpAll(loadTestEnv);

  group('État vide', () {
    for (final size in _sizes) {
      for (final scale in _scales) {
        testWidgets(
            'Uni et l\'explication, sans débordement en '
            '${size.width.toInt()}×${size.height.toInt()} (texte ×$scale)',
            (tester) async {
          await _pumpAt(tester, const ConferencesScreen(),
              size: size, scale: scale);
          expect(tester.takeException(), isNull);
          expect(find.text('Aucune feuille de présence'), findsOneWidget);
          expect(find.byType(AttendancePanel), findsOneWidget);
          expect(
            find.descendant(
                of: find.byType(AttendancePanel),
                matching: find.byType(UniMascot)),
            findsOneWidget,
          );
        });
      }
    }
  });

  group('Feuille en direct et réunions terminées', () {
    List<Override> overrides() => [
          liveAttendanceProvider
              .overrideWith(() => _SeededLiveAttendance(_liveSheet())),
          attendanceStoreProvider
              .overrideWithValue(InMemoryAttendanceStore([_pastSheet()])),
        ];

    for (final size in _sizes) {
      for (final scale in _scales) {
        testWidgets(
            'liste, compteurs et statuts en '
            '${size.width.toInt()}×${size.height.toInt()} (texte ×$scale)',
            (tester) async {
          await _pumpPanel(tester,
              size: size, scale: scale, overrides: overrides());
          expect(tester.takeException(), isNull);

          expect(find.text('En direct'), findsOneWidget);
          expect(find.text('Alice Kamga'), findsOneWidget);
          expect(find.text('u-alice'), findsOneWidget);
          expect(find.text('Bob Essomba'), findsOneWidget);
          expect(find.text('Chloé Mbappé'), findsOneWidget);
          expect(find.textContaining('1 en ligne · 1 présent / 3 invités'),
              findsOneWidget);
          // Alice connectée depuis le début : présente ; Bob parti après
          // 3 minutes sur 30 : partiel ; Chloé jamais venue : absente.
          expect(find.widgetWithText(StatusBadge, 'Présent'), findsOneWidget);
          expect(find.widgetWithText(StatusBadge, 'Partiel'), findsOneWidget);
          expect(find.widgetWithText(StatusBadge, 'Absent'), findsOneWidget);
          expect(find.text('En ligne'), findsOneWidget);

          expect(find.text('Réunions terminées'), findsOneWidget);
          expect(find.text('TD Algorithmique — L2'), findsOneWidget);
          expect(find.text('1 présent / 2 invités'), findsOneWidget);
          // Pas de mascotte quand il y a des données.
          expect(find.byType(UniMascot), findsNothing);
        });
      }
    }

    testWidgets('le seuil se change depuis le panneau', (tester) async {
      await _pumpPanel(tester,
          size: const Size(1280, 800), overrides: overrides());
      await tester.tap(find.text('Seuil 50 %'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Seuil 25 %').last);
      // Le menu se referme avec une animation : tant qu'elle court, l'option
      // et la valeur affichée coexistent.
      await tester.pumpAndSettle();
      expect(find.text('Seuil 25 %'), findsOneWidget);
      // Bob (3 min sur 30, soit 10 %) reste partiel ; le seuil est bien
      // relu depuis la feuille.
      expect(find.widgetWithText(StatusBadge, 'Partiel'), findsOneWidget);
    });

    testWidgets('le détail d\'une réunion terminée s\'ouvre au clic',
        (tester) async {
      await _pumpPanel(tester,
          size: const Size(1440, 900), overrides: overrides());
      await tester.tap(find.text('TD Algorithmique — L2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.text('Dan Ekwalla'), findsOneWidget);
      expect(find.text('Eva Nkolo'), findsOneWidget);
      expect(find.text('Présents 1'), findsOneWidget);
      expect(find.text('Partiels 1'), findsOneWidget);
      expect(find.text('Seuil 50 % (30 min)'), findsOneWidget);
    });
  });

  group('Export', () {
    late Directory temp;
    final opened = <Uri>[];

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('uniflow-panel-exports-');
      opened.clear();
    });

    tearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    testWidgets('le bouton PDF écrit le fichier et propose de l\'ouvrir',
        (tester) async {
      await _pumpPanel(
        tester,
        size: const Size(1280, 800),
        overrides: [
          liveAttendanceProvider
              .overrideWith(() => _SeededLiveAttendance(_liveSheet())),
          attendanceStoreProvider.overrideWithValue(InMemoryAttendanceStore()),
          attendanceExportServiceProvider.overrideWithValue(
            AttendanceExportService(
              resolveDirectory: () async => temp,
              launch: (uri) async {
                opened.add(uri);
                return true;
              },
              loadAsset: (key) async => null,
            ),
          ),
        ],
      );

      // Le rendu du PDF et l'écriture du fichier sont de vraies opérations
      // asynchrones : elles n'avancent pas dans l'horloge simulée du test,
      // `runAsync` leur rend la boucle d'événements réelle.
      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(AppButton, 'PDF'));
        for (var i = 0; i < 100 && temp.listSync().isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Export PDF enregistré'), findsOneWidget);
      final written = temp.listSync().whereType<File>().toList();
      expect(written, hasLength(1));
      expect(written.single.path, endsWith('presence-cours-de-reseaux-l3-${_isoToday()}.pdf'));

      // La suite de `_export` (ouverture) vit dans la même chaîne asynchrone
      // réelle que l'export : on lui rend la boucle d'événements de la même
      // façon.
      await tester.runAsync(() async {
        await tester.tap(find.text('Ouvrir le fichier'));
        for (var i = 0; i < 50 && opened.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(opened, hasLength(1));
      expect(opened.single.scheme, 'file');
      expect(tester.takeException(), isNull);
    });
  });
}

String _isoToday() {
  final now = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${now.year}-${two(now.month)}-${two(now.day)}';
}
