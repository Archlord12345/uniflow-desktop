import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'uni_icons.dart';

/// Largeur sous laquelle les actions de la barre passent sous le titre.
///
/// 560 px : en dessous, « titre + deux boutons libellés » ne tient plus sur une
/// seule ligne, même avec une police de taille normale.
const double _kNarrowBreakpoint = 560;

/// Barre du haut commune à toutes les pages internes : titre à gauche
/// (+ sous-titre optionnel), et une liste de widgets d'action à droite
/// (boutons, icônes de notification, etc.) — le contenu de droite change
/// selon la page, donc on le passe en paramètre plutôt que de le coder en dur.
class AppTopBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  const AppTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      // Surface blanche posée sur le fond gris de la page, avec une ombre
      // douce plutôt qu'un trait de séparation : c'est ce qui détache l'en-tête
      // du contenu sans créer de ligne dure, comme les en-têtes du web.
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        border: const Border(bottom: BorderSide(color: AppColors.inputBorder)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // `LayoutBuilder` : la barre doit tenir aussi bien dans une fenêtre de
      // 1440 px que dans une fenêtre réduite à 420. En dessous du seuil, les
      // actions passent sous le titre au lieu de le comprimer jusqu'au
      // débordement — c'est ce débordement que le test de mise en page
      // signalait (« A RenderFlex overflowed by N pixels on the right »).
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < _kNarrowBreakpoint;

          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // `maxLines` + ellipse : un titre de page long doit se
              // tronquer plutôt que de pousser les actions hors de la barre.
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.h1.copyWith(fontSize: 24),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body,
                ),
              ],
            ],
          );

          // `Wrap` plutôt qu'un `Row` : au-delà de deux ou trois actions, ou
          // avec une police agrandie, la rangée se replie sur une ligne
          // supplémentaire au lieu de déborder.
          final actionsRow = Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: actions,
          );

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                titleBlock,
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  actionsRow,
                ],
              ],
            );
          }

          return Row(
            children: [
              // Titre (+ sous-titre) à gauche. Expanded pour laisser toute
              // la place restante aux actions à droite sans déborder.
              Expanded(child: titleBlock),
              if (actions.isNotEmpty) ...[
                const SizedBox(width: 16),
                Flexible(child: actionsRow),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Petit bouton icône rond (ex: cloche de notification, engrenage
/// paramètres), utilisé dans la barre du haut.
class TopBarIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool showDot; // petit point rouge (ex: notification non lue)

  /// Info-bulle affichée au survol. Un bouton icône seul est ambigu ; sur une
  /// application de bureau, l'infobulle est le seul endroit où nommer l'action.
  final String? tooltip;

  const TopBarIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.showDot = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          children: [
            // `PhosphorIcon` et non `Icon` : une donnée duotone passée ici
            // perdrait son calque secondaire avec le widget Material.
            Center(
              child:
                  PhosphorIcon(icon, size: 20, color: AppColors.textSecondary),
            ),
            if (showDot)
              Positioned(
                top: 9,
                right: 9,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
