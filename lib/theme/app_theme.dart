import 'package:flutter/material.dart';

/// Palette de couleurs UniFlow.
///
/// Les valeurs sont **alignées sur le design system de la version web**
/// (`uniflow-we/src/index.css`) : mêmes primaires, mêmes neutres, mêmes
/// couleurs d'état. C'est ce qui garantit qu'une page du desktop ressemble à
/// la même page sur le web — auparavant les deux plateformes avaient dérivé
/// vers des bleus et des gris différents.
///
/// Les noms historiques (`primaryBlue`, `teal`, `textSecondary`…) sont
/// conservés : ils sont utilisés dans tous les écrans, les renommer n'aurait
/// apporté qu'un risque de régression.
class AppColors {
  AppColors._();

  // --- Couleurs de marque ------------------------------------------------
  /// Bleu principal (`--color-primary` du web).
  static const Color primaryBlue = Color(0xFF1E3A8A);

  /// Variante claire, pour les survols (`--color-primary-light`).
  static const Color primaryLight = Color(0xFF2D4FA8);

  /// Bleu foncé, pour les dégradés et les formes décoratives
  /// (`--color-primary-dark`, `--color-deepBlue` côté web).
  static const Color deepBlue = Color(0xFF152A66);

  /// Teintes très claires du bleu, pour les fonds de badges
  /// (`--color-primary-50` / `--color-primary-100`).
  static const Color primary50 = Color(0xFFEFF3FF);
  static const Color primary100 = Color(0xFFDCE5FD);

  /// Teal, accent secondaire du logo (`--color-teal`).
  static const Color teal = Color(0xFF0D9488);

  /// Teal clair, pour les survols (`--color-teal-light`).
  static const Color tealLight = Color(0xFF14B8A8);

  /// Teal foncé (`--color-teal-dark`).
  static const Color tealDark = Color(0xFF0A7167);

  /// Teintes très claires du teal, pour les fonds de badges.
  static const Color teal50 = Color(0xFFF0FDFA);
  static const Color teal100 = Color(0xFFCCFBF1);

  /// Violet, troisième accent utilisé par les dégradés « vibrants » du web.
  static const Color purple = Color(0xFF7C3AED);

  // --- Fond et surfaces --------------------------------------------------
  /// Fond général de l'app (`--color-bg`).
  static const Color background = Color(0xFFF3F4F6);

  /// Fond des cartes et panneaux (`--color-surface`).
  static const Color cardWhite = Color(0xFFFFFFFF);

  /// Gris très clair, pour les fonds de tableaux et de lignes alternées.
  static const Color surfaceMuted = Color(0xFFF9FAFB);

  // --- Textes ------------------------------------------------------------
  /// Titres et texte important (`--color-text`).
  static const Color textPrimary = Color(0xFF111827);

  /// Sous-titres et texte secondaire (`--color-muted`).
  static const Color textSecondary = Color(0xFF6B7280);

  /// Placeholders et texte très discret (gray-400 du web).
  static const Color textMuted = Color(0xFF9CA3AF);

  // --- Champs de formulaire ----------------------------------------------
  /// Fond des champs de saisie (gray-50 du web).
  static const Color inputFill = Color(0xFFF9FAFB);

  /// Bordure par défaut des champs et des cartes (`--color-border`).
  static const Color inputBorder = Color(0xFFE5E7EB);

  // --- États / feedback --------------------------------------------------
  static const Color danger = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // --- Sidebar -----------------------------------------------------------
  /// Fond bleu nuit de la barre latérale (extrémité haute du dégradé).
  static const Color sidebarBg = Color(0xFF151E32);

  /// Extrémité basse du dégradé de la sidebar : le fond s'assombrit vers le
  /// bas, comme la sidebar du web en thème sombre.
  static const Color sidebarBgDeep = Color(0xFF0B0F19);

  /// Couleur de l'item de menu actif. C'est le bleu du thème sombre du web
  /// (`#3B82F6`) plutôt que le bleu principal : sur un fond bleu nuit, le
  /// bleu `#1E3A8A` manquerait de contraste.
  static const Color sidebarActive = Color(0xFF3B82F6);

