import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Avatar rond affichant des initiales sur un fond coloré.
/// Utilisé pour les étudiants dans le tableau, et pour l'utilisateur
/// connecté en bas de la sidebar.
class InitialsAvatar extends StatelessWidget {
  final String initials;
  final Color backgroundColor;
  final Color textColor;
  final double size;

  const InitialsAvatar({
    super.key,
    required this.initials,
    this.backgroundColor = const Color(0xFFDCEBFF),
    this.textColor = AppColors.primaryBlue,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
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
}
