import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_destination.dart';
import '../models/appwrite_models.dart';
import '../providers/auth_provider.dart';
import '../providers/preferences_provider.dart';
import '../screens/session_flow.dart';
import '../router/route_guard.dart';
import '../theme/app_theme.dart';
import '../utils/avatar.dart';
import 'uniflow_logo.dart';
import 'user_avatar.dart';

/// Largeur de fenêtre sous laquelle la barre se replie en rail d'icônes.
///
/// 900 px : en dessous, une barre de 250 px laisserait moins de 650 px au
/// contenu, et les tableaux (étudiants, emploi du temps) débordaient déjà.
const double kSidebarCollapseBreakpoint = 900;

/// Couleurs de la barre latérale selon le thème.
///
/// Les planches (`docs/design/`) imposent une sidebar **claire** : fond blanc,
/// entrée active sur `primary50` avec texte `primaryBlue`. L'ancien dégradé
/// bleu nuit est conservé pour le thème sombre, où un panneau blanc
/// éblouirait à côté du fond `#0B0F19`.
class SidebarPalette {
  final Color background;
  final Color? backgroundDeep;
  final Color border;
  final Color brand;
  final Color text;
  final Color textMuted;
  final Color icon;
  final Color section;
  final Color divider;
  final Color activeBackground;
  final Color activeForeground;
  final Color activeAccent;
  final Color hoverBackground;
  final Color avatarBackground;
  final Color avatarForeground;
  final Color roleBackground;
  final Color roleBorder;
  final Color roleForeground;
  final Color signOut;

  const SidebarPalette({
    required this.background,
    this.backgroundDeep,
    required this.border,
    required this.brand,
    required this.text,
    required this.textMuted,
    required this.icon,
    required this.section,
    required this.divider,
    required this.activeBackground,
    required this.activeForeground,
    required this.activeAccent,
    required this.hoverBackground,
    required this.avatarBackground,
    required this.avatarForeground,
    required this.roleBackground,
    required this.roleBorder,
    required this.roleForeground,
    required this.signOut,
  });

  static const light = SidebarPalette(
    background: AppColors.cardWhite,
    border: AppColors.inputBorder,
    brand: AppColors.primaryBlue,
    text: AppColors.textPrimary,
    textMuted: AppColors.textSecondary,
    icon: AppColors.textSecondary,
    section: AppColors.textMuted,
    divider: AppColors.inputBorder,
    activeBackground: AppColors.primary50,
    activeForeground: AppColors.primaryBlue,
    activeAccent: AppColors.primaryBlue,
    hoverBackground: AppColors.surfaceMuted,
    avatarBackground: AppColors.primary50,
    avatarForeground: AppColors.primaryBlue,
    roleBackground: AppColors.teal50,
    roleBorder: AppColors.teal100,
    roleForeground: AppColors.tealDark,
    signOut: AppColors.textSecondary,
  );

  static const dark = SidebarPalette(
    background: AppColors.sidebarBg,
    backgroundDeep: AppColors.sidebarBgDeep,
    border: Color(0xFF243049),
    brand: Colors.white,
    text: Colors.white,
    textMuted: Color(0xBFFFFFFF),
    icon: Color(0x99FFFFFF),
    section: Color(0x61FFFFFF),
    divider: Color(0x14FFFFFF),
    activeBackground: AppColors.sidebarActive,
    activeForeground: Colors.white,
    activeAccent: Colors.white,
    hoverBackground: Color(0x0FFFFFFF),
    avatarBackground: Color(0xFF2A3352),
    avatarForeground: Colors.white,
    roleBackground: Color(0x2E0D9488),
    roleBorder: Color(0x730D9488),
    roleForeground: AppColors.tealLight,
    signOut: Color(0xB3FFFFFF),
  );

  static SidebarPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  bool get isDark => backgroundDeep != null;

