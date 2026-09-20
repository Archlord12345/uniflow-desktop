import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_destination.dart';
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
      decoration: const BoxDecoration(gradient: AppColors.sidebarGradient),
      child: ClipRect(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ----- En-tête : logo -----
            Padding(
              padding: EdgeInsets.fromLTRB(collapsed ? 0 : 20, 24, collapsed ? 0 : 20, 18),
              child: Row(
                mainAxisAlignment:
                    collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  const UniFlowIcon(size: 34),
                  if (!collapsed) ...[
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'UniFlow',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ----- Profil -----
            Padding(
              padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 20),
              child: Row(
                mainAxisAlignment:
                    collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  Tooltip(
                    message: user == null
                        ? 'Hors ligne'
                        : '${user.name} · ${role.label}'
                            '${user.isSuperAdmin ? ' · superadmin' : ''}',
                    child: InitialsAvatar(
                      initials: user == null ? '?' : initialsOf(user.name),
                      avatarFileId: user?.avatarFileId,
                      backgroundColor: const Color(0xFF2A3352),
                      textColor: Colors.white,
                      size: 40,
                    ),
                  ),
                  if (!collapsed) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            user == null ? 'Utilisateur' : user.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // Le pseudo prime : c'est le référent de la messagerie.
                          if (user?.username != null && user!.username!.isNotEmpty)
                            Text(
                              '@${user.username}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: 11.5,
                              ),
                            ),
                          const SizedBox(height: 4),
                          _RoleBadge(
                            label: user == null
                                ? 'Hors ligne'
                                : (user.isSuperAdmin
                                    ? 'Superadmin'
                                    : (user.isPersonal
                                        ? 'Compte personnel'
                                        : role.badge)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
            const SizedBox(height: 6),

            // ----- Menu par sections -----
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: collapsed ? 10 : 12,
                  vertical: 8,
                ),
                children: [
                  for (final entry in grouped.entries) ...[
                    if (!collapsed)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 12, 6),
                        child: Text(
                          entry.key.label.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.38),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                        child: Divider(
                          color: Colors.white.withValues(alpha: 0.08),
                          height: 1,
                        ),
                      ),
                    for (final destination in entry.value)
                      _Cascade(
                        controller: _entrance,
                        index: lineIndex++,
                        child: _SidebarTile(
                          destination: destination,
                          collapsed: collapsed,
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
                padding: EdgeInsets.fromLTRB(collapsed ? 0 : 12, 4, collapsed ? 0 : 12, 12),
                child: collapsed
                    ? Center(child: SignOutButton(compact: true, color: Colors.white.withValues(alpha: 0.7)))
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: SignOutButton(color: Colors.white.withValues(alpha: 0.7)),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Pastille de rôle sous le nom : le propriétaire veut que chacun sache avec
/// quel rôle il est connecté, donc ce qu'il voit et pourquoi.
class _RoleBadge extends StatelessWidget {
  final String label;
  const _RoleBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.tealLight,
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
      curve: Interval(start, (start + 0.4).clamp(0.0, 1.0), curve: Curves.easeOutCubic),
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
/// L'état actif est signalé par un fond bleu plein **et** une barre d'accent
/// verticale à gauche : sur un fond bleu nuit, la seule différence de teinte
/// se lit mal, la barre donne un repère net.
class _SidebarTile extends StatefulWidget {
  final AppDestination destination;
  final bool isActive;
  final bool collapsed;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.destination,
    required this.isActive,
    required this.collapsed,
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
    final highlighted = isActive || _hovered;

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
              horizontal: collapsed ? 0 : 12,
              vertical: 11,
            ),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.sidebarActive
                  : (_hovered
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(10),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AppColors.sidebarActive.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment:
                  collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                if (!collapsed) ...[
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 3,
                    height: isActive ? 18 : 6,
                    decoration: BoxDecoration(
                      color: isActive ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Icon(
                  widget.destination.icon,
                  size: 19,
                  color: highlighted
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.6),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.destination.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                        color: highlighted
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.75),
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
