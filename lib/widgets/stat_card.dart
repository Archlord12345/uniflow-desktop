import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Carte affichant une métrique clé (ex: "Étudiants : 1 248, +12%").
/// Disposition verticale : icône ronde en haut, libellé, puis grande valeur
/// avec le delta juste à côté — fidèle à la maquette "UniFlow Desktop Partie 1".
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String delta;
  final bool isPositive;
  final IconData icon;
  final Color iconBackground;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.delta,
    required this.icon,
    required this.iconBackground,
    this.isPositive = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: iconBackground, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 12),
          Text(label, style: AppTextStyles.body.copyWith(fontSize: 13)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                size: 13,
                color: isPositive ? AppColors.success : AppColors.textMuted,
              ),
              const SizedBox(width: 2),
              Text(
                delta,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isPositive ? AppColors.success : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
