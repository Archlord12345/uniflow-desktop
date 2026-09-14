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
          // `maxLines` + ellipse sur le libellé : dans une grille de KPI, la
          // colonne peut devenir étroite (fenêtre réduite, tablette) et un
          // libellé long n'a alors nulle part où aller.
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 6),
          // La valeur est en `FittedBox` plutôt qu'en `Text` nu : « 1 248 »
          // en 22 px gras déborde d'une carte étroite, et une taille qui
          // s'ajuste est préférable à des points de suspension sur un chiffre.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
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
              // Sans `Flexible`, cette Row n'avait aucun enfant capable de se
              // réduire : dès que la carte était plus étroite que l'icône plus
              // le texte, Flutter signalait un débordement au lieu de tronquer.
              Flexible(
                child: Text(
                  delta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isPositive ? AppColors.success : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
