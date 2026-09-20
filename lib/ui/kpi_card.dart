import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'surface_card.dart';

/// Carte d'indicateur du tableau de bord, reproduite du web
/// (`DashboardPage.tsx`, rangée `stats`) : pastille colorée avec l'icône en
/// haut à gauche, tendance en pilule en haut à droite, valeur en gras, libellé
/// en dessous. Cliquable : mène à l'écran qui détaille l'indicateur.
class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  /// Fond de la pastille (`bg-[#eff3ff]`) et couleur de l'icône
  /// (`text-[#1e3a8a]`).
  final Color tint;
  final Color iconColor;

  /// Texte de la tendance (« Données réelles », « 0 % », « Actifs »).
  final String? delta;

  /// Tendance favorable (vert) ou non (rouge), comme `up` côté web.
  final bool up;
  final VoidCallback? onTap;

  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
    required this.iconColor,
    this.delta,
    this.up = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = UniFlowColors.of(context);
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const Spacer(),
              if (delta != null)
                Flexible(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: up
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      delta!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTextStyles.fontFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: up
                            ? const Color(0xFF047857)
                            : const Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontSize: AppTextStyles.size24,
                fontWeight: FontWeight.w800,
                color: colors.text,
                height: 1.0,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: AppTextStyles.size12,
              color: colors.muted,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}
