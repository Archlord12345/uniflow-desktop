import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Uni, la mascotte d'UniFlow — même personnage, mêmes poses et mêmes
/// animations que sur le web (`src/components/mascot/UniMascot.tsx`).
///
/// Les images sont **embarquées dans le binaire** (`assets/mascot/*.webp`) :
/// elles s'affichent donc aussi hors ligne et sur les écrans d'erreur, là où
/// justement rien ne peut plus être téléchargé. C'est le choix demandé par le
/// propriétaire le 2026-09-21 (« ces images dans le code pour faciliter leur
/// affichage en cas d'erreur »).
///
/// Chaque pose a sa boucle : Uni salue en se balançant, réfléchit en
/// flottant, saute de joie, ronfle en respirant… L'animation est purement
/// Flutter (aucune dépendance Lottie/Rive) et se coupe quand le système
/// demande moins de mouvement (`MediaQuery.disableAnimations`).
enum UniPose {
  wave('uni_wave', 682 / 768, 'Uni salue de la main'),
  thinking('uni_thinking', 413 / 768, 'Uni réfléchit'),
  celebrate('uni_celebrate', 710 / 768, 'Uni saute de joie'),
  sorry('uni_sorry', 639 / 768, 'Uni, désolé, hausse les épaules'),
  search('uni_search', 764 / 768, 'Uni cherche à la loupe'),
  sleeping('uni_sleeping', 1, 'Uni dort sur ses livres'),
  graduate('uni_graduate', 600 / 768, 'Uni diplômé'),
  pointing('uni_pointing', 616 / 768, 'Uni montre la suite'),
  headset('uni_headset', 618 / 768, 'Uni au casque'),
  shield('uni_shield', 572 / 768, 'Uni tient un bouclier'),
  peekRight('uni_peek_right', 1, 'Uni passe la tête par le bord droit'),
  peekBottom('uni_peek_bottom', 1, 'Uni passe la tête par le bas');

  const UniPose(this.file, this.ratio, this.alt);

  /// Nom du fichier sans extension dans `assets/mascot/`.
  final String file;

  /// Largeur / hauteur de l'image, pour réserver la bonne boîte avant décodage.
  final double ratio;

  /// Description pour les lecteurs d'écran.
  final String alt;

  String get asset => 'assets/mascot/$file.webp';
}

/// Côté où s'accroche la bulle de dialogue.
enum UniBubbleSide { left, right, top }

/// Pose animée d'Uni, avec bulle et petits effets facultatifs.
class UniMascot extends StatefulWidget {
  final UniPose pose;

  /// Hauteur de l'image en points logiques ; la largeur suit le ratio.
  final double size;

  /// Coupe la boucle (entrée et bulle restent).
  final bool still;

  /// Confettis, « z », points de suspension… selon la pose.
  final bool effects;

  final Widget? bubble;
  final UniBubbleSide bubbleSide;
  final VoidCallback? onTap;

  const UniMascot({
    super.key,
    required this.pose,
    this.size = 150,
    this.still = false,
    this.effects = true,
    this.bubble,
    this.bubbleSide = UniBubbleSide.right,
    this.onTap,
  });

  @override
  State<UniMascot> createState() => _UniMascotState();
}

