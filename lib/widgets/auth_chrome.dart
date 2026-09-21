import 'package:flutter/material.dart';

import '../models/user_role.dart';
import '../theme/app_theme.dart';
import 'motion.dart';
import 'uni/uni_mascot.dart';

/// Habillage commun des écrans d'authentification (connexion, inscription) :
/// fond « mesh », carte blanche, panneau visuel à gauche et formulaire à
/// droite, ou empilés sur une fenêtre étroite.
///
/// Extrait de l'écran de connexion pour que l'inscription ait exactement le
/// même cadre : deux écrans d'entrée qui ne se ressemblent pas donnent
/// l'impression de deux produits.

/// Rouge plus sombre que `AppColors.danger`, réservé au **texte** posé sur un
/// fond rouge très clair : le rouge d'alerte manque de contraste en lecture.
const Color kDangerInk = Color(0xFFB91C1C);

/// Au-dessous de cette largeur, une seule colonne : bandeau de marque compact
/// en haut, formulaire dessous. Au-dessus, deux colonnes plein écran comme le
/// web (`lg:` de Tailwind ≈ 1024 ; 900 ici parce qu'une fenêtre desktop
/// « moitié d'écran » fait souvent 960).
const double kAuthTwoColumnBreakpoint = 900;

/// Paliers d'échelle des écrans d'authentification.
///
/// Sur une fenêtre 1024×576, la connexion était une carte figée de ~570×320
/// au milieu d'un grand vide, avec des textes de taille « téléphone » ; en
/// plein écran 4K, la même carte. Les marges, titres, champs et boutons
/// suivent désormais la largeur de la fenêtre par paliers.
class AuthScale {
  /// Marge autour du formulaire.
  final double padding;

  /// Taille du titre principal (« Se connecter »).
  final double title;

  /// Taille du texte courant.
  final double body;

  /// Hauteur des champs et du bouton principal.
  final double field;

  /// Facteur appliqué au texte du formulaire (via `MediaQuery.textScaler`).
  final double textFactor;

  const AuthScale._({
    required this.padding,
    required this.title,
    required this.body,
    required this.field,
    required this.textFactor,
  });

  static const compact =
      AuthScale._(padding: 24, title: 24, body: 14, field: 48, textFactor: 1.0);
  static const regular = AuthScale._(
      padding: 40, title: 30, body: 15, field: 50, textFactor: 1.06);
  static const large = AuthScale._(
      padding: 52, title: 34, body: 16, field: 52, textFactor: 1.14);
  static const huge = AuthScale._(
      padding: 64, title: 40, body: 17, field: 56, textFactor: 1.26);

  /// Palier pour une largeur de fenêtre : < 900, 900–1400, 1400–1900, ≥ 1900
  /// (écrans 4K).
  static AuthScale forWidth(double width) {
    if (width < kAuthTwoColumnBreakpoint) return compact;
    if (width < 1400) return regular;
    if (width < 1900) return large;
    return huge;
  }

  /// Largeur du formulaire : ~40 % de la fenêtre, bornée [360, 560], sans
  /// dépasser 90 % de la colonne qui l'accueille.
  static double formWidth(double windowWidth, double columnWidth) {
    final target = (windowWidth * 0.4).clamp(360.0, 560.0);
    return target.clamp(0.0, columnWidth * 0.9).clamp(0.0, 560.0);
  }

  static AuthScale of(BuildContext context) =>
      _AuthScaleScope.of(context)?.scale ??
      forWidth(MediaQuery.sizeOf(context).width);
}

class _AuthScaleScope extends InheritedWidget {
  final AuthScale scale;
  const _AuthScaleScope({required this.scale, required super.child});

  static _AuthScaleScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_AuthScaleScope>();

  @override
  bool updateShouldNotify(_AuthScaleScope oldWidget) =>
      oldWidget.scale != scale;
}

/// Habillage plein écran des écrans d'authentification.
///
/// Deux colonnes dès [kAuthTwoColumnBreakpoint] : panneau de marque à gauche
/// (45 %, dégradé indigo → teal, logo, accroche, trois arguments,
/// illustration), formulaire à droite (55 %) sur fond clair, centré, largeur
/// [AuthScale.formWidth]. En dessous : bandeau compact puis formulaire pleine
/// largeur avec 24 px de marge. Le formulaire défile toujours : jamais de
/// débordement sur une petite fenêtre.
class AuthShell extends StatelessWidget {
  final Widget form;

