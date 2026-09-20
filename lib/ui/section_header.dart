import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// En-tête de section d'une carte : titre en gras (14 px), sous-titre
/// atténué, et à droite soit une icône, soit un lien « Voir détails → ».
/// C'est le `flex items-center justify-between mb-4` répété sur chaque carte
/// du tableau de bord web.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? trailingIcon;
  final Color? trailingIconColor;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? actionColor;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailingIcon,
    this.trailingIconColor,
    this.actionLabel,
    this.onAction,
    this.actionColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = UniFlowColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTextStyles.fontFamily,
                  fontSize: AppTextStyles.size14,
                  fontWeight: FontWeight.w700,
                  color: colors.text,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTextStyles.fontFamily,
                    fontSize: AppTextStyles.size12,
                    color: colors.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: actionColor ?? colors.primary,
              textStyle: const TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontSize: AppTextStyles.size12,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text('$actionLabel →',
                maxLines: 1, overflow: TextOverflow.ellipsis),
          )
        else if (trailingIcon != null)
          Icon(trailingIcon,
              size: 16, color: trailingIconColor ?? AppColors.teal),
      ],
    );
  }
}