class _UniMascotState extends State<UniMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop;

  bool _animated = false;

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(vsync: this, duration: _loopDuration(widget.pose));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLoop();
  }

  @override
  void didUpdateWidget(covariant UniMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pose != widget.pose) _loop.duration = _loopDuration(widget.pose);
    _syncLoop(restart: oldWidget.pose != widget.pose);
  }

  /// Démarre ou arrête la boucle selon `still` et la préférence système. Le
  /// contrôleur ne tourne jamais à vide : un ticker infini empêcherait
  /// `pumpAndSettle` de se stabiliser et consommerait de la batterie pour un
  /// mouvement que personne ne verrait.
  void _syncLoop({bool restart = false}) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final animated = !widget.still && !reduce;
    if (animated && (!_animated || restart)) {
      _loop.repeat(reverse: true);
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

  static Duration _loopDuration(UniPose pose) => switch (pose) {
        UniPose.celebrate => const Duration(milliseconds: 700),
        UniPose.wave => const Duration(milliseconds: 900),
        UniPose.pointing => const Duration(milliseconds: 1100),
        UniPose.search => const Duration(milliseconds: 1300),
        UniPose.thinking => const Duration(milliseconds: 1600),
        UniPose.sleeping => const Duration(milliseconds: 2400),
        UniPose.sorry => const Duration(milliseconds: 1800),
        _ => const Duration(milliseconds: 1500),
      };

  /// Transformation de la pose à l'instant `t` (0 → 1 → 0, aller-retour).
  Matrix4 _transform(double t, Size box) {
    final e = Curves.easeInOut.transform(t);
    double dx = 0, dy = 0, angle = 0, scale = 1;
    switch (widget.pose) {
      case UniPose.wave:
        angle = (e - 0.5) * 0.10;
        dy = -6 * e;
      case UniPose.thinking:
        dy = -5 * e;
        angle = (e - 0.5) * 0.04;
      case UniPose.celebrate:
        dy = -16 * math.sin(e * math.pi);
        scale = 1 + 0.05 * math.sin(e * math.pi);
      case UniPose.sorry:
        angle = (e - 0.5) * 0.08;
        dy = 2 * e;
      case UniPose.search:
        dx = (e - 0.5) * 14;
        angle = (e - 0.5) * 0.08;
      case UniPose.sleeping:
        scale = 1 + 0.03 * e;
        dy = 2 * e;
      case UniPose.graduate:
        dy = -5 * e;
      case UniPose.pointing:
        dx = 7 * e;
      case UniPose.headset:
        dy = -4 * e;
        angle = (e - 0.5) * 0.03;
      case UniPose.shield:
        scale = 1 + 0.03 * e;
      case UniPose.peekRight:
        dx = -6 * e;
      case UniPose.peekBottom:
        dy = -6 * e;
    }
    // Rotation et échelle autour du bas du personnage : il « tient debout ».
    final pivot = Offset(box.width / 2, box.height * 0.92);
    return Matrix4.identity()
      ..translateByDouble(dx + pivot.dx, dy + pivot.dy, 0, 1)
      ..rotateZ(angle)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-pivot.dx, -pivot.dy, 0, 1);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final animated = _animated;
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
        // Si l'asset manquait (dépôt incomplet), on ne casse pas l'écran
        // d'erreur qui l'affiche : un simple rond de marque prend la place.
        errorBuilder: (_, __, ___) => _Fallback(size: widget.size),
      ),
    );

    if (animated) {
      image = AnimatedBuilder(
        animation: _loop,
        builder: (context, child) => Transform(
          transform: _transform(_loop.value, box),
          child: child,
        ),
        child: image,
      );
    }

    Widget figure = SizedBox(
      width: box.width,
      height: box.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          image,
          if (widget.effects && animated)
            Positioned.fill(child: _PoseEffects(pose: widget.pose, loop: _loop)),
        ],
      ),
    );

    // Entrée : Uni apparaît en grandissant, comme sur le web.
    figure = TweenAnimationBuilder<double>(
      tween: Tween(begin: reduce ? 1 : 0.6, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.scale(scale: v, alignment: Alignment.bottomCenter, child: child),
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
          children: [speech, const SizedBox(height: 6), figure],
        ),
      UniBubbleSide.left => Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [Flexible(child: speech), const SizedBox(width: 8), figure],
        ),
      UniBubbleSide.right => Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [figure, const SizedBox(width: 8), Flexible(child: speech)],
        ),
    };
  }
}

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
        gradient: LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF0D9488)]),
      ),
      alignment: Alignment.center,
      child: Text(
        'Uni',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: size * 0.2,
        ),
      ),
    );
  }
}

/// Bulle de dialogue d'Uni : fond blanc, bord fin, petite pointe vers lui.
class UniBubble extends StatelessWidget {
  final Widget child;
  final UniBubbleSide side;

  const UniBubble({super.key, required this.child, this.side = UniBubbleSide.right});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
          fontSize: 13,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1F2937),
        ) ??
        const TextStyle(fontSize: 13, color: Color(0xFF1F2937));

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: v,
          alignment: switch (side) {
            UniBubbleSide.right => Alignment.centerLeft,
            UniBubbleSide.left => Alignment.centerRight,
            UniBubbleSide.top => Alignment.bottomCenter,
          },
          child: child,
        ),
      ),
      child: CustomPaint(
        painter: _BubblePainter(side: side),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 260),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          margin: EdgeInsets.only(
            left: side == UniBubbleSide.right ? 8 : 0,
            right: side == UniBubbleSide.left ? 8 : 0,
            bottom: side == UniBubbleSide.top ? 8 : 0,
          ),
          child: DefaultTextStyle.merge(style: textStyle, child: child),
        ),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  final UniBubbleSide side;
  const _BubblePainter({required this.side});

  @override
  void paint(Canvas canvas, Size size) {
    const tail = 8.0;
    final body = switch (side) {
      UniBubbleSide.right => Rect.fromLTWH(tail, 0, size.width - tail, size.height),
      UniBubbleSide.left => Rect.fromLTWH(0, 0, size.width - tail, size.height),
      UniBubbleSide.top => Rect.fromLTWH(0, 0, size.width, size.height - tail),
    };
    final rrect = RRect.fromRectAndRadius(body, const Radius.circular(16));
    final path = Path()..addRRect(rrect);
    final tip = Path();
    switch (side) {
      case UniBubbleSide.right:
        final y = body.center.dy;
        tip
          ..moveTo(tail, y - 7)
          ..lineTo(0, y)
          ..lineTo(tail, y + 7)
          ..close();
      case UniBubbleSide.left:
        final y = body.center.dy;
        tip
          ..moveTo(body.right, y - 7)
          ..lineTo(size.width, y)
          ..lineTo(body.right, y + 7)
          ..close();
      case UniBubbleSide.top:
        final x = body.center.dx;
        tip
          ..moveTo(x - 7, body.bottom)
          ..lineTo(x, size.height)
          ..lineTo(x + 7, body.bottom)
          ..close();
    }
    path.addPath(tip, Offset.zero);

    canvas.drawShadow(path, const Color(0x331E3A8A), 8, true);
    canvas.drawPath(path, Paint()..color = Colors.white);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFFE5E7EB),
    );
  }

  @override
  bool shouldRepaint(covariant _BubblePainter old) => old.side != side;
}

