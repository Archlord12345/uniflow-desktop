import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/avatar.dart';

/// Avatar rond affichant la photo de profil du compte, ou ses initiales sur un
/// fond coloré en l'absence de photo.
/// Utilisé pour les étudiants dans le tableau, et pour l'utilisateur
/// connecté en haut de la sidebar.
class InitialsAvatar extends StatelessWidget {
  final String initials;
  final Color backgroundColor;
  final Color textColor;
  final double size;

  /// Identifiant du fichier dans le bucket Appwrite `uniflow_avatars`. Quand il
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
