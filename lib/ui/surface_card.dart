import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Carte de surface du design system : fond de surface, bordure `#e5e7eb`,
/// rayon 16 (`rounded-2xl`), ombre douce — la carte du tableau de bord web
/// (`rounded-2xl border border-[#e5e7eb] bg-white p-5 shadow-sm`).
///
/// Avec [onTap], la carte devient interactive : elle se soulève de 3 px et
/// renforce son ombre au survol (`card-interactive` du web). Le soulèvement
/// est une translation, pas un `scale` : un `scale` sur une grille de cartes
/// fait chevaucher les voisines.
class SurfaceCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final Color? color;
  final Color? borderColor;
  final bool dashedBorder;
  final Gradient? gradient;
  final Clip clipBehavior;

  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.onTap,
    this.radius = AppRadius.lg,
    this.color,
    this.borderColor,
    this.dashedBorder = false,
    this.gradient,
    this.clipBehavior = Clip.none,
  });

  @override
  State<SurfaceCard> createState() => _SurfaceCardState();
}

class _SurfaceCardState extends State<SurfaceCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = UniFlowColors.of(context);
    final interactive = widget.onTap != null;
    final lifted = interactive && _hover;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(widget.radius),
      side: widget.gradient != null
          ? BorderSide.none
          : BorderSide(color: widget.borderColor ?? colors.border),
    );

    Widget content = Padding(padding: widget.padding, child: widget.child);
    if (interactive) {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          customBorder: shape,
          child: content,
        ),
      );
    }

    return MouseRegion(
      cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: interactive ? (_) => setState(() => _hover = true) : null,
      onExit: interactive ? (_) => setState(() => _hover = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, lifted ? -3 : 0, 0),
        clipBehavior: widget.clipBehavior,
        decoration: ShapeDecoration(
          color:
              widget.gradient == null ? (widget.color ?? colors.surface) : null,
          gradient: widget.gradient,
          shape: shape,
          shadows: lifted ? AppShadows.cardHover : AppShadows.card,
        ),
        child: content,
      ),
    );
  }
}
