import 'package:flutter/material.dart';

/// Icône d'action d'une ligne de tableau (voir, modifier, supprimer).
///
/// 36 px de côté, sans la cible tactile de 48 px de Material : deux
/// `IconButton` standard font 96 px et débordaient de la colonne « Actions »
/// de 80 px du tableau des enseignants (le test le signalait : « overflowed
/// by 16 pixels »). Sur un bureau, le pointeur n'a pas besoin de la marge
/// tactile ; la largeur d'une colonne d'actions se calcule donc en multiples
/// de [side].
class TableActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onPressed;

  const TableActionIcon({
    super.key,
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  static const double side = 36;

  /// Largeur d'une colonne qui aligne [n] icônes.
  static double columnWidth(int n) => side * n + 8;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 17),
      color: color,
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        padding: EdgeInsets.zero,
        fixedSize: const Size.square(side),
        minimumSize: const Size.square(side),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
