import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/avatar.dart';

/// Avatar neutre affichant la photo, ou une silhouette grise sans aucun texte.
///
/// Distinct d'[InitialsAvatar] à dessein. Les initiales ont leur place dans un
/// tableau où chaque ligne doit rester identifiable ; sur la page Équipe, le
/// propriétaire a demandé qu'**aucune écriture** ne figure sur la photo — des
/// initiales y donnent l'impression d'une image qui n'a pas chargé. Quand il
/// n'y a pas de photo, cet avatar montre donc une silhouette, jamais un texte.
class SilhouetteAvatar extends StatelessWidget {
  final String? avatarFileId;
  final double size;

  /// Coins arrondis. `null` donne un cercle ; les cartes de l'équipe passent un
  /// rayon plus doux, comme le `rounded-2xl` de la page web.
  final BorderRadius? borderRadius;

  final Color background;
  final Color foreground;

  const SilhouetteAvatar({
    super.key,
    this.avatarFileId,
    this.size = 56,
    this.borderRadius,
    this.background = AppColors.inputFill,
    this.foreground = AppColors.textMuted,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(size / 2);

    Widget silhouette() => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: background, borderRadius: radius),
          alignment: Alignment.center,
          child: Icon(Icons.person_outline, size: size * 0.5, color: foreground),
        );

    final url = avatarUrl(avatarFileId);
    if (url == null) return silhouette();

    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // Une photo retirée du bucket ou un réseau coupé ramène à la
        // silhouette, jamais à un trou ni à des initiales.
        errorBuilder: (_, __, ___) => silhouette(),
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : Container(
                width: size,
                height: size,
                decoration: BoxDecoration(color: background, borderRadius: radius),
              ),
      ),
    );
  }
}

/// Avatar rond affichant la photo de profil du compte, ou ses initiales sur un
/// fond coloré en l'absence de photo.
/// Utilisé pour les étudiants dans le tableau, et pour l'utilisateur
/// connecté en haut de la sidebar.
class InitialsAvatar extends StatelessWidget {
  final String initials;
  final Color backgroundColor;
  final Color textColor;
  final double size;

  /// Identifiant du fichier dans le bucket Appwrite `uniflow_assets`. Quand il
  /// est renseigné, la photo remplace les initiales ; sinon l'affichage reste
  /// exactement celui d'avant, si bien que les appels existants ne changent pas.
  final String? avatarFileId;

  const InitialsAvatar({
    super.key,
    required this.initials,
    this.backgroundColor = const Color(0xFFDCEBFF),
    this.textColor = AppColors.primaryBlue,
    this.size = 36,
    this.avatarFileId,
  });

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl(avatarFileId);

    if (url == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          initials,
          style: TextStyle(
            fontSize: size * 0.36,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      );
    }

    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // Une photo supprimée côté serveur ou un réseau coupé ne doit pas
        // laisser un trou : on retombe sur les initiales.
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: TextStyle(
              fontSize: size * 0.36,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ),
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: backgroundColor.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
              ),
      ),
    );
  }
}
