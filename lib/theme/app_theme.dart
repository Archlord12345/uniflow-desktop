import 'package:flutter/material.dart';

/// Palette de couleurs UniFlow — dégradé bleu → teal, tel qu'utilisé
/// dans le logo et les accents de l'interface.
///
/// Centraliser les couleurs ici permet de garder une cohérence visuelle
/// sur toutes les pages (login, dashboard, gestion étudiants, etc.)
/// et de pouvoir changer facilement le thème plus tard (ex: dark mode).
class AppColors {
  AppColors._(); // constructeur privé : cette classe ne sert qu'à stocker des constantes, pas à être instanciée

  // --- Couleurs de marque (issues du logo) ---
  static const Color primaryBlue = Color(0xFF2F5FDB); // bleu principal : boutons, liens, éléments actifs
  static const Color deepBlue = Color(0xFF1E3A8A);     // bleu foncé : formes décoratives, sidebar
  static const Color teal = Color(0xFF0FBFA0);         // teal : accent secondaire du logo
  static const Color tealLight = Color(0xFF5FE0C7);    // teal clair : variantes/hover

  // --- Fond et surfaces ---
  static const Color background = Color(0xFFF4F6FA); // fond général de l'app (gris très clair)
  static const Color cardWhite = Color(0xFFFFFFFF);  // fond des cartes/blocs blancs

  // --- Textes ---
  static const Color textPrimary = Color(0xFF1A1D29);   // titres, texte important
  static const Color textSecondary = Color(0xFF8A8FA3); // sous-titres, texte secondaire
  static const Color textMuted = Color(0xFFB0B4C4);     // placeholders, texte très discret

  // --- Champs de formulaire ---
  static const Color inputFill = Color(0xFFF7F8FB);   // fond des champs de saisie
  static const Color inputBorder = Color(0xFFE3E6EE); // bordure par défaut des champs

  // --- États / feedback ---
  static const Color danger = Color(0xFFE85C5C);  // erreurs, suppressions
  static const Color success = Color(0xFF34C77B); // succès, confirmations
  static const Color warning = Color(0xFFF5A623); // avertissements

  // --- Sidebar (utile pour les pages suivantes : dashboard, gestion, etc.) ---
  static const Color sidebarBg = Color(0xFF141A2E);     // fond bleu nuit de la barre latérale
  static const Color sidebarActive = Color(0xFF2F5FDB); // couleur de l'item de menu actif

  /// Dégradé utilisé sur l'icône du logo (bleu → teal, diagonale haut-gauche vers bas-droite)
  static const LinearGradient logoGradient = LinearGradient(
    colors: [primaryBlue, teal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Styles de texte réutilisables (titres, corps de texte, labels, boutons...)
/// À utiliser partout au lieu de définir des TextStyle en dur dans les écrans,
/// pour garder une typographie cohérente.
class AppTextStyles {
  AppTextStyles._();

  static const String fontFamily = 'Inter'; // police proche de celle de la maquette

  /// Grand titre (ex: "Bienvenue chez UniFlow")
  static const TextStyle h1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  /// Titre de section (ex: en-tête de carte, titre de page)
  static const TextStyle h2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  /// Texte courant / sous-titres
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  /// Label au-dessus des champs de formulaire (ex: "Email", "Mot de passe")
  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// Texte des boutons pleins (fond coloré, texte blanc)
  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  /// Liens cliquables (ex: "Mot de passe oublié ?")
  static const TextStyle link = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryBlue,
  );
}

/// Thème global de l'application, injecté dans le MaterialApp.
/// Regroupe la config par défaut (couleurs, boutons, police) pour éviter
/// de re-styliser chaque widget individuellement dans chaque écran.
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: AppTextStyles.fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryBlue,
        primary: AppColors.primaryBlue,
        secondary: AppColors.teal,
        background: AppColors.background,
      ),
      // Style par défaut de tous les ElevatedButton de l'app
      // (ex: le bouton "Se connecter") : coins arrondis, pas d'ombre,
      // padding vertical généreux pour un look moderne "flat design".
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: AppTextStyles.button,
        ),
      ),
    );
  }
}
