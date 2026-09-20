import 'package:flutter/material.dart';

import '../widgets/motion.dart';

export '../widgets/motion.dart'
    show
        CascadeIn,
        kMotionMedium,
        motionReduced,
        pageTransition,
        softRoute,
        AnimatedCheck,
        AnimatedCross,
        ResultView,
        showFeedback;

/// Apparition en cascade du design system : fondu + translation de 14 px,
/// 320 ms, `easeOutCubic`, décalée de 60 ms par [index] — les valeurs de
/// `animate-stagger-N` et `fadeInUp` du web. `CascadeIn` reste le moteur ;
/// `MotionIn` fixe les réglages pour que toutes les pages bougent pareil.
class MotionIn extends StatelessWidget {
  final int index;
  final Widget child;

  /// Distance de translation en fraction de la hauteur de l'enfant ; 0.08
  /// vaut ~14 px sur une carte de 180 px.
  final Offset offset;

  const MotionIn({
    super.key,
    this.index = 0,
    required this.child,
    this.offset = const Offset(0, 0.08),
  });

  @override
  Widget build(BuildContext context) {
    return CascadeIn(
      index: index,
      step: const Duration(milliseconds: 60),
      duration: const Duration(milliseconds: 320),
      offset: offset,
      child: child,
    );
  }
}