  Decoration get decoration => isDark
      ? BoxDecoration(
          gradient: LinearGradient(
            colors: [background, backgroundDeep!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        )
      : BoxDecoration(
          color: background,
          border: Border(right: BorderSide(color: border)),
        );
}

/// Barre latérale : construite depuis [AppDestination] et la garde de
/// navigation, donc **un utilisateur ne voit que les écrans que son rôle et
/// son type de compte ouvrent**. L'ancienne liste figée (`SidebarItem`)
/// affichait les dix-neuf entrées à tout le monde, un étudiant voyait
/// « Paiements » et « Sentinelle IoT ».
///
/// Elle est animée : repli en rail d'icônes sous [kSidebarCollapseBreakpoint],
/// et entrée en cascade des lignes au premier affichage.
class AppSidebar extends ConsumerStatefulWidget {
  final AppDestination selected;
  final ValueChanged<AppDestination> onSelect;

  /// Force le mode replié (rail), indépendamment de la largeur.
  final bool? collapsed;

  const AppSidebar({
    super.key,
    required this.selected,
    required this.onSelect,
    this.collapsed,
  });

  static const double width = 250;
  static const double railWidth = 72;

  @override
  ConsumerState<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends ConsumerState<AppSidebar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = SidebarPalette.of(context);
    final user = ref.watch(currentUserProvider);
    final role = ref.watch(currentRoleProvider);
    final accountType = ref.watch(currentAccountTypeProvider);
    final grouped = groupedDestinations(role: role, accountType: accountType);
    // Repli : imposé par l'appelant, sinon par la préférence « barre
    // compacte », sinon par la largeur de fenêtre.
    final collapsed = widget.collapsed ??
        (ref.watch(preferencesProvider).compactSidebar ||
            MediaQuery.sizeOf(context).width < kSidebarCollapseBreakpoint);
    final width = collapsed ? AppSidebar.railWidth : AppSidebar.width;

    // Index global de chaque ligne, pour décaler les entrées en cascade.
    var lineIndex = 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      width: width,
      decoration: palette.decoration,
      child: ClipRect(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Brand(collapsed: collapsed, palette: palette),
            _Profile(
              collapsed: collapsed,
              palette: palette,
              user: user,
              roleLabel: role.label,
              roleBadge: user == null
                  ? 'Hors ligne'
                  : (user.isSuperAdmin
                      ? 'Superadmin'
                      : (user.isPersonal ? 'Compte personnel' : role.badge)),
            ),
            const SizedBox(height: AppSpacing.lg),
            Divider(color: palette.divider, height: 1),
            const SizedBox(height: AppSpacing.xs),

            // ----- Menu par sections -----
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: collapsed ? 10 : AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                children: [
                  for (final entry in grouped.entries) ...[
                    if (!collapsed)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            14, AppSpacing.md, AppSpacing.md, 6),
                        child: Text(
                          entry.key.label.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.overline.copyWith(
                            color: palette.section,
                            fontSize: 10.5,
                            letterSpacing: 1.1,
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm, horizontal: 14),
                        child: Divider(color: palette.divider, height: 1),
                      ),
                    for (final destination in entry.value)
                      _Cascade(
                        controller: _entrance,
                        index: lineIndex++,
                        child: _SidebarTile(
                          destination: destination,
                          collapsed: collapsed,
                          palette: palette,
                          isActive: destination == widget.selected,
                          onTap: () => widget.onSelect(destination),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            if (user != null)
              Padding(
                padding: EdgeInsets.fromLTRB(
                    collapsed ? 0 : AppSpacing.md,
                    AppSpacing.xs,
                    collapsed ? 0 : AppSpacing.md,
                    AppSpacing.md),
                child: collapsed
                    ? Center(
                        child: SignOutButton(
                            compact: true, color: palette.signOut))
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: SignOutButton(color: palette.signOut),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Logo et nom du produit, en tête de barre.
class _Brand extends StatelessWidget {
  final bool collapsed;
  final SidebarPalette palette;
  const _Brand({required this.collapsed, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(collapsed ? 0 : AppSpacing.xl,
          AppSpacing.xxl, collapsed ? 0 : AppSpacing.xl, 18),
      child: Row(
        mainAxisAlignment:
            collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          const UniFlowIcon(size: 34),
          if (!collapsed) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'UniFlow',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTextStyles.fontFamily,
                  color: palette.brand,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Avatar, nom, pseudo et pastille de rôle de l'utilisateur connecté.
class _Profile extends StatelessWidget {
  final bool collapsed;
  final SidebarPalette palette;
  final UniFlowUser? user;
  final String roleLabel;
  final String roleBadge;

  const _Profile({
    required this.collapsed,
    required this.palette,
    required this.user,
    required this.roleLabel,
    required this.roleBadge,
  });

  @override
  Widget build(BuildContext context) {
    final user = this.user;
    final username = user?.username;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : AppSpacing.xl),
      child: Row(
        mainAxisAlignment:
            collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Tooltip(
            message: user == null
                ? 'Hors ligne'
                : '${user.name} · $roleLabel'
                    '${user.isSuperAdmin ? ' · superadmin' : ''}',
            child: InitialsAvatar(
              initials: user == null ? '?' : initialsOf(user.name),
              avatarFileId: user?.avatarFileId,
              backgroundColor: palette.avatarBackground,
              textColor: palette.avatarForeground,
              size: 40,
            ),
          ),
          if (!collapsed) ...[
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    user == null ? 'Utilisateur' : user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTextStyles.fontFamily,
                      color: palette.text,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Le pseudo prime : c'est le référent de la messagerie.
                  if (username != null && username.isNotEmpty)
                    Text(
                      '@$username',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTextStyles.fontFamily,
                        color: palette.textMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xs),
                  _RoleBadge(label: roleBadge, palette: palette),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pastille de rôle sous le nom : le propriétaire veut que chacun sache avec
/// quel rôle il est connecté, donc ce qu'il voit et pourquoi.
class _RoleBadge extends StatelessWidget {
  final String label;
  final SidebarPalette palette;
  const _RoleBadge({required this.label, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: palette.roleBackground,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: palette.roleBorder),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          color: palette.roleForeground,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Entrée en cascade : chaque ligne apparaît un peu après la précédente, en
/// glissant depuis la gauche. Le décalage est plafonné pour que la vingtième
/// ligne n'attende pas une seconde.
class _Cascade extends StatelessWidget {
  final AnimationController controller;
  final int index;
  final Widget child;

  const _Cascade({
    required this.controller,
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.045).clamp(0.0, 0.6);
    final curve = CurvedAnimation(
      parent: controller,
      curve: Interval(start, (start + 0.4).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(-0.12, 0), end: Offset.zero)
            .animate(curve),
        child: child,
      ),
    );
  }
}

/// Une ligne cliquable du menu.
///
/// L'état actif est signalé par un fond teinté **et** une barre d'accent
/// verticale à gauche : la seule différence de teinte se lit mal (surtout sur
/// le thème sombre), la barre donne un repère net.
class _SidebarTile extends StatefulWidget {
  final AppDestination destination;
  final bool isActive;
  final bool collapsed;
  final SidebarPalette palette;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.destination,
    required this.isActive,
    required this.collapsed,
    required this.palette,
    required this.onTap,
  });

  @override
  State<_SidebarTile> createState() => _SidebarTileState();
}

class _SidebarTileState extends State<_SidebarTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isActive;
    final collapsed = widget.collapsed;
    final palette = widget.palette;
    final foreground = isActive
        ? palette.activeForeground
        : (_hovered ? palette.text : palette.icon);
    final labelColor = isActive
        ? palette.activeForeground
        : (_hovered ? palette.text : palette.textMuted);

    final tile = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 0 : AppSpacing.md,
              vertical: 11,
            ),
            decoration: BoxDecoration(
              color: isActive
                  ? palette.activeBackground
                  : (_hovered ? palette.hoverBackground : Colors.transparent),
              borderRadius: BorderRadius.circular(10),
              // L'ombre portée n'a de sens que sur le bleu plein du thème
              // sombre ; sur `primary50`, elle salirait le blanc.
              boxShadow: isActive && palette.isDark
                  ? [
                      BoxShadow(
                        color: palette.activeBackground.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: collapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                if (!collapsed) ...[
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 3,
                    height: isActive ? 18 : 6,
                    decoration: BoxDecoration(
                      color:
                          isActive ? palette.activeAccent : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Icon(widget.destination.icon, size: 19, color: foreground),
                if (!collapsed) ...[
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      widget.destination.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTextStyles.fontFamily,
                        fontSize: 13.5,
                        fontWeight:
                            isActive ? FontWeight.w700 : FontWeight.w500,
                        color: labelColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: collapsed
          ? Tooltip(
              message: widget.destination.label,
              preferBelow: false,
              child: tile,
            )
          : tile,
    );
  }
}
