import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Tonalité sémantique d'un badge, alignée sur les couleurs d'état du web.
enum BadgeTone {
  neutral,
  primary,
  teal,
  success,
  warning,
  danger,
  info,
  purple
}

/// Pilule de statut (`Badge.tsx`) : fond très clair, texte de la même teinte
/// mais foncé, 12 px gras. Le web accepte aussi un point coloré à gauche
/// (`dot`), utile dans les listes denses.
class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeTone tone;
  final bool dot;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    this.tone = BadgeTone.neutral,
    this.dot = false,
    this.icon,
  });

  /// Déduit la tonalité d'un statut textuel courant (« Actif », « En
  /// attente », « Rejeté »…) pour les listes qui reçoivent des statuts bruts.
  factory StatusBadge.fromStatus(String status) {
    final s = status.trim().toUpperCase();
    BadgeTone tone;
    if (const {
      'ACTIF',
      'ACTIVE',
      'VALIDÉ',
      'VALIDATED',
      'PRÉSENT',
      'PRESENT',
      'PUBLIÉ',
      'PUBLISHED',
      'SOUMIS',
      'NOTÉ'
    }.contains(s)) {
      tone = BadgeTone.success;
    } else if (const {'EN ATTENTE', 'PENDING', 'À RENDRE', 'BROUILLON', 'DRAFT'}
        .contains(s)) {
      tone = BadgeTone.warning;
    } else if (const {
      'REJETÉ',
      'REJECTED',
      'ABSENT',
      'EN RETARD',
      'ÉCHEC',
      'INACTIF'
    }.contains(s)) {
      tone = BadgeTone.danger;
    } else if (const {'CM'}.contains(s)) {
      tone = BadgeTone.primary;
    } else if (s.startsWith('TD')) {
      tone = BadgeTone.teal;
    } else if (s.startsWith('TP')) {
      tone = BadgeTone.warning;
    } else {
      tone = BadgeTone.neutral;
    }
    return StatusBadge(label: status, tone: tone);
  }

  ({Color bg, Color fg}) _palette(UniFlowColors colors) {
    switch (tone) {
      case BadgeTone.neutral:
        return (bg: colors.surfaceMuted, fg: colors.muted);
      case BadgeTone.primary:
        return (bg: AppColors.primary50, fg: AppColors.primaryBlue);
      case BadgeTone.teal:
        return (bg: AppColors.teal50, fg: AppColors.teal);
      case BadgeTone.success:
        return (bg: const Color(0xFFD1FAE5), fg: const Color(0xFF047857));
      case BadgeTone.warning:
        return (bg: const Color(0xFFFEF3C7), fg: const Color(0xFFB45309));
      case BadgeTone.danger:
        return (bg: const Color(0xFFFEE2E2), fg: const Color(0xFFB91C1C));
      case BadgeTone.info:
        return (bg: const Color(0xFFDBEAFE), fg: const Color(0xFF1D4ED8));
      case BadgeTone.purple:
        return (bg: const Color(0xFFEDE9FE), fg: AppColors.purple);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = _palette(UniFlowColors.of(context));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration:
                  BoxDecoration(color: palette.fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ] else if (icon != null) ...[
            Icon(icon, size: 12, color: palette.fg),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontSize: AppTextStyles.size12,
                fontWeight: FontWeight.w700,
                color: palette.fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
