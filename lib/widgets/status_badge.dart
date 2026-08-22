import 'package:flutter/material.dart';

/// Petite pilule colorée (ex: "L3", "L2", "M1" dans le tableau des étudiants).
/// Le texte reprend une version assombrie de la couleur de fond pour
/// garder un bon contraste sans avoir à définir deux couleurs à chaque fois.
class StatusBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color? textColor;

  const StatusBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20), // forme pilule
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          // assombrit la couleur de fond pour le texte si aucune couleur
          // de texte n'est fournie explicitement, afin d'assurer le contraste
          color: textColor ?? _darken(backgroundColor),
        ),
      ),
    );
  }

  /// Assombrit une couleur de ~40% pour l'utiliser comme couleur de texte
  /// lisible sur un fond pastel (ex: fond vert clair -> texte vert foncé).
  static Color _darken(Color color, [double amount = 0.4]) {
    final hsl = HSLColor.fromColor(color);
    final darker = hsl.withLightness(
      (hsl.lightness - amount).clamp(0.0, 1.0),
    );
    return darker.toColor();
  }
}