/// Petits effets autour d'Uni, propres à chaque pose.
class _PoseEffects extends StatelessWidget {
  final UniPose pose;
  final Animation<double> loop;

  const _PoseEffects({required this.pose, required this.loop});

  @override
  Widget build(BuildContext context) {
    return switch (pose) {
      UniPose.celebrate => _Confetti(loop: loop),
      UniPose.sleeping => _FloatingGlyphs(loop: loop, glyphs: const ['z', 'z', 'Z'], color: const Color(0xFF6366F1)),
      UniPose.search => _FloatingGlyphs(loop: loop, glyphs: const ['?'], color: const Color(0xFF0D9488), size: 22),
      UniPose.thinking => _ThinkingDots(loop: loop),
      UniPose.sorry => _SweatDrop(loop: loop),
      _ => const SizedBox.shrink(),
    };
  }
}

class _Confetti extends StatelessWidget {
  final Animation<double> loop;
  const _Confetti({required this.loop});

  static const _colors = [
    Color(0xFF1E3A8A),
    Color(0xFF0D9488),
    Color(0xFF7C3AED),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
  ];

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: loop,
        builder: (context, _) => LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth, h = c.maxHeight;
            return Stack(
              clipBehavior: Clip.none,
              children: List.generate(10, (i) {
                final phase = (loop.value + i / 10) % 1;
                final x = (i / 10) * w + math.sin(i) * 6;
                final y = -12 + phase * h * 0.7;
                return Positioned(
                  left: x,
                  top: y,
                  child: Opacity(
                    opacity: (1 - phase).clamp(0.0, 1.0),
                    child: Transform.rotate(
                      angle: phase * math.pi * 2 + i,
                      child: Container(
                        width: 6,
                        height: i.isEven ? 6 : 10,
                        decoration: BoxDecoration(
                          color: _colors[i % _colors.length],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

class _FloatingGlyphs extends StatelessWidget {
  final Animation<double> loop;
  final List<String> glyphs;
  final Color color;
  final double size;

  const _FloatingGlyphs({
    required this.loop,
    required this.glyphs,
    required this.color,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: loop,
        builder: (context, _) => LayoutBuilder(
          builder: (context, c) => Stack(
            clipBehavior: Clip.none,
            children: List.generate(glyphs.length, (i) {
              final phase = (loop.value + i / glyphs.length) % 1;
              return Positioned(
                right: c.maxWidth * 0.08 - i * 6,
                top: c.maxHeight * 0.12 - phase * 26 - i * 8,
                child: Opacity(
                  opacity: (1 - phase).clamp(0.0, 1.0),
                  child: Text(
                    glyphs[i],
                    style: TextStyle(
                      fontSize: size + i * 3,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _ThinkingDots extends StatelessWidget {
  final Animation<double> loop;
  const _ThinkingDots({required this.loop});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0.9, -1.05),
        child: AnimatedBuilder(
          animation: loop,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final v = ((loop.value * 3) - i).clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Opacity(
                  opacity: 0.3 + 0.7 * v,
                  child: Container(
                    width: 5 + 2 * v,
                    height: 5 + 2 * v,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E3A8A),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _SweatDrop extends StatelessWidget {
  final Animation<double> loop;
  const _SweatDrop({required this.loop});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: loop,
        builder: (context, _) => Align(
          alignment: Alignment(0.85, -0.7 + loop.value * 0.25),
          child: Opacity(
            opacity: (1 - loop.value * 0.8).clamp(0.0, 1.0),
            child: Container(
              width: 8,
              height: 12,
              decoration: const BoxDecoration(
                color: Color(0xFF60A5FA),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Trois points qui rebondissent — « Uni réfléchit… », « Chargement… ».
class UniDots extends StatefulWidget {
  final Color color;
  final double size;

  const UniDots({super.key, this.color = const Color(0xFF1E3A8A), this.size = 7});

  @override
  State<UniDots> createState() => _UniDotsState();
}

class _UniDotsState extends State<UniDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final phase = reduce ? 0.0 : math.sin((_c.value * 2 * math.pi) - i * 0.9);
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: widget.size * 0.35),
            child: Transform.translate(
              offset: Offset(0, -phase.clamp(0.0, 1.0) * widget.size * 0.8),
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
              ),
            ),
          );
        }),
      ),
    );
  }
}
