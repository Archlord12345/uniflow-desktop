import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniflow/widgets/uni/archlord_mascot.dart';
import 'package:uniflow/widgets/uni/mascot_dialogue.dart';
import 'package:uniflow/widgets/uni/uni_mascot.dart';

Widget _wrap(Widget child, {bool reduceMotion = false, double width = 700}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: MaterialApp(
      home: Scaffold(
        body:
            Center(child: SizedBox(width: width, child: Center(child: child))),
      ),
    ),
  );
}

const _lines = [
  MascotLine.archlord('Bonjour, je suis Archlord.'),
  MascotLine.uni('Et moi Uni !'),
  MascotLine.archlord('Ensemble, on fait UniFlow.'),
];

/// Laisse l'`AnimatedSwitcher` démarrer sa transition (une frame), la finir
/// (sa durée) **et** retirer l'ancienne bulle : le retrait passe par un
/// `setState` déclenché en fin d'animation, donc il faut une frame de plus.
/// Sans la première frame, un clic laissait deux bulles visibles dans le test.
Future<void> _settleSwitch(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

void main() {
  group('ArchlordPose', () {
    test('chaque pose pointe un asset WebP embarqué', () {
      for (final pose in ArchlordPose.values) {
        expect(pose.asset, startsWith('assets/mascot/archlord_'));
        expect(pose.asset, endsWith('.webp'));
        expect(pose.ratio, greaterThan(0));
        expect(pose.ratio, lessThan(1),
            reason: 'un humain debout est plus haut que large');
        expect(pose.alt, isNotEmpty);
      }
      expect(ArchlordUniScene.fistBumpAsset,
          startsWith('assets/mascot/archlord_uni_'));
    });
  });

  group('ArchlordMascot', () {
    testWidgets('réserve la boîte au ratio de la pose et expose l’alt',
        (tester) async {
      await tester.pumpWidget(
          _wrap(const ArchlordMascot(pose: ArchlordPose.wave, size: 120)));
      await tester.pump(const Duration(milliseconds: 600));
      final box = tester.getSize(find.byType(Image));
      expect(box.height, 120);
      expect(box.width, closeTo(120 * ArchlordPose.wave.ratio, 0.5));
      expect(find.bySemanticsLabel(ArchlordPose.wave.alt), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('la bulle s’affiche des trois côtés sans déborder',
        (tester) async {
      for (final side in UniBubbleSide.values) {
        await tester.pumpWidget(_wrap(
          ArchlordMascot(
            pose: ArchlordPose.explain,
            size: 100,
            speaking: true,
            bubble: const Text('Le serveur tourne sur ce poste.'),
            bubbleSide: side,
          ),
        ));
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('Le serveur tourne sur ce poste.'), findsOneWidget,
            reason: '$side');
        expect(find.byType(UniBubble), findsOneWidget);
        expect(tester.takeException(), isNull,
            reason: 'débordement côté $side');
      }
    });

    testWidgets('la boucle tourne quand il parle et se coupe sans mouvement',
        (tester) async {
      await tester.pumpWidget(_wrap(
          const ArchlordMascot(pose: ArchlordPose.explain, speaking: true)));
      await tester.pump(const Duration(milliseconds: 500));
      // Une boucle infinie laisse toujours des frames planifiées.
      expect(tester.binding.hasScheduledFrame, isTrue);

      await tester.pumpWidget(_wrap(
        const ArchlordMascot(pose: ArchlordPose.explain, speaking: true),
        reduceMotion: true,
      ));
      // Avec une animation infinie, pumpAndSettle expirerait ; ici elle doit
      // se stabiliser, preuve que la boucle est coupée.
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('still coupe la boucle même avec animations autorisées',
        (tester) async {
      await tester.pumpWidget(
          _wrap(const ArchlordMascot(pose: ArchlordPose.thumbs, still: true)));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('onTap rend le personnage cliquable', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(
        ArchlordMascot(
            pose: ArchlordPose.pointing, size: 100, onTap: () => taps++),
      ));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.byType(Image));
      expect(taps, 1);
    });
  });

  group('ArchlordUniFistBump', () {
    testWidgets('respecte le ratio de la scène et se stabilise sans mouvement',
        (tester) async {
      await tester.pumpWidget(
          _wrap(const ArchlordUniFistBump(size: 100), reduceMotion: true));
      await tester.pumpAndSettle();
      final box = tester.getSize(find.byType(Image));
      expect(box.height, 100);
      expect(box.width, closeTo(100 * ArchlordUniScene.fistBumpRatio, 0.5));
      expect(
          find.bySemanticsLabel(ArchlordUniScene.fistBumpAlt), findsOneWidget);
    });
  });

  group('MascotDialogue', () {
    testWidgets(
        'montre une réplique à la fois et avance toutes les 3,5 s en boucle',
        (tester) async {
      await tester
          .pumpWidget(_wrap(const MascotDialogue(lines: _lines, size: 100)));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text(_lines[0].text), findsOneWidget);
      expect(find.text(_lines[1].text), findsNothing);

      await tester.pump(kMascotDialogueInterval);
      await _settleSwitch(tester);
      expect(find.text(_lines[1].text), findsOneWidget);
      expect(find.text(_lines[0].text), findsNothing);

      await tester.pump(kMascotDialogueInterval);
      await _settleSwitch(tester);
      expect(find.text(_lines[2].text), findsOneWidget);

      // Après la dernière, on repart de la première : la boucle est infinie.
      await tester.pump(kMascotDialogueInterval);
      await _settleSwitch(tester);
      expect(find.text(_lines[0].text), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('un clic passe à la réplique suivante et relance la cadence',
        (tester) async {
      await tester
          .pumpWidget(_wrap(const MascotDialogue(lines: _lines, size: 100)));
      await tester.pump(const Duration(milliseconds: 600));
      // À 3,1 s, on est à 0,4 s de l'avancement automatique.
      await tester.pump(const Duration(milliseconds: 2500));
      await tester.tap(find.byType(MascotDialogue));
      await _settleSwitch(tester);
      expect(find.text(_lines[1].text), findsOneWidget);

      // Sans remise à zéro, l'ancien minuteur aurait sauté à la 3e réplique
      // dans la seconde qui suit le clic.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.text(_lines[1].text), findsOneWidget);
      expect(find.text(_lines[2].text), findsNothing);
    });

    testWidgets('la queue de la bulle pointe vers le locuteur', (tester) async {
      await tester
          .pumpWidget(_wrap(const MascotDialogue(lines: _lines, size: 100)));
      await tester.pump(const Duration(milliseconds: 600));
      // Archlord est à gauche : la bulle est « à droite » du personnage.
      expect(tester.widget<UniBubble>(find.byType(UniBubble)).side,
          UniBubbleSide.right);
      await tester.tap(find.byType(MascotDialogue));
      await _settleSwitch(tester);
      expect(tester.widget<UniBubble>(find.byType(UniBubble)).side,
          UniBubbleSide.left);
    });

    testWidgets('le locuteur s’anime, l’autre écoute immobile', (tester) async {
      await tester
          .pumpWidget(_wrap(const MascotDialogue(lines: _lines, size: 100)));
      await tester.pump(const Duration(milliseconds: 600));
      var archlord = tester.widget<ArchlordMascot>(find.byType(ArchlordMascot));
      var uni = tester.widget<UniMascot>(find.byType(UniMascot));
      expect(archlord.speaking, isTrue);
      expect(archlord.still, isFalse);
      expect(uni.still, isTrue);

      await tester.tap(find.byType(MascotDialogue));
      await _settleSwitch(tester);
      archlord = tester.widget<ArchlordMascot>(find.byType(ArchlordMascot));
      uni = tester.widget<UniMascot>(find.byType(UniMascot));
      expect(archlord.speaking, isFalse);
      expect(archlord.still, isTrue);
      expect(uni.still, isFalse);
    });

    testWidgets(
        'sans mouvement, toutes les répliques sont visibles et rien ne tourne',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const MascotDialogue(lines: _lines, size: 100),
        reduceMotion: true,
      ));
      await tester.pumpAndSettle();
      for (final line in _lines) {
        expect(find.text(line.text), findsOneWidget);
      }
      expect(find.byType(UniBubble), findsNWidgets(_lines.length));
      expect(tester.takeException(), isNull);
    });

    testWidgets('autoAdvance désactivé : la réplique reste, le clic avance',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const MascotDialogue(lines: _lines, size: 100, autoAdvance: false),
      ));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(seconds: 8));
      expect(find.text(_lines[0].text), findsOneWidget);
      await tester.tap(find.byType(MascotDialogue));
      await _settleSwitch(tester);
      expect(find.text(_lines[1].text), findsOneWidget);
    });

    testWidgets('tient dans une colonne étroite sans déborder', (tester) async {
      await tester.pumpWidget(_wrap(
        const MascotDialogue(lines: _lines, size: 110),
        width: 360,
      ));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
      expect(find.text(_lines[0].text), findsOneWidget);
    });
  });
}
