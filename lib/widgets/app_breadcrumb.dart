import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Fil d'Ariane simple : une liste de libellés séparés par "/", le dernier
/// étant en gras pour indiquer la page actuelle. Le premier élément est
/// cliquable (retour à la page parente) si [onRootTap] est fourni.
class AppBreadcrumb extends StatelessWidget {
  final List<String> items;
  final VoidCallback? onRootTap;

  const AppBreadcrumb({super.key, required this.items, this.onRootTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('/', style: TextStyle(color: AppColors.textMuted)),
            ),
          // Chaque segment est `Flexible` en `loose` : il garde sa taille
          // naturelle tant qu'il y a de la place, et se tronque sinon. Un
          // `flex: 0` n'aurait servi à rien — les enfants sans flex sont
          // mesurés sans contrainte de largeur et débordent de nouveau.
          Flexible(
            fit: FlexFit.loose,
            child: GestureDetector(
              onTap: i == 0 ? onRootTap : null,
              child: Text(
                items[i],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  // dernier élément = page actuelle -> gras et foncé
                  fontWeight: i == items.length - 1 ? FontWeight.w700 : FontWeight.w400,
                  color: i == items.length - 1
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
