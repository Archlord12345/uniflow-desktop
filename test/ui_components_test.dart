import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniflow/models/app_destination.dart';
import 'package:uniflow/offline/sync_state.dart';
import 'package:uniflow/ui/ui.dart';

import 'layout_test_support.dart';

/// Tests du système de design (`lib/ui/`) : la coquille, la carte KPI, les
/// boutons, les badges et le tableau. Chaque test vérifie aussi l'absence de
/// débordement, la première cause de régression visuelle sur le desktop.
void main() {
  setUpAll(loadTestEnv);

  Future<void> pumpAt(WidgetTester tester, Widget child, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        MediaQuery(data: MediaQueryData(size: size), child: host(child)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  group('AppShell', () {
    testWidgets('en-tête : section, titre, recherche, cloche et avatar',
        (tester) async {
      AppDestination? picked;
      await pumpAt(
        tester,
        AppShell(
          selected: AppDestination.dashboard,
          onSelect: (d) => picked = d,
          body: const SizedBox.expand(),
        ),
        const Size(1366, 768),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Tableau de bord'), findsWidgets);
      expect(find.text('PILOTAGE'), findsWidgets);
      expect(find.byType(SearchField), findsOneWidget);
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
      expect(find.byType(SyncIndicator), findsOneWidget);

      await tester.enterText(find.byType(SearchField), 'emploi');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Emploi du temps').last);
      await tester.pump();
      expect(picked, AppDestination.schedule);
    });

    testWidgets('la recherche se replie et rien ne déborde en 800×600',
        (tester) async {
      await pumpAt(
        tester,
        AppShell(
          selected: AppDestination.schedule,
          onSelect: (_) {},
          body: const SizedBox.expand(),
        ),
        const Size(800, 600),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(SearchField), findsNothing);
    });

    testWidgets('bandeau hors ligne quand l\'état l\'indique', (tester) async {
      const size = Size(1366, 768);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: size),
          child: host(
            AppShell(
              selected: AppDestination.dashboard,
              onSelect: (_) {},
              body: const SizedBox.expand(),
            ),
            overrides: [
              syncStateProvider.overrideWith((ref) => SyncState(
                    status: SyncStatus.offline,
                    pendingWrites: 3,
                    lastSyncAt: DateTime.now(),
                  )),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(OfflineBanner), findsOneWidget);
      expect(find.textContaining('Mode hors ligne'), findsOneWidget);
      expect(find.textContaining('3 modification(s)'), findsOneWidget);
    });
  });

  group('KpiCard', () {
    testWidgets('valeur, libellé, tendance et clic', (tester) async {
      var taps = 0;
      await pumpAt(
        tester,
        Center(
          child: SizedBox(
            width: 220,
            child: KpiCard(
              label: 'Cours inscrits',
              value: '6',
              delta: 'Données réelles',
              icon: Icons.menu_book_outlined,
              tint: AppColors.primary50,
              iconColor: AppColors.primaryBlue,
              onTap: () => taps++,
            ),
          ),
        ),
        const Size(800, 600),
      );
      expect(find.text('6'), findsOneWidget);
      expect(find.text('Cours inscrits'), findsOneWidget);
      expect(find.text('Données réelles'), findsOneWidget);
      await tester.tap(find.byType(KpiCard));
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('une carte KPI étroite tronque sans déborder', (tester) async {
      await pumpAt(
        tester,
        const Center(
          child: SizedBox(
            width: 120,
            child: KpiCard(
              label: 'Un libellé particulièrement long pour une carte',
              value: '1 234 567',
              delta: 'Tendance très longue',
              icon: Icons.school_outlined,
              tint: AppColors.teal50,
              iconColor: AppColors.teal,
            ),
          ),
        ),
        const Size(800, 600),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('AppButton', () {
    testWidgets('désactivé quand onPressed est nul ou en chargement',
        (tester) async {
      var pressed = 0;
      await pumpAt(
        tester,
        Column(children: [
          AppButton(label: 'Actif', onPressed: () => pressed++),
          const AppButton(label: 'Inactif', onPressed: null),
          AppButton(
              label: 'Chargement', loading: true, onPressed: () => pressed++),
          AppButton.danger(label: 'Supprimer', onPressed: () => pressed++),
        ]),
        const Size(800, 600),
      );
      await tester.tap(find.text('Actif'));
      await tester.tap(find.text('Inactif'));
      await tester.tap(find.byType(CircularProgressIndicator));
      expect(pressed, 1);
      expect(tester.takeException(), isNull);
    });
  });

  test('StatusBadge.fromStatus déduit la tonalité', () {
    expect(StatusBadge.fromStatus('Validé').tone, BadgeTone.success);
    expect(StatusBadge.fromStatus('PENDING').tone, BadgeTone.warning);
    expect(StatusBadge.fromStatus('Rejeté').tone, BadgeTone.danger);
    expect(StatusBadge.fromStatus('CM').tone, BadgeTone.primary);
    expect(StatusBadge.fromStatus('TD Gr2').tone, BadgeTone.teal);
    expect(StatusBadge.fromStatus('n\'importe quoi').tone, BadgeTone.neutral);
  });

  testWidgets('AppDataTable partage la largeur et ne déborde pas en 420 px',
      (tester) async {
    await pumpAt(
      tester,
      AppDataTable<int>(
        columns: const [
          AppColumn('Code'),
          AppColumn('Intitulé', flex: 3),
          AppColumn('Statut', width: 90, align: TextAlign.right),
        ],
        rows: List.generate(5, (i) => i),
        cells: (row, _) => [
          Text('ICT10$row', maxLines: 1, overflow: TextOverflow.ellipsis),
          Text('Un intitulé de cours vraiment très long numéro $row',
              maxLines: 1, overflow: TextOverflow.ellipsis),
          StatusBadge.fromStatus(row.isEven ? 'Actif' : 'En attente'),
        ],
      ),
      const Size(420, 620),
    );
    expect(find.text('CODE'), findsOneWidget);
    expect(find.byType(StatusBadge), findsNWidgets(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('EmptyState défile dans un espace contraint', (tester) async {
    await pumpAt(
      tester,
      const SizedBox(
        height: 120,
        child: EmptyState(
          icon: Icons.inbox_outlined,
          title: 'Aucune donnée',
          description: 'Rien à afficher pour le moment.',
          actionLabel: 'Actualiser',
        ),
      ),
      const Size(800, 600),
    );
    expect(tester.takeException(), isNull);
  });

  test('SyncState : libellés', () {
    const offline = SyncState(status: SyncStatus.offline, pendingWrites: 2);
    expect(offline.label, 'Hors ligne · 2 en attente');
    expect(offline.lastSyncLabel, 'jamais synchronisé');
    final synced = SyncState(
        status: SyncStatus.synced, lastSyncAt: DateTime(2026, 9, 20, 8, 5));
    expect(synced.label, 'Synchronisé');
    expect(synced.lastSyncLabel, contains('08:05'));
  });
}
