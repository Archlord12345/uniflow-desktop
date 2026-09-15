import 'package:flutter/material.dart';
import '../theme/app_theme.dart';


/// Widget séparé de [UniFlowLogo] pour pouvoir l'utiliser seule
/// (ex: petite icône dans la sidebar une fois repliée, favicon web, etc.)
class UniFlowIcon extends StatelessWidget {
  /// Écusson carré de la marque, détouré (fond transparent).
  ///
  /// `assets/images/logo.png` — le logotype horizontal, 1711×531 — était
  /// affiché ici dans un carré de `size` avec `BoxFit.cover` : l'image était
  /// mise à l'échelle sur la hauteur puis rognée sur la largeur, et le mot
  /// « UniFlow » disparaissait, ne laissant qu'une tranche centrale de
  /// l'écusson. Le web documente le même piège
  /// (`uniflow-we/src/lib/brandAssets.ts`) : le logo horizontal n'est pas
  /// adapté aux formats carrés.
  static const String _logoAssetPath = 'assets/brand/uniflow_marque.png';

  /// Taille du carré contenant l'icône (largeur = hauteur)
  final double size;

  const UniFlowIcon({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    // Plus de conteneur décoré, ni dégradé ni coins arrondis.
    //
    // Le dégradé partait de `primaryBlue` #1E3A8A — exactement le bleu de
    // l'écusson : la toque et la jambe gauche de la marque s'y confondaient
    // avec le fond. Il n'avait de sens qu'avec l'ancien logotype opaque, dont
    // il fallait masquer le fond blanc. Une plaque blanche serait tout aussi
    // fautive : sur la sidebar sombre, « un carré blanc plein fait une tuile
    // blanche », le défaut que `tools/generer-icones-uniflow.py` documente
    // déjà pour les icônes de lanceur.
    //
    // La marque est détourée : elle se compose directement sur le fond de
    // l'écran. Vérifié sur les deux fonds où elle apparaît — le marine de la
    // sidebar (#151E32) et le voile bleu→teal de la connexion — elle y reste
    // lisible.
    return Image.asset(
      _logoAssetPath,
      width: size,
      height: size,
      // `contain` : la marque est carrée, elle remplit donc le carré sans être
      // rognée. Si l'écusson venait à être remplacé par une image non carrée,
      // elle serait réduite au lieu d'être tronquée — `cover`, lui, rogne.
      fit: BoxFit.contain,
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

  /// Couleur du mot « UniFlow ».
  ///
  /// Par défaut la couleur de titre du thème, prévue pour un fond clair. Sur un
  /// fond sombre (photo, dégradé de marque), il faut passer `Colors.white` :
  /// sinon le texte se confond avec le fond.
  final Color? textColor;

  const UniFlowLogo({
    super.key,
    this.iconSize = 40,
    this.fontSize = 26,
    this.showTagline = false,
    this.textColor,
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
            // `Flexible` : sans lui, `maxLines`/`ellipsis` sont sans effet, le
            // `Text` réclamant sa largeur naturelle quoi qu'il arrive.
            Flexible(
              child: Text(
                'UniFlow',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  color: textColor ?? AppColors.textPrimary,
                ),
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
