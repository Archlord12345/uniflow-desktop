import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'uni_mascot.dart';

/// Archlord, la seconde mascotte d'UniFlow : le fondateur de KERNEL FORGE,
/// dessiné dans le même style que Uni (demande du propriétaire, 2026-09-21).
///
/// Comme Uni, ses poses sont **embarquées** (`assets/mascot/archlord_*.webp`)
/// pour s'afficher hors ligne. Contrairement à Uni, c'est un humain : il ne
/// saute pas et ne flotte pas. Sa boucle est une respiration lente, un léger
/// balancement, et un hochement de tête quand il parle — rien de plus, un
/// personnage humain qui gigote lit comme un défaut.
enum ArchlordPose {
  wave('archlord_wave', 373 / 768, 'Archlord salue de la main'),
  explain('archlord_explain', 403 / 768, 'Archlord explique, la main ouverte'),
  laptop('archlord_laptop', 405 / 768, 'Archlord travaille sur son portable'),
  thumbs('archlord_thumbs', 325 / 768, 'Archlord lève le pouce'),
  thinking('archlord_thinking', 272 / 768, 'Archlord réfléchit'),
  pointing('archlord_pointing', 417 / 768, 'Archlord montre la suite');

  const ArchlordPose(this.file, this.ratio, this.alt);

  /// Nom du fichier sans extension dans `assets/mascot/`.
  final String file;

  /// Largeur / hauteur de l'image, pour réserver la bonne boîte avant décodage.
  final double ratio;

  /// Description pour les lecteurs d'écran.
  final String alt;

  String get asset => 'assets/mascot/$file.webp';
}

/// Scène à deux : Archlord et Uni se saluent du poing. Une seule image, pas
/// une composition de deux poses — c'est le dessin du propriétaire.
class ArchlordUniScene {
  ArchlordUniScene._();

  static const String fistBumpAsset =
      'assets/mascot/archlord_uni_fistbump.webp';
  static const double fistBumpRatio = 768 / 714;
  static const String fistBumpAlt = 'Archlord et Uni se saluent du poing';
}

/// Période de la respiration : lente, comme un souffle calme.
const Duration _kBreathPeriod = Duration(milliseconds: 3400);

/// Amplitude de la respiration (échelle verticale) et du balancement (radians).
const double _kBreathScale = 0.012;
const double _kSwayAngle = 0.012;

/// Hochement de tête pendant la parole : plus rapide que la respiration,
/// quelques pixels seulement.
const double _kNodCyclesPerBreath = 5;
const double _kNodOffset = 2.5;
const double _kNodAngle = 0.018;

/// Entrée : Archlord se lève de quelques pixels en apparaissant.
const Duration _kEnterDuration = Duration(milliseconds: 460);
const double _kEnterRise = 10;

/// Pose animée d'Archlord, avec bulle facultative.
class ArchlordMascot extends StatefulWidget {
  final ArchlordPose pose;

  /// Hauteur de l'image en points logiques ; la largeur suit le ratio.
  final double size;

  /// Coupe la boucle (entrée et bulle restent).
  final bool still;

  /// Il parle : la respiration s'accompagne d'un hochement de tête.
  final bool speaking;

  final Widget? bubble;
  final UniBubbleSide bubbleSide;
  final VoidCallback? onTap;

  const ArchlordMascot({
    super.key,
    required this.pose,
    this.size = 150,
    this.still = false,
    this.speaking = false,
    this.bubble,
    this.bubbleSide = UniBubbleSide.right,
    this.onTap,
  });

  @override
  State<ArchlordMascot> createState() => _ArchlordMascotState();
}

