import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'archlord_mascot.dart';
import 'uni_mascot.dart';

/// Qui parle dans un [MascotDialogue].
enum MascotSpeaker { archlord, uni }

/// Une réplique : le locuteur et son texte.
class MascotLine {
  final MascotSpeaker who;
  final String text;

  const MascotLine(this.who, this.text);
  const MascotLine.archlord(this.text) : who = MascotSpeaker.archlord;
  const MascotLine.uni(this.text) : who = MascotSpeaker.uni;
}

/// Cadence par défaut : assez lente pour lire une phrase, assez rapide pour
/// qu'un écran de connexion ne semble pas figé.
const Duration kMascotDialogueInterval = Duration(milliseconds: 3500);

/// Archlord (à gauche) et Uni (à droite) échangent des répliques, une bulle
/// à la fois entre les deux personnages, la queue tournée vers celui qui
/// parle. Le locuteur s'anime, l'autre écoute immobile.
///
/// L'avancement est automatique (toutes les [interval]) et au clic ; il boucle.
/// Quand le système demande de réduire les animations, toutes les répliques
/// s'affichent d'un coup, statiquement : rien ne bouge, rien n'est caché.
class MascotDialogue extends StatefulWidget {
  final List<MascotLine> lines;

  /// Hauteur des personnages.
  final double size;

  final Duration interval;

  /// Coupe l'avancement automatique (le clic reste actif).
  final bool autoAdvance;

  final ArchlordPose archlordPose;
  final UniPose uniPose;

  /// Style du texte des bulles ; par défaut celui de [UniBubble].
  final TextStyle? textStyle;

  const MascotDialogue({
    super.key,
    required this.lines,
    this.size = 140,
    this.interval = kMascotDialogueInterval,
    this.autoAdvance = true,
    this.archlordPose = ArchlordPose.explain,
    this.uniPose = UniPose.wave,
    this.textStyle,
  });

  @override
  State<MascotDialogue> createState() => _MascotDialogueState();
}

class _MascotDialogueState extends State<MascotDialogue> {
  int _index = 0;
  Timer? _timer;

  bool get _reduceMotion =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant MascotDialogue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index >= widget.lines.length) _index = 0;
    _syncTimer();
  }

  /// Le minuteur ne tourne que s'il a quelque chose à faire : plusieurs
  /// répliques, avancement automatique demandé et animations autorisées.
  void _syncTimer() {
    _timer?.cancel();
    _timer = null;
    final active =
        widget.autoAdvance && !_reduceMotion && widget.lines.length > 1;
    if (active) {
      _timer = Timer.periodic(widget.interval, (_) => _advance());
    }
  }

  void _advance() {
    if (!mounted) return;
    setState(() => _index = (_index + 1) % widget.lines.length);
  }

  /// Au clic on passe tout de suite à la suite, et on repart de zéro pour la
  /// cadence : sinon la réplique suivante pouvait disparaître une fraction de
  /// seconde après être apparue.
  void _onTap() {
    _advance();
    _syncTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Sans réplique, pas de dialogue : les deux personnages se tiennent
    // simplement côte à côte (les listes peuvent venir d'un contenu distant).
    if (widget.lines.isEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ArchlordMascot(pose: widget.archlordPose, size: widget.size),
          const SizedBox(width: AppSpacing.md),
          UniMascot(pose: widget.uniPose, size: widget.size),
        ],
      );
    }
    final reduce = _reduceMotion;
    final line = widget.lines[_index];
    final speaker = reduce ? null : line.who;
    // Sans style imposé, le texte hérite de celui de `UniBubble` : les bulles
    // du dialogue ressemblent alors à celles d'Uni partout ailleurs.
    final style = widget.textStyle;

    final archlord = ArchlordMascot(
      pose: widget.archlordPose,
      size: widget.size,
      still: speaker != MascotSpeaker.archlord,
      speaking: speaker == MascotSpeaker.archlord,
    );
    final uni = UniMascot(
      pose: widget.uniPose,
      size: widget.size,
      still: speaker != MascotSpeaker.uni,
    );

    final Widget middle;
    if (reduce) {
      middle = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < widget.lines.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.xs),
            _Speech(line: widget.lines[i], style: style),
          ],
        ],
      );
    } else {
      middle = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween(begin: 0.94, end: 1.0).animate(animation),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey(_index),
              child: _Speech(line: line, style: style),
            ),
          ),
          if (widget.lines.length > 1) ...[
            const SizedBox(height: AppSpacing.sm),
            _Dots(count: widget.lines.length, active: _index),
          ],
        ],
      );
    }

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        archlord,
        const SizedBox(width: AppSpacing.sm),
        Flexible(child: middle),
        const SizedBox(width: AppSpacing.sm),
        uni,
      ],
    );

    if (reduce) return row;
    return Semantics(
      button: true,
      label: 'Réplique suivante',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
        child: MouseRegion(cursor: SystemMouseCursors.click, child: row),
      ),
    );
  }
}

/// Une bulle dont la queue pointe vers le locuteur : Archlord est à gauche,
/// donc sa bulle a la queue à gauche (`UniBubbleSide.right` = « la bulle est
/// à droite du personnage ») ; symétrique pour Uni.
class _Speech extends StatelessWidget {
  final MascotLine line;
  final TextStyle? style;

  const _Speech({required this.line, required this.style});

  @override
  Widget build(BuildContext context) {
    final side = switch (line.who) {
      MascotSpeaker.archlord => UniBubbleSide.right,
      MascotSpeaker.uni => UniBubbleSide.left,
    };
    return Align(
      alignment: line.who == MascotSpeaker.archlord
          ? Alignment.centerLeft
          : Alignment.centerRight,
      child: UniBubble(
        side: side,
        child: Text(line.text, style: style),
      ),
    );
  }
}

/// Points de progression, pour dire « ça avance » sans horloge visible.
class _Dots extends StatelessWidget {
  final int count;
  final int active;

  const _Dots({required this.count, required this.active});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: i == active ? 14 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == active ? AppColors.primaryBlue : AppColors.inputBorder,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
      ],
    );
  }
}
