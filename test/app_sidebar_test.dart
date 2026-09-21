// La barre latérale suit les planches (`docs/design/`) : claire en thème
// clair, entrée active sur `primary50` avec texte `primaryBlue` ; le dégradé
// bleu nuit ne subsiste qu'en thème sombre.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniflow/models/app_destination.dart';
import 'package:uniflow/providers/appwrite_provider.dart';
import 'package:uniflow/providers/auth_provider.dart';
import 'package:uniflow/services/appwrite_service.dart';
import 'package:uniflow/theme/app_theme.dart';
import 'package:uniflow/widgets/app_sidebar.dart';

import 'layout_test_support.dart';

Future<void> _pump(WidgetTester tester,
    {required ThemeData theme, bool collapsed = false}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => testUser()),
        appwriteServiceProvider.overrideWithValue(AppwriteService()),
      ],
      child: MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Row(
            children: [
              AppSidebar(
                selected: AppDestination.teachers,
                onSelect: (_) {},
                collapsed: collapsed,
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 800));
}

/// Le conteneur animé de la ligne active : celui qui porte la couleur.
AnimatedContainer _activeTile(WidgetTester tester) {
  final label = find.text(AppDestination.teachers.label);
  return tester.widget<AnimatedContainer>(
    find.ancestor(of: label, matching: find.byType(AnimatedContainer)).first,
  );
}

void main() {
  setUpAll(loadTestEnv);

  test('SidebarPalette : claire par défaut, sombre en thème sombre', () {
    expect(SidebarPalette.light.background, AppColors.cardWhite);
    expect(SidebarPalette.light.activeBackground, AppColors.primary50);
    expect(SidebarPalette.light.activeForeground, AppColors.primaryBlue);
    expect(SidebarPalette.light.isDark, isFalse);
    expect(SidebarPalette.dark.isDark, isTrue);
  });

  testWidgets('thème clair : fond blanc, entrée active primary50 / primaryBlue',
      (tester) async {
    await _pump(tester, theme: AppTheme.lightTheme);
    expect(tester.takeException(), isNull);

    final sidebar = tester.widget<AnimatedContainer>(
      find
          .descendant(
              of: find.byType(AppSidebar),
              matching: find.byType(AnimatedContainer))
          .first,
    );
    final decoration = sidebar.decoration as BoxDecoration;
    expect(decoration.color, AppColors.cardWhite);
    expect(decoration.gradient, isNull);

    final active = _activeTile(tester).decoration as BoxDecoration;
    expect(active.color, AppColors.primary50);
    final label = tester.widget<Text>(find.text(AppDestination.teachers.label));
    expect(label.style?.color, AppColors.primaryBlue);
    expect(label.style?.fontWeight, FontWeight.w700);
  });

  testWidgets('thème sombre : le dégradé bleu nuit est conservé',
      (tester) async {
    await _pump(tester, theme: AppTheme.darkTheme);
    expect(tester.takeException(), isNull);
    final sidebar = tester.widget<AnimatedContainer>(
      find
          .descendant(
              of: find.byType(AppSidebar),
              matching: find.byType(AnimatedContainer))
          .first,
    );
    final decoration = sidebar.decoration as BoxDecoration;
    expect(decoration.gradient, isNotNull);
    final active = _activeTile(tester).decoration as BoxDecoration;
    expect(active.color, AppColors.sidebarActive);
  });

  testWidgets('repliée : rail d’icônes de 72 px, sans débordement',
      (tester) async {
    await _pump(tester, theme: AppTheme.lightTheme, collapsed: true);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(AppSidebar)).width, AppSidebar.railWidth);
    expect(find.text(AppDestination.teachers.label), findsNothing);
  });
}
