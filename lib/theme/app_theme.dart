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

  /// Ambre des planches (TP, statuts « Occupée », « Vacataire ») : la même
  /// teinte que [warning], nommée comme dans `docs/design/README.md`.
  static const Color amber = warning;

  // --- Sidebar (thème sombre) ---------------------------------------------
  // Depuis les planches du 2026-09-21, la barre latérale est claire en thème
  // clair (`SidebarPalette.light`) ; ces teintes ne servent qu'au thème sombre.
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

  /// Dégradé du panneau d'authentification, identique au web
  /// (`from-[#1e3a8a] via-[#2d4fa8] to-[#0d9488]`).
  static const LinearGradient authHeroGradient = LinearGradient(
    colors: [Color(0xFF1E3A8A), Color(0xFF2D4FA8), Color(0xFF0D9488)],
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

/// Grille d'espacement de 4 px, comme les classes `p-1`…`p-8` de Tailwind
/// côté web : un écran qui mélange 13, 18 et 22 px paraît « bricolé ».
class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double section = 40;
}

/// Rayons : 12 (`rounded-xl`), 16 (`rounded-2xl`, cartes du tableau de bord),
/// 20 (`rounded-3xl`, panneaux d'authentification).
class AppRadius {
  AppRadius._();
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double pill = 999;
}

/// Ombres douces du web (`shadow-sm`, `shadow-md`, `shadow-lg`), teintées du
/// bleu de marque pour ne pas grisailler le fond `#f3f4f6`.
class AppShadows {
  AppShadows._();
  static List<BoxShadow> get card => [
        BoxShadow(
          color: AppColors.primaryBlue.withValues(alpha: 0.05),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ];
  static List<BoxShadow> get cardHover => [
        BoxShadow(
          color: AppColors.primaryBlue.withValues(alpha: 0.12),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ];
  static List<BoxShadow> get floating => [
        BoxShadow(
          color: AppColors.deepBlue.withValues(alpha: 0.18),
          blurRadius: 40,
          offset: const Offset(0, 16),
        ),
      ];
}

/// Couleurs qui changent avec le thème (fond, surface, bordure, texte), lues
/// via `UniFlowColors.of(context)`. Les valeurs sombres sont celles du
/// `.dark` du web (`#0b0f19`, `#151e32`, `#243049`, `#f8fafc`, `#cbd5e1`).
///
/// `AppColors` reste la palette claire historique utilisée par les écrans
/// existants ; les composants de `lib/ui/` lisent cette extension pour
/// fonctionner dans les deux thèmes.
@immutable
class UniFlowColors extends ThemeExtension<UniFlowColors> {
  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color border;
  final Color text;
  final Color muted;
  final Color primary;
  final Color primaryLight;
  final Color primaryDark;
  final Color sidebar;
  final Color sidebarDeep;

  const UniFlowColors({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.text,
    required this.muted,
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.sidebar,
    required this.sidebarDeep,
  });

  static const light = UniFlowColors(
    background: AppColors.background,
    surface: AppColors.cardWhite,
    surfaceMuted: AppColors.surfaceMuted,
    border: AppColors.inputBorder,
    text: AppColors.textPrimary,
    muted: AppColors.textSecondary,
    primary: AppColors.primaryBlue,
    primaryLight: AppColors.primaryLight,
    primaryDark: AppColors.deepBlue,
    sidebar: AppColors.sidebarBg,
    sidebarDeep: AppColors.sidebarBgDeep,
  );

  static const dark = UniFlowColors(
    background: Color(0xFF0B0F19),
    surface: Color(0xFF151E32),
    surfaceMuted: Color(0xFF1B2540),
    border: Color(0xFF243049),
    text: Color(0xFFF8FAFC),
    muted: Color(0xFFCBD5E1),
    primary: Color(0xFF3B82F6),
    primaryLight: Color(0xFF60A5FA),
    primaryDark: Color(0xFF1D4ED8),
    sidebar: Color(0xFF0B0F19),
    sidebarDeep: Color(0xFF060810),
  );

  static UniFlowColors of(BuildContext context) =>
      Theme.of(context).extension<UniFlowColors>() ?? light;

  @override
  UniFlowColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? border,
    Color? text,
    Color? muted,
    Color? primary,
    Color? primaryLight,
    Color? primaryDark,
    Color? sidebar,
    Color? sidebarDeep,
  }) =>
      UniFlowColors(
        background: background ?? this.background,
        surface: surface ?? this.surface,
        surfaceMuted: surfaceMuted ?? this.surfaceMuted,
        border: border ?? this.border,
        text: text ?? this.text,
        muted: muted ?? this.muted,
        primary: primary ?? this.primary,
        primaryLight: primaryLight ?? this.primaryLight,
        primaryDark: primaryDark ?? this.primaryDark,
        sidebar: sidebar ?? this.sidebar,
        sidebarDeep: sidebarDeep ?? this.sidebarDeep,
      );

