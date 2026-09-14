import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_breadcrumb.dart';

/// Barre de titre d'une page de gestion : fil d'Ariane à gauche, actions à
/// droite.
///
/// Le repli est confié à un `Wrap` plutôt qu'à un seuil de largeur codé en
/// dur. La raison est mesurable : les deux boutons libellés d'une barre
/// réclament 581 px à taille de texte normale et 713 px à ×1.3 — leur largeur
/// suit la taille de police de l'utilisateur. Un seuil fixe finissait donc
/// toujours par déborder dès que la police était agrandie, et il fallait le
/// retoucher à chaque bouton ajouté. Ici, `Wrap` compare les largeurs réelles :
/// tant que le fil d'Ariane et les actions tiennent côte à côte, `spaceBetween`
/// les repousse aux deux extrémités ; sinon le groupe d'actions passe à la
/// ligne suivante et s'aligne à gauche, sous le fil.
class AppPageBar extends StatelessWidget {
  final List<String> breadcrumb;

  /// Ligne d'explication sous le fil d'Ariane.
  ///
  /// Elle vivait auparavant dans une `Column` en `Expanded` d'une `Row` : le
  /// bouton d'action, non flexible, prenait la largeur dont il avait besoin et
  /// ne laissait au titre qu'une trentaine de pixels. Le texte se repliait
  /// alors sur vingt lignes — la barre mesurait 646 px de haut dans une
  /// fenêtre de 620. Ici le titre est un bloc entier de la `Wrap` : il est
  /// mesuré à sa largeur naturelle, et c'est le bouton qui descend.
  final String? subtitle;

  final List<Widget> actions;

  const AppPageBar({
    super.key,
    required this.breadcrumb,
    this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        border: Border(bottom: BorderSide(color: AppColors.inputBorder)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBreadcrumb(items: breadcrumb),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: AppTextStyles.body),
              ],
            ],
          ),
          if (actions.isNotEmpty)
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: actions,
            ),
        ],
      ),
    );
  }
}