class _ArchlordMascotState extends State<ArchlordMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop =
      AnimationController(vsync: this, duration: _kBreathPeriod);

  bool _animated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLoop();
  }

  @override
  void didUpdateWidget(covariant ArchlordMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncLoop();
  }

  /// Démarre ou arrête la boucle selon `still` et la préférence système. Le
  /// contrôleur ne tourne jamais à vide (batterie, `pumpAndSettle`), comme
  /// pour Uni.
  void _syncLoop() {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final animated = !widget.still && !reduce;
    if (animated && !_animated) {
      _loop.repeat();
    } else if (!animated && _animated) {
      _loop.stop();
      _loop.value = 0;
    }
    _animated = animated;
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  /// Transformation à l'instant `t` ∈ [0, 1[ d'un cycle de respiration.
  Matrix4 _transform(double t, Size box) {
    final breath = math.sin(t * 2 * math.pi);
    var dy = 0.0;
    var angle = _kSwayAngle * math.sin(t * 2 * math.pi + math.pi / 3);
    // La respiration soulève très légèrement le buste : échelle verticale
    // autour des pieds, pas une translation, pour que les chaussures restent
    // au sol.
    final scaleY = 1 + _kBreathScale * (breath + 1) / 2;
    if (widget.speaking) {
      final nod = math.sin(t * 2 * math.pi * _kNodCyclesPerBreath);
      dy += _kNodOffset * nod.abs() * -1;
      angle += _kNodAngle * nod;
    }
    final pivot = Offset(box.width / 2, box.height * 0.96);
    return Matrix4.identity()
      ..translateByDouble(pivot.dx, dy + pivot.dy, 0, 1)
      ..rotateZ(angle)
      ..scaleByDouble(1, scaleY, 1, 1)
      ..translateByDouble(-pivot.dx, -pivot.dy, 0, 1);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final box = Size(widget.size * widget.pose.ratio, widget.size);

    Widget image = Semantics(
      image: true,
      label: widget.pose.alt,
      child: Image.asset(
        widget.pose.asset,
        width: box.width,
        height: box.height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        // Asset manquant (dépôt incomplet, export en cours) : un médaillon de
        // marque tient la place, l'écran qui l'accueille reste intact.
        errorBuilder: (_, __, ___) => _Fallback(size: widget.size),
      ),
    );

    if (_animated) {
      image = AnimatedBuilder(
        animation: _loop,
        builder: (context, child) => Transform(
          transform: _transform(_loop.value, box),
          child: child,
        ),
        child: image,
      );
    }

    Widget figure =
        SizedBox(width: box.width, height: box.height, child: image);

    figure = TweenAnimationBuilder<double>(
      tween: Tween(begin: reduce ? 1 : 0, end: 1),
      duration: _kEnterDuration,
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, (1 - v) * _kEnterRise),
          child: child,
        ),
      ),
      child: figure,
    );

    if (widget.onTap != null) {
      figure = GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: MouseRegion(cursor: SystemMouseCursors.click, child: figure),
      );
    }

    final bubble = widget.bubble;
    if (bubble == null) return figure;

    final speech = UniBubble(side: widget.bubbleSide, child: bubble);
    return switch (widget.bubbleSide) {
      UniBubbleSide.top => Column(
          mainAxisSize: MainAxisSize.min,
          children: [speech, const SizedBox(height: AppSpacing.xs), figure],
        ),
      UniBubbleSide.left => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: speech),
            const SizedBox(width: AppSpacing.sm),
            figure,
          ],
        ),
      UniBubbleSide.right => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            figure,
            const SizedBox(width: AppSpacing.sm),
            Flexible(child: speech),
          ],
        ),
    };
  }
}

/// Médaillon de repli : les initiales du fondateur sur le dégradé de marque.
class _Fallback extends StatelessWidget {
  final double size;
  const _Fallback({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size * 0.7,
      height: size * 0.7,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.logoGradient,
      ),
      alignment: Alignment.center,
      child: Text(
        'A',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: size * 0.28,
        ),
      ),
    );
  }
}

/// La scène du poing : Archlord et Uni, une seule image qui respire.
class ArchlordUniFistBump extends StatefulWidget {
  /// Hauteur de la scène ; la largeur suit le ratio de l'image.
  final double size;

  const ArchlordUniFistBump({super.key, this.size = 160});

  @override
  State<ArchlordUniFistBump> createState() => _ArchlordUniFistBumpState();
}

class _ArchlordUniFistBumpState extends State<ArchlordUniFistBump>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop =
      AnimationController(vsync: this, duration: _kBreathPeriod);
  bool _animated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!reduce && !_animated) {
      _loop.repeat();
    } else if (reduce && _animated) {
      _loop.stop();
      _loop.value = 0;
    }
    _animated = !reduce;
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = Size(widget.size * ArchlordUniScene.fistBumpRatio, widget.size);
    Widget image = Semantics(
      image: true,
      label: ArchlordUniScene.fistBumpAlt,
      child: Image.asset(
        ArchlordUniScene.fistBumpAsset,
        width: box.width,
        height: box.height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => _Fallback(size: widget.size),
      ),
    );
    if (_animated) {
      image = AnimatedBuilder(
        animation: _loop,
        builder: (context, child) {
          final breath = (math.sin(_loop.value * 2 * math.pi) + 1) / 2;
          return Transform.scale(
            scaleY: 1 + _kBreathScale * breath,
            alignment: Alignment.bottomCenter,
            child: child,
          );
        },
        child: image,
      );
    }
    return SizedBox(width: box.width, height: box.height, child: image);
  }
}