  /// Conservés pour compatibilité des appelants ; la largeur est désormais
  /// calculée depuis la fenêtre ([AuthScale.formWidth]).
  final double formWidth;
  final double formWidthWide;

  const AuthShell({
    super.key,
    required this.form,
    this.formWidth = 380,
    this.formWidthWide = 460,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final scale = AuthScale.forWidth(width);
          final twoColumns = width >= kAuthTwoColumnBreakpoint;
          return _AuthScaleScope(
            scale: scale,
            child: twoColumns
                ? _twoColumns(context, constraints, scale)
                : _oneColumn(context, constraints, scale),
          );
        },
      ),
    );
  }

  Widget _twoColumns(
      BuildContext context, BoxConstraints constraints, AuthScale scale) {
    final heroWidth = constraints.maxWidth * 0.45;
    final formColumn = constraints.maxWidth - heroWidth;
    return Row(
      children: [
        SizedBox(
          width: heroWidth,
          height: constraints.maxHeight,
          child: CascadeIn(
            index: 0,
            offset: const Offset(-0.04, 0),
            child: AuthHeroPanel(scale: scale),
          ),
        ),
        Expanded(
          child: _FormColumn(
            form: form,
            scale: scale,
            columnWidth: formColumn,
            windowWidth: constraints.maxWidth,
            minHeight: constraints.maxHeight,
          ),
        ),
      ],
    );
  }

  Widget _oneColumn(
      BuildContext context, BoxConstraints constraints, AuthScale scale) {
    // Le bandeau garde une hauteur bornée pour laisser le formulaire respirer
    // même sur 800×600 ; le tout défile d'un bloc.
    final bannerHeight = (constraints.maxHeight * 0.26).clamp(120.0, 180.0);
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(
            height: bannerHeight,
            width: double.infinity,
            child: CascadeIn(
              index: 0,
              offset: const Offset(0, -0.05),
              child: AuthHeroPanel(scale: scale, compact: true),
            ),
          ),
          _FormColumn(
            form: form,
            scale: scale,
            columnWidth: constraints.maxWidth,
            windowWidth: constraints.maxWidth,
            minHeight: constraints.maxHeight - bannerHeight,
            scrollable: false,
          ),
        ],
      ),
    );
  }
}

/// Colonne claire qui centre le formulaire, le borne en largeur et le fait
/// défiler. Le texte du formulaire est mis à l'échelle du palier courant via
/// `MediaQuery.textScaler`, de sorte que titres, libellés et boutons
/// grandissent ensemble sans toucher chaque widget.
class _FormColumn extends StatelessWidget {
  final Widget form;
  final AuthScale scale;
  final double columnWidth;
  final double windowWidth;
  final double minHeight;
  final bool scrollable;

