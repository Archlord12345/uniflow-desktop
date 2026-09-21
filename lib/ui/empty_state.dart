import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/uni_icons.dart';
import 'app_button.dart';

/// État vide (`EmptyState.tsx` du web) : icône dans une pastille dégradée
/// claire, titre, explication et action facultative. Il défile dans un espace
/// contraint : un état vide qui déborde est pire qu'une liste vide.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = UniFlowColors.of(context);
    final size = compact ? 44.0 : 56.0;
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
          vertical: compact ? AppSpacing.xl : AppSpacing.section,
          horizontal: AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconTile(
            icon: icon,
            color: AppColors.primaryBlue,
            size: size,
            semanticLabel: title,
          ),
          SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: compact ? AppTextStyles.size14 : AppTextStyles.size16,
              fontWeight: FontWeight.w700,
              color: colors.text,
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                description!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTextStyles.fontFamily,
                  fontSize:
                      compact ? AppTextStyles.size12 : AppTextStyles.size14,
                  height: 1.45,
                  color: colors.muted,
                ),
              ),
            ),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: AppSpacing.xl),
            AppButton.secondary(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}
