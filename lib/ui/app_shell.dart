import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_destination.dart';
import '../offline/sync_state.dart';
import '../providers/auth_provider.dart';
import '../router/route_guard.dart';
import '../screens/notifications_screen.dart';
import '../screens/session_flow.dart';
import '../theme/app_theme.dart';
import '../utils/avatar.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/uni_icons.dart';
import '../widgets/user_avatar.dart';
import '../widgets/uni/uni_assistant.dart';
import '../widgets/uni/uni_scenes.dart';
import 'form_fields.dart';
import 'motion_in.dart';

/// Coquille de l'application : barre latérale claire repliable à gauche,
/// en-tête (recherche, état de synchronisation, notifications, avatar) et
/// contenu en dessous — l'`AppLayout.tsx` du web.
///
/// La coquille ne décide de rien : [selected] et [onSelect] viennent du
/// propriétaire (la garde de route reste dans `MainShell`).
class AppShell extends ConsumerWidget {
  final AppDestination selected;
  final ValueChanged<AppDestination> onSelect;
  final Widget body;

  const AppShell({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.body,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = UniFlowColors.of(context);
    final sync = ref.watch(syncStateProvider);
    return Scaffold(
      backgroundColor: colors.background,
      body: Row(
        children: [
          AppSidebar(selected: selected, onSelect: onSelect),
          Expanded(
            child: Column(
              children: [
                AppHeader(selected: selected, onSelect: onSelect),
                AnimatedSize(
                  duration: kMotionMedium,
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: sync.isOffline
                      ? OfflineBanner(state: sync)
                      : const SizedBox(width: double.infinity),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      body,
                      // Uni : bouton flottant + panneau ancré, et sa première
                      // apparition par le bord droit (une fois par lancement).
                      const Positioned.fill(child: UniAssistantDock()),
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 90),
                          child: Consumer(
                            builder: (context, ref, _) => UniPeek(
                              id: 'hello-shell',
                              message:
                                  'Salut ! Je suis Uni. Une question sur tes cours ou l’application ? Clique-moi.',
                              onTap: () => ref
                                  .read(uniPanelOpenProvider.notifier)
                                  .state = true,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// En-tête de la coquille. Sous 720 px de largeur de contenu, la recherche
/// se replie en icône : la barre doit tenir dans une fenêtre 800×600 avec la
/// barre latérale en rail.
class AppHeader extends ConsumerStatefulWidget {
  final AppDestination selected;
  final ValueChanged<AppDestination> onSelect;

  const AppHeader({super.key, required this.selected, required this.onSelect});

  static const double height = 64;

  @override
  ConsumerState<AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends ConsumerState<AppHeader> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _searchLink = LayerLink();
  OverlayEntry? _results;
  List<AppDestination> _matches = const [];

  @override
  void dispose() {
    _hideResults();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onQuery(String raw) {
    final query = raw.trim().toLowerCase();
    final role = ref.read(currentRoleProvider);
    final accountType = ref.read(currentAccountTypeProvider);
    final visible = visibleDestinations(role: role, accountType: accountType);
    setState(() {
      _matches = query.isEmpty
          ? const []
          : visible
              .where((d) =>
                  d.label.toLowerCase().contains(query) ||
                  d.section.label.toLowerCase().contains(query))
              .take(6)
              .toList();
    });
    if (_matches.isEmpty) {
      _hideResults();
    } else {
      _showResults();
    }
  }

  void _showResults() {
    _results?.markNeedsBuild();
    if (_results != null) return;
    _results = OverlayEntry(
      builder: (_) => Positioned(
        width: 360,
        child: CompositedTransformFollower(
          link: _searchLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 46),
          child: _SearchResults(
            matches: _matches,
            onPick: (d) {
              _searchController.clear();
              _hideResults();
              _searchFocus.unfocus();
              widget.onSelect(d);
            },
          ),
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_results!);
  }

  void _hideResults() {
    _results?.remove();
    _results = null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = UniFlowColors.of(context);
    final user = ref.watch(currentUserProvider);
    final unread = ref.watch(unreadNotificationsCountProvider);
    final sync = ref.watch(syncStateProvider);

    return Container(
      height: AppHeader.height,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Trois paliers : sous 720 px la recherche se replie en icône ;
          // sous 900, l'état de synchronisation et le nom se réduisent —
          // avec le texte agrandi ×1.3, la rangée débordait de 29 px en
          // 1024×720 (barre latérale dépliée).
          final wide = constraints.maxWidth >= 720;
          final roomy = constraints.maxWidth >= 900;
          final showName = roomy;
          return Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.selected.section.label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          AppTextStyles.overline.copyWith(color: colors.muted),
                    ),
                    Text(
                      widget.selected.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTextStyles.fontFamily,
                        fontSize: AppTextStyles.size16,
                        fontWeight: FontWeight.w700,
                        color: colors.text,
                      ),
                    ),
                  ],
                ),
              ),
              if (wide) ...[
                CompositedTransformTarget(
                  link: _searchLink,
                  child: SizedBox(
                    width: (constraints.maxWidth * 0.32).clamp(200.0, 360.0),
                    child: SearchField(
                      hint: 'Rechercher un écran…',
                      controller: _searchController,
                      focusNode: _searchFocus,
                      onChanged: _onQuery,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
              ],
              SyncIndicator(state: sync, compact: !roomy),
              const SizedBox(width: AppSpacing.sm),
              _HeaderIconButton(
                icon: UniIcons.notifications(UniIconStyle.bold),
                tooltip: 'Notifications',
                badge: unread,
                onTap: () => widget.onSelect(AppDestination.notifications),
              ),
              const SizedBox(width: AppSpacing.md),
              _AvatarMenu(
                name: user?.name ?? '',
                roleLabel: user?.isPlatform == true
                    ? 'Admin plateforme'
                    : ref.watch(currentRoleProvider).label,
                avatarFileId: user?.avatarFileId,
                showName: showName,
                onSelect: widget.onSelect,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  final List<AppDestination> matches;
  final ValueChanged<AppDestination> onPick;
  const _SearchResults({required this.matches, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final colors = UniFlowColors.of(context);
    return MotionIn(
      offset: const Offset(0, -0.1),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppShadows.floating,
        ),
        // Le `Material` porte la couleur : un `ListTile` peint son encre sur
        // le Material le plus proche, une décoration au-dessus la masquerait.
        child: Material(
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(color: colors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final d in matches)
                  ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm)),
                    leading: PhosphorIcon(d.icon(UniIconStyle.bold),
                        size: 18, color: colors.primary),
                    title: Text(d.label,
                        style: TextStyle(
                            fontFamily: AppTextStyles.fontFamily,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: colors.text)),
                    subtitle:
                        Text(d.section.label, style: AppTextStyles.bodySmall),
                    onTap: () => onPick(d),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Indicateur d'état de synchronisation : point coloré + libellé. Compact
/// (point seul, libellé en infobulle) sur une fenêtre étroite.
class SyncIndicator extends StatelessWidget {
  final SyncState state;
  final bool compact;
  const SyncIndicator({super.key, required this.state, this.compact = false});

  Color _color() {
    switch (state.status) {
      case SyncStatus.synced:
        return AppColors.success;
      case SyncStatus.syncing:
        return AppColors.info;
      case SyncStatus.offline:
        return AppColors.warning;
      case SyncStatus.pending:
        return AppColors.warning;
      case SyncStatus.error:
        return AppColors.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = UniFlowColors.of(context);
    final color = _color();
    final dot = state.status == SyncStatus.syncing
        ? SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(strokeWidth: 2, color: color))
        : Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          );
    final child = Container(
      height: 36,
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          dot,
          if (!compact) ...[
            const SizedBox(width: 8),
            Text(
              state.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontSize: AppTextStyles.size12,
                fontWeight: FontWeight.w600,
                color: colors.text,
              ),
            ),
          ],
        ],
      ),
    );
    return Tooltip(
      message: '${state.label} · ${state.lastSyncLabel}',
      child: child,
    );
  }
}

/// Bandeau discret « Mode hors ligne — dernière synchronisation à HH:MM ».
class OfflineBanner extends StatelessWidget {
  final SyncState state;
  const OfflineBanner({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl, vertical: AppSpacing.sm),
      color: const Color(0xFFFEF3C7),
      child: Row(
        children: [
          PhosphorIcon(UniIcons.offline(UniIconStyle.bold),
              size: 16, color: const Color(0xFFB45309)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Mode hors ligne — ${state.lastSyncLabel}'
              '${state.pendingWrites > 0 ? ' · ${state.pendingWrites} modification(s) en attente d\'envoi' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontSize: AppTextStyles.size12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final int badge;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = UniFlowColors.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                    child: PhosphorIcon(icon, size: 21, color: colors.muted)),
                if (badge > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: colors.surface, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          badge > 9 ? '9+' : '$badge',
                          style: const TextStyle(
                            fontFamily: AppTextStyles.fontFamily,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarMenu extends ConsumerWidget {
  final String name;
  final String roleLabel;
  final String? avatarFileId;
  final bool showName;
  final ValueChanged<AppDestination> onSelect;

  const _AvatarMenu({
    required this.name,
    required this.roleLabel,
    required this.avatarFileId,
    required this.showName,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = UniFlowColors.of(context);
    return PopupMenuButton<String>(
      tooltip: 'Compte',
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md)),
      onSelected: (value) async {
        switch (value) {
          case 'settings':
            onSelect(AppDestination.settings);
          case 'notifications':
            onSelect(AppDestination.notifications);
          case 'logout':
            await signOutToLogin(context, ref);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: AppTextStyles.fontFamily,
                      fontWeight: FontWeight.w700,
                      color: colors.text)),
              Text(roleLabel, style: AppTextStyles.bodySmall),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
            value: 'settings',
            child: ListTile(
                dense: true,
                leading: PhosphorIcon(UniIcons.settings(UniIconStyle.bold),
                    size: 18),
                title: const Text('Paramètres'))),
        PopupMenuItem(
            value: 'notifications',
            child: ListTile(
                dense: true,
                leading: PhosphorIcon(UniIcons.notifications(UniIconStyle.bold),
                    size: 18),
                title: const Text('Notifications'))),
        const PopupMenuDivider(),
        PopupMenuItem(
            value: 'logout',
            child: ListTile(
                dense: true,
                leading: PhosphorIcon(UniIcons.signOut(UniIconStyle.bold),
                    size: 18, color: AppColors.danger),
                title: const Text('Se déconnecter',
                    style: TextStyle(color: AppColors.danger)))),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InitialsAvatar(
              initials: initialsOf(name),
              size: 36,
              avatarFileId: avatarFileId,
            ),
            if (showName) ...[
              const SizedBox(width: AppSpacing.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: AppTextStyles.fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: colors.text)),
                    Text(roleLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            AppTextStyles.bodySmall.copyWith(fontSize: 11.5)),
                  ],
                ),
              ),
              PhosphorIcon(UniIcons.chevronDown(UniIconStyle.bold),
                  size: 18, color: colors.muted),
            ],
          ],
        ),
      ),
    );
  }
}
