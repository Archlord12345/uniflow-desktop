// Icônes Phosphor communes (spec `docs/icones-uniflow.md`) : table
// `subjectIcon`, couleur `subjectColor`, tuile `IconTile`, et le style
// actif/inactif de la barre latérale.
//
// Symptôme d'origine : le desktop affichait des icônes Material filaires là
// où le web et le mobile ont des tuiles Phosphor pleines ; la même matière
// n'avait pas la même icône d'une application à l'autre.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uniflow/models/app_destination.dart';
import 'package:uniflow/providers/appwrite_provider.dart';
import 'package:uniflow/providers/auth_provider.dart';
import 'package:uniflow/services/appwrite_service.dart';
import 'package:uniflow/theme/app_theme.dart';
import 'package:uniflow/widgets/app_sidebar.dart';
import 'package:uniflow/widgets/uni_icons.dart';

import 'layout_test_support.dart';

Finder _inTile<T extends Widget>() =>
    find.descendant(of: find.byType(IconTile), matching: find.byType(T));

void main() {
  setUpAll(loadTestEnv);
  const duotone = UniIconStyle.duotone;

  group('subjectIcon', () {
    test('table des mots-clés', () {
      expect(subjectIcon('Mathématiques'), UniIcons.mathOperations(duotone));
      expect(subjectIcon('Physique quantique'), UniIcons.atom(duotone));
      expect(subjectIcon('Chimie organique'), UniIcons.flask(duotone));
      expect(subjectIcon('Biologie cellulaire'), UniIcons.dna(duotone));
      expect(subjectIcon('Réseaux informatiques'), UniIcons.network(duotone));
      expect(subjectIcon('Sécurité des SI'), UniIcons.security(duotone));
      expect(subjectIcon('Cloud & DevOps'), UniIcons.cloud(duotone));
      expect(subjectIcon('Statistiques'), UniIcons.chartLine(duotone));
      expect(subjectIcon('Anglais technique'), UniIcons.language(duotone));
      expect(subjectIcon('Entrepreneuriat'), UniIcons.rocket(duotone));
      expect(subjectIcon('Projet tutoré'), UniIcons.kanban(duotone));
      expect(subjectIcon('Algorithmique'), UniIcons.code(duotone));
      expect(subjectIcon('Gestion financière'), UniIcons.coins(duotone));
      expect(subjectIcon('Droit des affaires'), UniIcons.scales(duotone));
      expect(subjectIcon('Histoire moderne'), UniIcons.scroll(duotone));
      expect(subjectIcon('Géographie'), UniIcons.globeHemisphereWest(duotone));
      expect(subjectIcon('Électronique'), UniIcons.lightning(duotone));
      expect(subjectIcon('Musique'), UniIcons.musicNotes(duotone));
      expect(subjectIcon('Design graphique'), UniIcons.palette(duotone));
      expect(subjectIcon('Sport'), UniIcons.barbell(duotone));
      expect(subjectIcon('Santé publique'), UniIcons.firstAid(duotone));
      expect(subjectIcon('Télécommunications'), UniIcons.broadcast(duotone));
      expect(subjectIcon('Philosophie'), UniIcons.feather(duotone));
      expect(
          subjectIcon('Applications mobiles'), UniIcons.deviceMobile(duotone));
    });

    test('BookOpen par défaut', () {
      expect(subjectIcon('Séminaire'), UniIcons.bookOpen(duotone));
      expect(subjectIcon(''), UniIcons.bookOpen(duotone));
    });

    test('insensible à la casse et aux accents', () {
      expect(subjectIcon('ALGÈBRE LINÉAIRE'), UniIcons.mathOperations(duotone));
      expect(subjectIcon('algebre lineaire'), UniIcons.mathOperations(duotone));
      expect(subjectIcon('SÉCURITÉ'), UniIcons.security(duotone));
      expect(subjectIcon('Économie'), UniIcons.coins(duotone));
    });

    test('l\'ordre des mots-clés : les quatre exemples de la spec', () {
      expect(subjectIcon('Développement web'), UniIcons.globe(duotone));
      expect(
          subjectIcon('Bases de données avancées'), UniIcons.database(duotone));
      expect(subjectIcon('Systèmes d\'exploitation (Linux)'),
          UniIcons.terminal(duotone));
      expect(subjectIcon('Intelligence artificielle et science des données'),
          UniIcons.brain(duotone));
    });

    test('« ia » n\'est reconnu qu\'en mot entier', () {
      // « matériaux » et « sociales » contiennent « ia » : ils ne doivent pas
      // devenir Brain.
      expect(subjectIcon('Sciences des matériaux'), UniIcons.bookOpen(duotone));
      expect(subjectIcon('Cours IA'), UniIcons.brain(duotone));
    });

    test('le code est consulté après le nom', () {
      expect(subjectIcon('UE 12', code: 'MATH201'),
          UniIcons.mathOperations(duotone));
      expect(subjectIcon('Physique', code: 'MATH201'), UniIcons.atom(duotone));
    });

    test('le style demandé est respecté', () {
      expect(subjectIcon('Physique', style: UniIconStyle.fill),
          UniIcons.atom(UniIconStyle.fill));
    });
  });

  group('subjectColor', () {
    test('colorHex prime, avec ou sans dièse', () {
      expect(subjectColor('X', colorHex: '#EC4899'), const Color(0xFFEC4899));
      expect(subjectColor('X', colorHex: 'f97316'), const Color(0xFFF97316));
    });

    test('un colorHex invalide retombe sur la palette', () {
      final fallback = subjectColor('INF101');
      expect(subjectColor('INF101', colorHex: 'rouge'), fallback);
      expect(subjectColor('INF101', colorHex: ''), fallback);
      expect(subjectPalette, contains(fallback));
    });

    test('même code → même couleur, hachage stable', () {
      expect(subjectColor('INF101'), subjectColor('INF101'));
      expect(subjectColor(' INF101 '), subjectColor('INF101'));
      expect(subjectColor('inf101'), subjectColor('INF101'));
    });

    test('le hachage est FNV-1a 32 bits, comme `stableHash` du web', () {
      // Vecteurs de référence de FNV-1a : si l'un change, la couleur d'un
      // cours diverge entre le web et le desktop.
      expect(stableSubjectHash(''), 0x811c9dc5);
      expect(stableSubjectHash('a'), 0xe40c292c);
      expect(stableSubjectHash('foobar'), 0xbf9cf968);
    });

    test('#RGB est développé en #RRGGBB', () {
      expect(parseHexColor('#f80'), const Color(0xFFFF8800));
    });

    test('la palette est celle de la spec', () {
      expect(subjectPalette, [
        AppColors.teal,
        AppColors.primaryBlue,
        AppColors.purple,
        AppColors.warning,
        AppColors.success,
        const Color(0xFFEC4899),
        const Color(0xFFF97316),
      ]);
    });
  });

  group('IconTile', () {
    Widget host(Widget child, {bool disableAnimations = false}) => MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: disableAnimations),
            child: Scaffold(body: Center(child: child)),
          ),
        );

    testWidgets('les deux variantes se construisent à la taille demandée',
        (tester) async {
      await tester.pumpWidget(host(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconTile(
            key: const ValueKey('filled'),
            icon: UniIcons.courses(),
            color: AppColors.teal,
            size: 56,
          ),
          IconTile(
            key: const ValueKey('soft'),
            icon: UniIcons.courses(),
            color: AppColors.teal,
            size: 36,
            variant: IconTileVariant.soft,
            index: 3,
          ),
        ],
      )));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byKey(const ValueKey('filled'))),
          const Size(56, 56));
      expect(tester.getSize(find.byKey(const ValueKey('soft'))),
          const Size(36, 36));
      expect(find.byType(PhosphorIcon), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('l\'apparition en cascade se termine (pumpAndSettle)',
        (tester) async {
      await tester.pumpWidget(host(IconTile(
        icon: UniIcons.grades(),
        color: AppColors.purple,
        index: IconTile.maxCascadeIndex + 20,
      )));
      // Cibler la tuile : la transition de page de MaterialApp porte aussi
      // un FadeTransition.
      final fade = tester.widget<FadeTransition>(_inTile<FadeTransition>());
      expect(fade.opacity.value, 0);

      await tester.pumpAndSettle();
      expect(fade.opacity.value, 1);
      // `.first` : l'AnimatedScale de pression pose lui aussi un
      // ScaleTransition, sous celui de l'apparition.
      final scale =
          tester.widget<ScaleTransition>(_inTile<ScaleTransition>().first);
      expect(scale.scale.value, 1);
    });

    testWidgets('sans animation quand MediaQuery.disableAnimations est vrai',
        (tester) async {
      await tester.pumpWidget(
        host(
          IconTile(icon: UniIcons.grades(), color: AppColors.purple, index: 4),
          disableAnimations: true,
        ),
      );
      // Dès la première frame, la tuile est entièrement visible et à l'échelle
      // finale : l'apparition n'a pas été jouée.
      final fade = tester.widget<FadeTransition>(_inTile<FadeTransition>());
      expect(fade.opacity.value, 1);
      final scale =
          tester.widget<ScaleTransition>(_inTile<ScaleTransition>().first);
      expect(scale.scale.value, 1);
    });

    testWidgets('pression et survol : onTap déclenché, aucune exception',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(IconTile(
        icon: UniIcons.video(),
        color: AppColors.primaryBlue,
        onTap: () => taps++,
        tooltip: 'Visioconférence',
      )));
      await tester.pumpAndSettle();

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.byType(IconTile)));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(IconTile));
      await tester.pumpAndSettle();

      expect(taps, 1);
      expect(find.byType(Tooltip), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('navigation', () {
    test('AppDestination expose une icône Phosphor dans le style demandé', () {
      expect(AppDestination.dashboard.icon(UniIconStyle.fill),
          UniIcons.dashboard(UniIconStyle.fill));
      expect(AppDestination.schedule.icon(UniIconStyle.bold),
          UniIcons.schedule(UniIconStyle.bold));
      expect(AppDestination.settings.icon(),
          UniIcons.settings(UniIconStyle.duotone));
    });

    testWidgets('la barre latérale : fill pour l\'actif, bold pour les autres',
        (tester) async {
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
            home: Scaffold(
              body: Row(
                children: [
                  AppSidebar(
                    selected: AppDestination.dashboard,
                    onSelect: (_) {},
                  ),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
          find.byIcon(UniIcons.dashboard(UniIconStyle.fill)), findsOneWidget);
      expect(find.byIcon(UniIcons.dashboard(UniIconStyle.bold)), findsNothing);
      // Les réglages ne sont pas dans la barre (menu de l'avatar) : on vérifie
      // le `bold` sur une destination inactive réellement listée.
      expect(find.byIcon(UniIcons.schedule(UniIconStyle.bold)), findsOneWidget);
    });
  });
}
