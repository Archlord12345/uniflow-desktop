import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/motion.dart';
import 'surface_card.dart';

export '../widgets/motion.dart' show Shimmer, TableSkeleton, CardGridSkeleton;

/// Squelette d'une carte du tableau de bord : en-tête (titre + action) puis
/// [lines] lignes de longueur décroissante. Il occupe la place exacte de la
/// carte à venir, pour que la page ne saute pas à l'arrivée des données.
class CardSkeleton extends StatelessWidget {
  final int lines;
  final double? height;

  const CardSkeleton({super.key, this.lines = 3, this.height});

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              children: [
                Shimmer(width: 140, height: 14),
                Spacer(),
                Shimmer(width: 60, height: 12),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            for (var i = 0; i < lines; i++) ...[
              Shimmer(width: 240 - i * 40.0, height: 12),
              if (i < lines - 1) const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
      ),
    );
  }
}

/// Squelette d'une carte KPI : pastille, valeur, libellé.
class KpiSkeleton extends StatelessWidget {
  const KpiSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SurfaceCard(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Shimmer(
                width: 36,
                height: 36,
                borderRadius: BorderRadius.all(Radius.circular(12))),
            Spacer(),
            Shimmer(width: 50, height: 14),
          ]),
          SizedBox(height: AppSpacing.md),
          Shimmer(width: 70, height: 24),
          SizedBox(height: AppSpacing.sm),
          Shimmer(width: 110, height: 12),
        ],
      ),
    );
  }
}