  const _FormColumn({
    required this.form,
    required this.scale,
    required this.columnWidth,
    required this.windowWidth,
    required this.minHeight,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = AuthScale.formWidth(windowWidth, columnWidth);
    final content = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(scale.padding),
          child: SizedBox(
            key: const Key('auth-form'),
            width: width,
            child: CascadeIn(
              index: 1,
              offset: const Offset(0, 0.04),
              child: MediaQuery(
                data: media.copyWith(
                  // Borné : l'agrandissement système reste respecté mais ne
                  // se cumule pas sans limite avec le palier.
                  textScaler: TextScaler.linear(
                    (media.textScaler.scale(1) * scale.textFactor)
                        .clamp(0.9, 1.6),
                  ),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    inputDecorationTheme:
                        Theme.of(context).inputDecorationTheme.copyWith(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical:
                                    ((scale.field - 20) / 2).clamp(12.0, 20.0),
                              ),
                            ),
                  ),
                  child: Material(type: MaterialType.transparency, child: form),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF8FAFC), Colors.white, Color(0xFFF8FAFC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: scrollable ? SingleChildScrollView(child: content) : content,
    );
  }
}

/// Arguments affichés sur le panneau de marque — les trois du web
/// (`LoginPage.tsx`), pour que les deux clients racontent la même chose.
const List<({IconData icon, String title, String desc, Color color})>
    kAuthFeatures = [
  (
    icon: Icons.school_outlined,
    title: 'Gestion académique complète',
    desc:
        'Cours, devoirs, notes et emploi du temps centralisés en un seul endroit.',
    color: Color(0xFF34D399),
  ),
  (
    icon: Icons.wifi_tethering_outlined,
    title: 'Accès résilient',
    desc:
        'Les données consultées restent disponibles ; les opérations sensibles exigent une session active.',
    color: Color(0xFF60A5FA),
  ),
  (
    icon: Icons.verified_user_outlined,
    title: 'Rôles contrôlés',
    desc:
        'La session Appwrite et les permissions par rôle encadrent chaque accès.',
    color: Color(0xFFC084FC),
  ),
];

/// Panneau de marque : dégradé indigo `#1e3a8a` → `#2d4fa8` → teal `#0d9488`
/// (celui du web), halos, logo, accroche, trois arguments, illustration.
///
/// L'ancienne photo `login.jpg` (322×620) étirée en `BoxFit.cover` sur tout
/// le panneau sortait floue : elle est remplacée par le logotype du web
/// (1200 px) sur une plaque blanche, net à toute taille.
class AuthHeroPanel extends StatelessWidget {
  final bool compact;
  final AuthScale scale;
  const AuthHeroPanel(
      {super.key, this.compact = false, this.scale = AuthScale.regular});

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final logoWidth = compact ? 150.0 : (scale.title * 7.2).clamp(200.0, 320.0);
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.authHeroGradient),
      child: ClipRect(
        child: Stack(
          children: [
            Positioned(
                top: -80,
                left: -60,
                child: _Blob(
                    size: compact ? 200 : 360,
                    color: Colors.white.withValues(alpha: 0.10))),
            Positioned(
                bottom: -100,
                right: -80,
                child: _Blob(
                    size: compact ? 220 : 320,
                    color: Colors.white.withValues(alpha: 0.08))),
            Positioned.fill(
              child: compact
                  ? _compactBanner(logoWidth, dpr)
                  : _fullPanel(context, logoWidth, dpr),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logoPlaque(double logoWidth, double dpr) => Container(
        padding: EdgeInsets.symmetric(
            horizontal: logoWidth * 0.08, vertical: logoWidth * 0.05),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 10)),
          ],
        ),
        child: Image.asset(
          'assets/brand/uniflow-wordmark.png',
          width: logoWidth,
          cacheWidth: (logoWidth * dpr).round(),
          filterQuality: FilterQuality.high,
          fit: BoxFit.contain,
        ),
      );

  Widget _compactBanner(double logoWidth, double dpr) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            _logoPlaque(logoWidth, dpr),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bienvenue sur UniFlow',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.h1
                        .copyWith(color: Colors.white, fontSize: 20),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'La plateforme universitaire qui fonctionne partout, même sans Internet.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: Colors.white.withValues(alpha: 0.88)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _fullPanel(BuildContext context, double logoWidth, double dpr) {
    final pad = scale.padding;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Sous ~620 px de haut, les cartes d'arguments n'ont plus leur place :
        // on les retire plutôt que de faire défiler un panneau décoratif.
        final showFeatures = constraints.maxHeight >= 620;
        // Uni salue au-dessus du logo dès que la hauteur le permet ; sous
        // 560 px il céderait la place au formulaire.
        final showUni = constraints.maxHeight >= 560;
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: pad, vertical: pad * 0.8),
          child: ConstrainedBox(
            constraints:
                BoxConstraints(minHeight: constraints.maxHeight - pad * 1.6),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showUni) ...[
                      Center(
                        child: UniMascot(
                          pose: UniPose.wave,
                          size: (scale.title * 5.2).clamp(110.0, 160.0),
                        ),
                      ),
                      SizedBox(height: pad * 0.4),
                    ],
                    Center(child: _logoPlaque(logoWidth, dpr)),
                    SizedBox(height: pad * 0.7),
                    Text(
                      'Bienvenue sur UniFlow',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.h1.copyWith(
                          color: Colors.white,
                          fontSize: scale.title + 2,
                          height: 1.15),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'La plateforme universitaire intelligente qui fonctionne partout, même sans Internet.',
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: scale.body + 1,
                          height: 1.5,
                          color: const Color(0xFFDBEAFE)),
                    ),
                    if (showFeatures) ...[
                      SizedBox(height: pad * 0.8),
                      for (var i = 0; i < kAuthFeatures.length; i++) ...[
                        CascadeIn(
                            index: 2 + i,
                            child: _FeatureCard(
                                feature: kAuthFeatures[i], scale: scale)),
                        if (i < kAuthFeatures.length - 1)
                          const SizedBox(height: 12),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Carte d'argument translucide (`bg-white/10`, bordure `white/20`), qui se
/// décale de 6 px au survol comme sur le web.
class _FeatureCard extends StatefulWidget {
  final ({IconData icon, String title, String desc, Color color}) feature;
  final AuthScale scale;
  const _FeatureCard({required this.feature, required this.scale});

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.feature;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(_hover ? 6 : 0, 0, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: _hover ? 0.16 : 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(f.icon, size: 22, color: f.color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    f.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: widget.scale.body + 0.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    f.desc,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: widget.scale.body - 1.5,
                        height: 1.4,
                        color: const Color(0xFFDBEAFE)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bouton principal en dégradé bleu → teal. `ElevatedButton` ne sait pas
/// peindre un dégradé, et c'est ce dégradé qui rattache l'écran à la charte.
class GradientButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;
  final IconData? icon;

  const GradientButton({
    super.key,
    required this.label,
    this.isLoading = false,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: disabled ? null : AppColors.logoGradient,
        color: disabled ? AppColors.inputBorder : null,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: disabled
            ? null
            : [
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: 0.30),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          child: SizedBox(
            height: AuthScale.of(context).field,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.4),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 18, color: Colors.white),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.button,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Encadré rouge d'erreur. Un texte rouge isolé se confond avec le formulaire.
class ErrorBanner extends StatelessWidget {
  final String message;
  const ErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return CascadeIn(
      index: 0,
      offset: const Offset(0, -0.1),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, size: 18, color: AppColors.danger),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                  color: kDangerInk,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Choix « Compte universitaire / Compte indépendant », deux cartes.
///
/// Le type de compte décide de tout le reste (cursus ou espace personnel),
/// il vient donc en premier, avant même l'email.
class AccountTypeSelector extends StatelessWidget {
  final AccountType value;
  final ValueChanged<AccountType> onChanged;

  const AccountTypeSelector(
      {super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // Pas de `LayoutBuilder` ici : la colonne du formulaire vit dans un
    // `IntrinsicHeight` (pour égaliser panneau et formulaire), qui ne sait pas
    // mesurer un `LayoutBuilder`. Les deux cartes se partagent la largeur et
    // tronquent leur texte si elle manque.
    return Row(
      children: [
        Expanded(
          child: _TypeCard(
            selected: value == AccountType.university,
            icon: Icons.account_balance_outlined,
            title: 'Universitaire',
            subtitle: 'Rattaché à un établissement',
            onTap: () => onChanged(AccountType.university),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _TypeCard(
            selected: value == AccountType.personal,
            icon: Icons.person_outline,
            title: 'Indépendant',
            subtitle: 'Espace personnel libre',
            onTap: () => onChanged(AccountType.personal),
          ),
        ),
      ],
    );
  }
}

class _TypeCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _TypeCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary50 : AppColors.inputFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primaryBlue : AppColors.inputBorder,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 22,
                color: selected ? AppColors.primaryBlue : AppColors.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? AppColors.primaryBlue
                          : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Liste déroulante habillée comme les champs `AppTextField`.
class AuthDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String hint;

  const AuthDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint = 'Sélectionner',
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color, width: width),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          // `initialValue` est l'API des versions récentes de Flutter ; la
          // valeur est resynchronisée par la clé quand elle change de
          // l'extérieur (réinitialisation en cascade).
          key: ValueKey(value),
          initialValue: value,
          isExpanded: true,
          icon:
              const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          hint: Text(
            hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.inputFill,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            border: border(AppColors.inputBorder),
            enabledBorder: border(AppColors.inputBorder),
            focusedBorder: border(AppColors.primaryBlue, 1.5),
          ),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color;
  const _Blob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(size * 0.4)),
    );
  }
}