  @override
  UniFlowColors lerp(UniFlowColors? other, double t) {
    if (other == null) return this;
    return UniFlowColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      sidebarDeep: Color.lerp(sidebarDeep, other.sidebarDeep, t)!,
    );
  }
}

/// Styles de texte réutilisables.
///
/// À utiliser partout au lieu de définir des `TextStyle` en dur dans les
/// écrans, pour garder une typographie cohérente avec le web.
class AppTextStyles {
  AppTextStyles._();

  /// Police de l'interface : Inter, embarquée dans `assets/fonts/` et
  /// déclarée dans `pubspec.yaml`. Avant, la famille était nommée sans être
  /// fournie et Flutter retombait sur la police système : le desktop ne
  /// ressemblait pas au web.
  static const String fontFamily = 'Inter';

  /// Échelle typographique du web : 12 / 14 / 16 / 20 / 24 / 32.
  static const double size12 = 12;
  static const double size14 = 14;
  static const double size16 = 16;
  static const double size20 = 20;
  static const double size24 = 24;
  static const double size32 = 32;

  /// Titre d'écran (`text-3xl font-black`).
  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontSize: size32,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    height: 1.15,
    letterSpacing: -0.5,
  );

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

  /// Transitions de page douces : fondu + léger glissement vertical, sur les
  /// trois plateformes de bureau. La transition Material par défaut (zoom) est
  /// pensée pour le tactile et paraît brusque à la souris.
  static const PageTransitionsTheme pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
    },
  );

  static ThemeData get lightTheme => _build(UniFlowColors.light);

  /// Thème sombre du web (`.dark` de `index.css`).
  static ThemeData get darkTheme => _build(UniFlowColors.dark);

  /// Échelle typographique appliquée au `textTheme` Material, pour que les
  /// widgets standard (`ListTile`, `DataTable`, `AlertDialog`) parlent la même
  /// langue que les écrans : 12 / 14 / 16 / 20 / 24 / 32.
  static TextTheme _textTheme(Color text, Color muted) {
    TextStyle style(double size, FontWeight weight, {Color? color}) =>
        TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: size,
          fontWeight: weight,
          color: color ?? text,
          height: 1.35,
        );
    return TextTheme(
      displayLarge: style(AppTextStyles.size32, FontWeight.w800),
      headlineMedium: style(AppTextStyles.size24, FontWeight.w700),
      titleLarge: style(AppTextStyles.size20, FontWeight.w700),
      titleMedium: style(AppTextStyles.size16, FontWeight.w600),
      titleSmall: style(AppTextStyles.size14, FontWeight.w600),
      bodyLarge: style(AppTextStyles.size16, FontWeight.w400),
      bodyMedium: style(AppTextStyles.size14, FontWeight.w400),
      bodySmall: style(AppTextStyles.size12, FontWeight.w400, color: muted),
      labelLarge: style(AppTextStyles.size14, FontWeight.w600),
      labelMedium: style(AppTextStyles.size12, FontWeight.w600),
      labelSmall: style(11, FontWeight.w700, color: muted),
    );
  }

  static ThemeData _build(UniFlowColors c) {
    final dark = c == UniFlowColors.dark;
    final base = ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: c.background,
      fontFamily: AppTextStyles.fontFamily,
      pageTransitionsTheme: pageTransitions,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      extensions: [c],
      colorScheme: ColorScheme.fromSeed(
        seedColor: c.primary,
        brightness: dark ? Brightness.dark : Brightness.light,
        primary: c.primary,
        secondary: AppColors.teal,
        surface: c.surface,
        error: AppColors.danger,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: c.text,
        outline: c.border,
      ),
    );

    if (dark) {
      // Le thème sombre ne reprend que les réglages qui dépendent des couleurs ;
      // les formes (rayons, densité) sont partagées avec le thème clair.
      return base.copyWith(
        textTheme: _textTheme(c.text, c.muted),
        cardTheme: CardThemeData(
          color: c.surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusCard),
            side: BorderSide(color: c.border),
          ),
        ),
        dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: c.surfaceMuted,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusCard),
            borderSide: BorderSide(color: c.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusCard),
            borderSide: BorderSide(color: c.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusCard),
            borderSide: BorderSide(color: c.primary, width: 1.5),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: c.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg)),
        ),
      );
    }

    return base.copyWith(
      // --- Textes -------------------------------------------------------
      textTheme: _textTheme(c.text, c.muted),

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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
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
          borderSide:
              const BorderSide(color: AppColors.primaryBlue, width: 1.5),
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
