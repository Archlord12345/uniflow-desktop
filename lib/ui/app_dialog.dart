import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/uni_icons.dart';
import 'app_button.dart';

/// Dialogue du design system (`Modal.tsx`) : icône dans une pastille
/// dégradée, titre, contenu, boutons alignés à droite. Largeur bornée à 90 %
/// de la fenêtre et 520 px : un `AlertDialog` de 280 px paraît perdu en 4K,
/// un dialogue fixe déborde en 800×600.
class AppDialog extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? content;
  final List<Widget> actions;
  final double maxWidth;

  const AppDialog({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.content,
    this.actions = const [],
    this.maxWidth = 520,
  });

  /// Confirmation à deux boutons ; renvoie `true` si l'utilisateur confirme.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirmer',
    String cancelLabel = 'Annuler',
    bool destructive = false,
    IconData? icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: title,
        icon: icon ?? (destructive ? UniIcons.warning() : UniIcons.help()),
        content: Text(message, style: AppTextStyles.body),
        actions: [
          AppButton.secondary(
              label: cancelLabel,
              onPressed: () => Navigator.of(context).pop(false)),
          if (destructive)
            AppButton.danger(
                label: confirmLabel,
                onPressed: () => Navigator.of(context).pop(true))
          else
            AppButton(
                label: confirmLabel,
                onPressed: () => Navigator.of(context).pop(true)),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = UniFlowColors.of(context);
    final width =
        (MediaQuery.sizeOf(context).width * 0.9).clamp(280.0, maxWidth);
    return Dialog(
      backgroundColor: colors.surface,
      insetPadding: const EdgeInsets.all(AppSpacing.xxl),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppColors.logoGradient,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: PhosphorIcon(
                        icon!,
                        color: Colors.white,
                        size: 22,
                        duotoneSecondaryColor: Colors.white,
                        duotoneSecondaryOpacity: 0.45,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title,
                            style: AppTextStyles.h2
                                .copyWith(fontSize: 18, color: colors.text)),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(subtitle!,
                              style: AppTextStyles.body
                                  .copyWith(color: colors.muted)),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: PhosphorIcon(UniIcons.close(UniIconStyle.bold),
                        size: 20, color: colors.muted),
                  ),
                ],
              ),
              if (content != null) ...[
                const SizedBox(height: AppSpacing.xl),
                Flexible(child: SingleChildScrollView(child: content)),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxl),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.sm,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
