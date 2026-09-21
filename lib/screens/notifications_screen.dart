import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../repositories/management_repository.dart';
import '../theme/app_theme.dart';
import '../ui/app_button.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/data_state_view.dart';
import '../widgets/motion.dart';
import '../widgets/uni_icons.dart';

/// Notifications du compte connecté (`notifications`, documents du
/// propriétaire, alimentés par la Function `notification-alerts`).
final notificationsProvider =
    FutureProvider<List<AppNotification>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.watch(notificationsApiProvider).listFor(user.id);
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  return ref
          .watch(notificationsProvider)
          .valueOrNull
          ?.where((n) => !n.isRead)
          .length ??
      0;
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadNotificationsCountProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTopBar(
          title: 'Notifications',
          subtitle: unread == 0
              ? 'Tout est lu'
              : '$unread non lue${unread > 1 ? 's' : ''}',
          actions: [
            if (unread > 0)
              AppButton.secondary(
                label: 'Tout marquer comme lu',
                icon: UniIcons.checks(UniIconStyle.bold),
                onPressed: () => _markAll(context, ref),
              ),
          ],
        ),
        Expanded(
          child: notifications.when(
            loading: () =>
                const DataLoadingView(label: 'Chargement des notifications…'),
            error: (e, _) => DataErrorView(
                error: e, onRetry: () => ref.invalidate(notificationsProvider)),
            data: (items) {
              if (items.isEmpty) {
                return DataEmptyView(
                  icon: UniIcons.notifications(),
                  message:
                      'Aucune notification. Les rappels de cours, de devoirs et de séances arriveront ici.',
                );
              }
              return ListView.builder(
                padding: AppSpacing.pageScroll,
                itemCount: items.length,
                itemBuilder: (context, i) => CascadeIn(
                  index: i,
                  child: _NotificationTile(
                    notification: items[i],
                    onToggleRead: () => _toggle(context, ref, items[i]),
                    onDelete: () => _delete(context, ref, items[i]),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _toggle(
      BuildContext context, WidgetRef ref, AppNotification n) async {
    try {
      await ref.read(notificationsApiProvider).markRead(n.id, read: !n.isRead);
      ref.invalidate(notificationsProvider);
    } catch (e) {
      if (context.mounted) {
        showFeedback(context,
            message: 'Mise à jour impossible.', detail: '$e', success: false);
      }
    }
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, AppNotification n) async {
    try {
      await ref.read(notificationsApiProvider).delete(n.id);
      ref.invalidate(notificationsProvider);
      if (context.mounted) {
        showFeedback(context, message: 'Notification supprimée.');
      }
    } catch (e) {
      if (context.mounted) {
        showFeedback(context,
            message: 'Suppression impossible.', detail: '$e', success: false);
      }
    }
  }

  Future<void> _markAll(BuildContext context, WidgetRef ref) async {
    final items = ref.read(notificationsProvider).valueOrNull ??
        const <AppNotification>[];
    final api = ref.read(notificationsApiProvider);
    try {
      await Future.wait(
          [for (final n in items.where((n) => !n.isRead)) api.markRead(n.id)]);
      ref.invalidate(notificationsProvider);
      if (context.mounted) {
        showFeedback(context, message: 'Toutes les notifications sont lues.');
      }
    } catch (e) {
      if (context.mounted) {
        showFeedback(context,
            message: 'Mise à jour incomplète.', detail: '$e', success: false);
      }
    }
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onToggleRead;
  final VoidCallback onDelete;
  const _NotificationTile(
      {required this.notification,
      required this.onToggleRead,
      required this.onDelete});

  IconData get _icon => switch (notification.type.toLowerCase()) {
        final t when t.contains('assignment') || t.contains('devoir') =>
          UniIcons.assignments(),
        final t when t.contains('schedule') || t.contains('cours') =>
          UniIcons.schedule(),
        final t when t.contains('grade') || t.contains('note') =>
          UniIcons.grades(),
        final t when t.contains('attendance') || t.contains('presence') =>
          UniIcons.attendance(),
        final t when t.contains('message') => UniIcons.messaging(),
        _ => UniIcons.notifications(),
      };

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: unread ? AppColors.primary50 : AppColors.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: unread
                ? AppColors.primaryBlue.withValues(alpha: 0.3)
                : AppColors.inputBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(
            icon: _icon,
            color: unread ? AppColors.primaryBlue : AppColors.textSecondary,
            size: 36,
            variant: unread ? IconTileVariant.filled : IconTileVariant.soft,
            semanticLabel: notification.type,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: TextStyle(
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 14),
                ),
                const SizedBox(height: 3),
                Text(notification.message, style: AppTextStyles.body),
                if (notification.createdAt != null) ...[
                  const SizedBox(height: 4),
                  Text(_relative(notification.createdAt!),
                      style: AppTextStyles.bodySmall),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: unread ? 'Marquer comme lu' : 'Marquer comme non lu',
            onPressed: onToggleRead,
            icon: PhosphorIcon(
                unread
                    ? UniIcons.readAll(UniIconStyle.bold)
                    : UniIcons.mail(UniIconStyle.bold),
                size: 19),
          ),
          IconButton(
            tooltip: 'Supprimer',
            onPressed: onDelete,
            icon: PhosphorIcon(UniIcons.delete(UniIconStyle.bold),
                size: 19, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  static String _relative(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inHours < 1) return 'Il y a ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'Il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