  /// Dégradé de la sidebar, du haut vers le bas.
  static const LinearGradient sidebarGradient = LinearGradient(
    colors: [sidebarBg, sidebarBgDeep],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // --- Dégradés ----------------------------------------------------------
  /// Dégradé du logo (bleu → teal), repris du `gradient-text` du web.
  static const LinearGradient logoGradient = LinearGradient(
    colors: [primaryBlue, teal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Dégradé des en-têtes (`admin-header-gradient` du web).
  static const LinearGradient headerGradient = LinearGradient(
    colors: [primaryBlue, deepBlue, Color(0xFF0D1F4F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Dégradé « mesh » des fonds de page d'authentification
  /// (`bg-gradient-mesh` du web).
  static const LinearGradient meshGradient = LinearGradient(
    colors: [primary50, teal50, Color(0xFFEDE9FE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Dégradé teal, pour les accents secondaires.
  static const LinearGradient tealGradient = LinearGradient(
    colors: [teal, tealDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Styles de texte réutilisables.
///
/// À utiliser partout au lieu de définir des `TextStyle` en dur dans les
/// écrans, pour garder une typographie cohérente avec le web.
class AppTextStyles {
  AppTextStyles._();

  /// Police de l'interface.
  ///
  /// ATTENTION : Inter n'est pas embarquée dans `pubspec.yaml`, Flutter se
  /// rabat donc sur la police système. Pour un rendu identique au web, il faut
  /// déposer les fichiers `.ttf` dans `assets/fonts/` et déclarer la famille
  /// dans la section `fonts:` de `pubspec.yaml` — la déclaration est prête en
  /// commentaire dans ce fichier.
  static const String fontFamily = 'Inter';

  /// Grand titre (ex: « Bienvenue chez UniFlow »).
  static const TextStyle h1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  /// Titre de section (ex: en-tête de carte, titre de page).
  static const TextStyle h2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.25,
  );

  /// Titre de carte, un cran sous [h2].
  static const TextStyle h3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  /// Texte courant / sous-titres.
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  /// Texte courant en version discrète.
  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
    height: 1.45,
  );

  /// Label au-dessus des champs de formulaire.
  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// Texte des boutons pleins (fond coloré, texte blanc).
  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  /// Liens cliquables (ex: « Mot de passe oublié ? »).
  static const TextStyle link = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryBlue,
  );

  /// Très petits libellés en majuscules (en-têtes de colonnes, sections).
  static const TextStyle overline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: AppColors.textMuted,
    letterSpacing: 0.4,
  );
}

/// Thème global de l'application, injecté dans le `MaterialApp`.
///
/// Enrichi pour couvrir les widgets Material standard (champs, boutons,
/// dialogues, barres de défilement…) : les écrans qui utilisent ces widgets
/// héritent alors du style du web sans avoir à le répéter.
class AppTheme {
  AppTheme._();

  /// Rayon des conteneurs principaux (`rounded-xl` du web = 12 px).
  static const double radiusCard = 12;

  /// Rayon des éléments interactifs (`rounded-lg` du web = 8 px).
  static const double radiusControl = 8;

  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: AppTextStyles.fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryBlue,
        primary: AppColors.primaryBlue,
        secondary: AppColors.teal,
        surface: AppColors.cardWhite,
        error: AppColors.danger,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
      ),
    );

    return base.copyWith(
      // --- Textes -------------------------------------------------------
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),

      // --- Boutons pleins ------------------------------------------------
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.inputBorder,
          disabledForegroundColor: AppColors.textMuted,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusCard),
          ),
          textStyle: AppTextStyles.button,
        ),
      ),

      // --- Boutons secondaires ------------------------------------------
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          backgroundColor: AppColors.cardWhite,
          side: const BorderSide(color: AppColors.inputBorder, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusCard),
          ),
          textStyle: AppTextStyles.button.copyWith(
            color: AppColors.textPrimary,
            fontSize: 14,
          ),
        ),
      ),

      // --- Boutons texte --------------------------------------------------
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryBlue,
          textStyle: AppTextStyles.link,
        ),
      ),

      // --- Champs de formulaire -------------------------------------------
      // Reprend le `.input-focus` du web : bordure bleue au focus et anneau
      // translucide de 3 px autour du champ.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardWhite,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        labelStyle: AppTextStyles.body,
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.textMuted),
        helperStyle: AppTextStyles.bodySmall,
        errorStyle: const TextStyle(fontSize: 12.5, color: AppColors.danger),
        prefixIconColor: AppColors.textMuted,
        suffixIconColor: AppColors.textMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
      ),

      // --- Cartes ---------------------------------------------------------
      cardTheme: CardThemeData(
        color: AppColors.cardWhite,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: AppColors.inputBorder),
        ),
      ),

      // --- Séparateurs -----------------------------------------------------
      dividerTheme: const DividerThemeData(
        color: AppColors.inputBorder,
        thickness: 1,
        space: 1,
      ),

      // --- Dialogues --------------------------------------------------------
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: AppTextStyles.h2.copyWith(fontSize: 18),
        contentTextStyle: AppTextStyles.body,
      ),

      // --- Notifications -----------------------------------------------------
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: 13.5,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
      ),

      // --- Info-bulles --------------------------------------------------------
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.textPrimary,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: const TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: 11.5,
          color: Colors.white,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      ),

      // --- Barres de défilement ------------------------------------------------
      // Fines et discrètes, comme la scrollbar du web (5 px).
      scrollbarTheme: ScrollbarThemeData(
        thickness: WidgetStateProperty.all(5),
        radius: const Radius.circular(10),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered)
              ? AppColors.textMuted
              : const Color(0xFFD1D5DB),
        ),
        trackColor: WidgetStateProperty.all(Colors.transparent),
        trackVisibility: WidgetStateProperty.all(false),
      ),

      // --- Cases à cocher -------------------------------------------------------
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primaryBlue
              : Colors.transparent,
        ),
        side: const BorderSide(color: AppColors.inputBorder, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // --- Listes déroulantes ----------------------------------------------------
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
      ),

      // --- Barres de progression ---------------------------------------------------
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primaryBlue,
        linearTrackColor: AppColors.inputBorder,
        circularTrackColor: AppColors.inputBorder,
      ),
    );
  }
}
