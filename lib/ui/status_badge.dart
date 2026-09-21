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

  /// Teinte libre, pour les données qui portent leur propre couleur (types
  /// de séance de l'emploi du temps) : fond à 15 %, texte de la teinte pleine.
  /// Prend le pas sur [tone].
  final Color? color;

  const StatusBadge({
    super.key,
    required this.label,
    this.tone = BadgeTone.neutral,
    this.dot = false,
    this.icon,
  }) : color = null;

  const StatusBadge.tinted({
    super.key,
    required this.label,
    required Color this.color,
    this.dot = false,
    this.icon,
  }) : tone = BadgeTone.neutral;

  /// Tonalité d'un statut textuel courant (« Actif », « En attente »,
  /// « Suspendu », « Cours magistral »…), pour les listes qui reçoivent des
  /// libellés bruts. Exposée pour que les écrans puissent l'utiliser sans
  /// construire le badge (légendes, tests).
  static BadgeTone toneFor(String status) {
    final s = status.trim().toUpperCase();
    if (const {
      'ACTIF',
      'ACTIVE',
      'VALIDÉ',
      'VALIDATED',
      'PRÉSENT',
      'PRESENT',
      'PUBLIÉ',
      'PUBLIÉE',
      'PUBLISHED',
      'SOUMIS',
      'NOTÉ',
      'EN ÉCOUTE',
      'NIVEAU',
    }.contains(s)) {
      return BadgeTone.success;
    }
    if (const {
      'EN ATTENTE',
      'PENDING',
      'À RENDRE',
      'BROUILLON',
      'DRAFT',
      'NON PUBLIÉE',
    }.contains(s)) {
      return BadgeTone.warning;
    }
    if (const {
      'REJETÉ',
      'REJECTED',
      'ABSENT',
      'EN RETARD',
      'ÉCHEC',
      'INACTIF',
      'SUSPENDU',
      'SUSPENDED',
    }.contains(s)) {
      return BadgeTone.danger;
    }
    // Types de séance : les mêmes teintes que la légende de l'emploi du temps
    // (CM bleu, TD sarcelle, TP ambre), que la base écrive le sigle ou le nom.
    if (s == 'CM' || s == 'COURS MAGISTRAL') return BadgeTone.primary;
    if (s.startsWith('TD') || s == 'TRAVAUX DIRIGÉS') return BadgeTone.teal;
    if (s.startsWith('TP') || s == 'TRAVAUX PRATIQUES') {
      return BadgeTone.warning;
    }
    return BadgeTone.neutral;
  }

  factory StatusBadge.fromStatus(String status, {Key? key, bool dot = false}) =>
      StatusBadge(key: key, label: status, tone: toneFor(status), dot: dot);

  ({Color bg, Color fg}) _palette(UniFlowColors colors) {
    final tint = color;
    if (tint != null) {
      return (bg: tint.withValues(alpha: 0.15), fg: tint);
    }
    switch (tone) {
      case BadgeTone.neutral:
        return (bg: colors.surfaceMuted, fg: colors.muted);
      case BadgeTone.primary:
        return (bg: AppColors.primary50, fg: AppColors.primaryBlue);
      case BadgeTone.teal:
        return (bg: AppColors.teal50, fg: AppColors.teal);
      case BadgeTone.success:
        return (bg: AppColors.success100, fg: AppColors.successDark);
      case BadgeTone.warning:
        return (bg: AppColors.warning100, fg: AppColors.warningDark);
      case BadgeTone.danger:
        return (bg: AppColors.danger100, fg: AppColors.dangerDark);
      case BadgeTone.info:
        return (bg: AppColors.info100, fg: AppColors.infoDark);
      case BadgeTone.purple:
        return (bg: AppColors.purple100, fg: AppColors.purple);
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
