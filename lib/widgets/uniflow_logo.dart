import 'package:flutter/material.dart';
import '../theme/app_theme.dart';


/// Widget séparé de [UniFlowLogo] pour pouvoir l'utiliser seule
/// (ex: petite icône dans la sidebar une fois repliée, favicon web, etc.)
class UniFlowIcon extends StatelessWidget {
  static const String _logoAssetPath = 'assets/images/logo.jpg';

  /// Taille du carré contenant l'icône (largeur = hauteur)
  final double size;

  const UniFlowIcon({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.28);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.logoGradient,
        borderRadius: radius,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Image.asset(
          _logoAssetPath,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

/// Logo complet : icône + texte "UniFlow" (+ tagline optionnelle).
/// Utilisé sur l'écran de login, et réutilisable sur le dashboard,
/// l'en-tête de la sidebar, etc.
class UniFlowLogo extends StatelessWidget {
  final double iconSize;
  final double fontSize;

  /// Affiche ou non la phrase d'accroche sous le logo
  /// ("Plateforme de gestion académique intelligente")
  final bool showTagline;

  const UniFlowLogo({
    super.key,
    this.iconSize = 40,
    this.fontSize = 26,
    this.showTagline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Icône + texte "UniFlow" alignés horizontalement
        Row(
          mainAxisSize: MainAxisSize.min, // la Row ne prend que la place nécessaire (pas toute la largeur)
          children: [
            UniFlowIcon(size: iconSize),
            const SizedBox(width: 10),
            Text(
              'UniFlow',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        // Tagline optionnelle, affichée seulement si showTagline == true
        if (showTagline) ...[
          const SizedBox(height: 4),
          const Text(
            'Plateforme de gestion académique intelligente',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
