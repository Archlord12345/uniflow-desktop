import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AppButtonVariant { primary, secondary, ghost, danger }

/// Bouton du design system.
///
/// - `primary` : dégradé indigo → teal, texte blanc, ombre bleue (le
///   `authButtonClass` et les boutons d'action du web) ;
/// - `secondary` : surface claire, bordure, texte foncé ;
/// - `ghost` : sans fond, texte primaire (liens d'action) ;
/// - `danger` : rouge plein, réservé aux suppressions.
///
/// `ElevatedButton` ne sait pas peindre un dégradé : c'est pour cela que le
/// primaire est dessiné à la main plutôt qu'hérité du thème.
class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final bool loading;
  final bool expand;
  final double height;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.expand = false,
    this.height = 44,
  });

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.height = 44,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.height = 40,
  }) : variant = AppButtonVariant.ghost;

  const AppButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.height = 44,
  }) : variant = AppButtonVariant.danger;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = UniFlowColors.of(context);
    final disabled = widget.onPressed == null || widget.loading;

    Gradient? gradient;
    Color? background;
    Color foreground;
    BorderSide side = BorderSide.none;
    List<BoxShadow> shadows = const [];

    switch (widget.variant) {
      case AppButtonVariant.primary:
        gradient = disabled ? null : AppColors.logoGradient;
        background = disabled ? colors.border : null;
        foreground = disabled ? colors.muted : Colors.white;
        if (!disabled) {
          shadows = [
            BoxShadow(
              color:
                  AppColors.primaryBlue.withValues(alpha: _hover ? 0.34 : 0.22),
              blurRadius: _hover ? 22 : 14,
              offset: Offset(0, _hover ? 8 : 5),
            ),
          ];
        }
      case AppButtonVariant.secondary:
        background = _hover ? colors.surfaceMuted : colors.surface;
        foreground = disabled ? colors.muted : colors.text;
        side = BorderSide(color: colors.border, width: 1.5);
      case AppButtonVariant.ghost:
        background = _hover
            ? colors.primary.withValues(alpha: 0.08)
            : Colors.transparent;
        foreground = disabled ? colors.muted : colors.primary;
      case AppButtonVariant.danger:
        background = disabled
            ? colors.border
            : (_hover ? const Color(0xFFDC2626) : AppColors.danger);
        foreground = disabled ? colors.muted : Colors.white;
    }

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      side: side,
    );

    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
          )
        else if (widget.icon != null)
          Icon(widget.icon, size: 18, color: foreground),
        if (widget.loading || widget.icon != null) const SizedBox(width: 8),
        Flexible(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: AppTextStyles.size14,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ),
      ],
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: widget.height,
        decoration: ShapeDecoration(
          color: gradient == null ? background : null,
          gradient: gradient,
          shape: shape,
          shadows: shadows,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: disabled ? null : widget.onPressed,
            customBorder: shape,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
