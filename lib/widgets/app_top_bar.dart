import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        border: Border(bottom: BorderSide(color: AppColors.inputBorder)),
      ),
      child: Row(
        children: [
          // Titre (+ sous-titre) à gauche. Expanded pour laisser toute
          // la place restante aux actions à droite sans déborder.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppTextStyles.h1.copyWith(fontSize: 24)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: AppTextStyles.body),
                ],
              ],
            ),
          ),
          // Actions à droite, séparées par un petit espace
          Row(
            children: [
              for (final action in actions) ...[
                action,
                const SizedBox(width: 12),
              ],
            ],
          ),
        ],
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

  const TopBarIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
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
            Center(child: Icon(icon, size: 20, color: AppColors.textSecondary)),
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
  }
}
