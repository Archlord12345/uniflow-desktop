import 'package:flutter/material.dart';

import '../models/user_role.dart';
import '../theme/app_theme.dart';
import 'motion.dart';
import 'uniflow_logo.dart';

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

/// Au-dessous de cette largeur, l'image passe au-dessus du formulaire.
const double kAuthSideBySideBreakpoint = 760;

/// Au-dessus de cette largeur, la colonne du formulaire s'élargit.
const double kAuthWideBreakpoint = 1040;

class AuthShell extends StatelessWidget {
  final Widget form;

  /// Largeur de la colonne du formulaire en disposition large. L'inscription
  /// a plus de champs que la connexion, elle demande une colonne plus large.
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
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.meshGradient),
        child: Stack(
          children: [
            Positioned(
              top: -140,
              left: -120,
              child: _Blob(size: 320, color: AppColors.primaryBlue.withValues(alpha: 0.10)),
            ),
            Positioned(
              bottom: -160,
              right: -130,
              child: _Blob(size: 340, color: AppColors.teal.withValues(alpha: 0.12)),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final sideBySide = width >= kAuthSideBySideBreakpoint;
                  final isWide = width >= kAuthWideBreakpoint;
                  final padding = sideBySide ? 32.0 : 16.0;

                  return SingleChildScrollView(
                    padding: EdgeInsets.all(padding),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight - padding * 2),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1080),
                          child: CascadeIn(
                            index: 0,
                            offset: const Offset(0, 0.03),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.cardWhite,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: AppColors.inputBorder),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryBlue.withValues(alpha: 0.13),
                                    blurRadius: 48,
                                    offset: const Offset(0, 20),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: Material(
                                  type: MaterialType.transparency,
                                  child: sideBySide
                                      ? _wide(isWide)
                                      : _narrow(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wide(bool isWide) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Expanded(child: AuthHeroPanel()),
          SizedBox(
            width: isWide ? formWidthWide : formWidth,
            child: ColoredBox(
              color: AppColors.cardWhite,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isWide ? 44 : 32, vertical: 40),
                child: form,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _narrow() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 180, width: double.infinity, child: AuthHeroPanel(compact: true)),
        ColoredBox(
          color: AppColors.cardWhite,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 30),
            child: form,
          ),
        ),
      ],
    );
  }
}

/// Panneau visuel : photo de campus, voile dégradé bleu → teal, message.
class AuthHeroPanel extends StatelessWidget {
  final bool compact;
  const AuthHeroPanel({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: Image.asset('assets/images/login.jpg', fit: BoxFit.cover)),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryBlue.withValues(alpha: 0.88),
                  AppColors.deepBlue.withValues(alpha: 0.82),
                  AppColors.teal.withValues(alpha: 0.78),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: compact ? 20 : 36, vertical: compact ? 16 : 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                UniFlowLogo(
                  iconSize: compact ? 40 : 54,
                  fontSize: compact ? 24 : 30,
                  textColor: Colors.white,
                ),
                SizedBox(height: compact ? 8 : 18),
                Text(
                  'Bienvenue sur UniFlow',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h1.copyWith(color: Colors.white, fontSize: compact ? 21 : 27),
                ),
                const SizedBox(height: 6),
                Text(
                  'La plateforme académique de référence',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: compact ? 12.5 : 14,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 30),
                  const _HeroPoint(
                    icon: Icons.school_outlined,
                    text: 'Étudiants, enseignants et programmes au même endroit',
                  ),
                  const SizedBox(height: 12),
                  const _HeroPoint(
                    icon: Icons.calendar_today_outlined,
                    text: 'Emplois du temps et présences en temps réel',
                  ),
                  const SizedBox(height: 12),
                  const _HeroPoint(
                    icon: Icons.videocam_outlined,
                    text: 'Visioconférence hébergée sur le poste, même sans internet',
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
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
            height: 52,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
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

  const AccountTypeSelector({super.key, required this.value, required this.onChanged});

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
            Icon(icon, size: 22, color: selected ? AppColors.primaryBlue : AppColors.textMuted),
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
                      color: selected ? AppColors.primaryBlue : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
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
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
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
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
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

class _HeroPoint extends StatelessWidget {
  final IconData icon;
  final String text;
  const _HeroPoint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              text,
              style: TextStyle(fontSize: 13, height: 1.35, color: Colors.white.withValues(alpha: 0.9)),
            ),
          ),
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
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(size * 0.4)),
    );
  }
}
