import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/attendance_provider.dart';
import '../services/conference/attendance_export_service.dart';
import '../services/conference/conference_attendance.dart';
import '../theme/app_theme.dart';
import '../ui/app_button.dart';
import '../ui/app_data_table.dart';
import '../ui/app_dialog.dart';
import '../ui/status_badge.dart';
import '../ui/table_action_icon.dart';
import '../ui/toast.dart';
import '../utils/french_date.dart';
import '../widgets/data_state_view.dart';

/// Panneau « Présence » de la console des conférences.
///
/// Deux parties : la feuille de la réunion en cours, qui se met à jour au fil
/// des arrivées et des départs, et les feuilles des réunions terminées,
/// relues depuis le poste. Chacune s'exporte en PDF ou en classeur.
///
/// Ce widget ne connaît ni le serveur média ni l'API de jonction : il lit les
/// providers de présence, qui reçoivent les événements. Il se teste donc avec
/// un magasin en mémoire et une feuille préremplie.
class AttendancePanel extends ConsumerStatefulWidget {
  const AttendancePanel({super.key});

  @override
  ConsumerState<AttendancePanel> createState() => _AttendancePanelState();
}

class _AttendancePanelState extends ConsumerState<AttendancePanel> {
  /// Fait avancer les durées affichées pendant la réunion : sans lui, la
  /// durée d'un participant connecté ne bougerait qu'au prochain événement.
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _syncTicker(bool live) {
    if (live && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!live && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final live = ref.watch(liveAttendanceProvider);
    final pastAsync = ref.watch(pastAttendancesProvider);
    _syncTicker(live != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (live != null) ...[
          _LiveSheet(
            sheet: live,
            onExport: (format) => _export(live, format),
            onThreshold: (value) => ref
                .read(liveAttendanceProvider.notifier)
                .setPresenceThreshold(value),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Réunions terminées', style: AppTextStyles.h2.copyWith(fontSize: 14)),
          const SizedBox(height: AppSpacing.md),
        ],
        pastAsync.when(
          loading: () => const DataLoadingView(
              label: 'Lecture des feuilles de présence…', compact: true),
          error: (error, _) => DataErrorView(
            title: 'Les feuilles de présence sont illisibles',
            error: error,
            compact: true,
            onRetry: () => ref.invalidate(pastAttendancesProvider),
          ),
          data: (sheets) {
            if (sheets.isEmpty) {
              if (live != null) {
                return Text(
                  'Aucune réunion terminée pour le moment : la feuille de la '
                  'réunion en cours viendra ici à sa clôture.',
                  style: AppTextStyles.body.copyWith(fontSize: 12.5),
                );
              }
              return const DataEmptyView(
                compact: true,
                icon: Icons.fact_check_outlined,
                title: 'Aucune feuille de présence',
                message:
                    'La feuille se remplit d\'elle-même pendant une réunion : '
                    'chaque participant y est noté à son arrivée et à son '
                    'départ, avec sa durée de connexion. Elle reste sur ce '
                    'poste et s\'exporte en PDF ou en classeur, même hors '
                    'ligne.',
              );
            }
            return _PastSheets(
              sheets: sheets,
              onOpen: (sheet) => _showDetails(sheet),
              onExport: _export,
              onDelete: _delete,
            );
          },
        ),
      ],
    );
  }

  Future<void> _export(
      ConferenceAttendance sheet, AttendanceExportFormat format) async {
    final service = ref.read(attendanceExportServiceProvider);
    final File file;
    try {
      file = await service.export(sheet, format);
    } on Object catch (error) {
      if (!mounted) return;
      Toast.error(context, 'Export ${format.label} impossible',
          detail: error.toString());
      return;
    }
    if (!mounted) return;

    final open = await AppDialog.confirm(
      context,
      title: 'Export ${format.label} enregistré',
      message: 'Le fichier est dans vos Documents :\n${file.path}',
      confirmLabel: 'Ouvrir le fichier',
      cancelLabel: 'Fermer',
      icon: Icons.check_circle_outline,
    );
    if (!open || !mounted) return;
    final opened = await service.open(file);
    if (!opened && mounted) {
      Toast.error(context, 'Le fichier n\'a pas pu être ouvert',
          detail: file.path);
    }
  }

  Future<void> _delete(ConferenceAttendance sheet) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Supprimer cette feuille ?',
      message: 'La feuille de présence de « ${sheet.title} » '
          '(${formatShortDate(sheet.startedAt)}) sera effacée de ce poste. '
          'Les exports déjà enregistrés dans vos Documents sont conservés.',
      confirmLabel: 'Supprimer',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await ref.read(attendanceStoreProvider).delete(sheet.conferenceId);
    ref.invalidate(pastAttendancesProvider);
    if (mounted) Toast.success(context, 'Feuille supprimée.');
  }

  Future<void> _showDetails(ConferenceAttendance sheet) {
    final end = sheet.endedAt ?? DateTime.now();
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: sheet.title,
        subtitle: '${sheet.hostName.isEmpty ? 'Hôte inconnu' : sheet.hostName}'
            ' · ${formatShortDateTime(sheet.startedAt)}'
            ' · ${formatDurationFr(sheet.durationAt(end))}',
        icon: Icons.fact_check_outlined,
        maxWidth: 860,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _SummaryLine(sheet: sheet, now: end),
            const SizedBox(height: AppSpacing.md),
            AttendanceTable(sheet: sheet, now: end),
          ],
        ),
        actions: [
          AppButton.secondary(
            label: 'PDF',
            icon: Icons.picture_as_pdf_outlined,
            onPressed: () => _export(sheet, AttendanceExportFormat.pdf),
          ),
          AppButton.secondary(
            label: 'Excel',
            icon: Icons.table_view_outlined,
            onPressed: () => _export(sheet, AttendanceExportFormat.excel),
          ),
          AppButton(
            label: 'Fermer',
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }
}

/// Feuille de la réunion en cours : compteurs, seuil, tableau en direct.
class _LiveSheet extends StatelessWidget {
  final ConferenceAttendance sheet;
  final void Function(AttendanceExportFormat format) onExport;
  final ValueChanged<double> onThreshold;

  const _LiveSheet({
    required this.sheet,
    required this.onExport,
    required this.onThreshold,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final summary = sheet.summaryAt(now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // `Wrap` : badge, compteurs et durée débordaient d'une `Row` sous
        // 600 px de large ; ils passent à la ligne au besoin.
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const StatusBadge(
                label: 'En direct', tone: BadgeTone.success, dot: true),
            Text(
              '${summary.connectedNow} en ligne · ${summary.present} '
              '${summary.present == 1 ? 'présent' : 'présents'} / '
              '${summary.invited} ${summary.invited == 1 ? 'invité' : 'invités'}',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
            ),
            Text(
              'Durée ${formatDurationFr(summary.meetingDuration)}',
              style: const TextStyle(
                  fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _ThresholdPicker(value: sheet.presenceThreshold, onChanged: onThreshold),
            AppButton.secondary(
              label: 'PDF',
              icon: Icons.picture_as_pdf_outlined,
              height: 40,
              onPressed: () => onExport(AttendanceExportFormat.pdf),
            ),
            AppButton.secondary(
              label: 'Excel',
              icon: Icons.table_view_outlined,
              height: 40,
              onPressed: () => onExport(AttendanceExportFormat.excel),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AttendanceTable(
          sheet: sheet,
          now: now,
          emptyLabel: 'En attente des participants : la feuille se remplit à '
              'leur connexion.',
        ),
      ],
    );
  }
}

/// Choix du seuil de présence : la part de la réunion qu'il faut avoir suivie
/// pour être compté présent.
class _ThresholdPicker extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _ThresholdPicker({required this.value, required this.onChanged});

  static const List<double> options = [0.25, 0.5, 0.75];

  @override
  Widget build(BuildContext context) {
    final current = options.contains(value) ? value : null;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.inputBorder, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadius.md),
        color: AppColors.cardWhite,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<double>(
          value: current,
          hint: Text('Seuil ${(value * 100).round()} %',
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
          icon: const Icon(Icons.keyboard_arrow_down,
              size: 18, color: AppColors.textMuted),
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary),
          items: [
            for (final option in options)
              DropdownMenuItem<double>(
                value: option,
                child: Text('Seuil ${(option * 100).round()} %'),
              ),
          ],
          onChanged: (selected) {
            if (selected != null) onChanged(selected);
          },
        ),
      ),
    );
  }
}

/// « Présents 4 · Partiels 3 · Absents 1 · seuil 50 % (55 min) ».
class _SummaryLine extends StatelessWidget {
  final ConferenceAttendance sheet;
  final DateTime now;

  const _SummaryLine({required this.sheet, required this.now});

  @override
  Widget build(BuildContext context) {
    final summary = sheet.summaryAt(now);
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        StatusBadge(label: 'Présents ${summary.present}', tone: BadgeTone.success),
        StatusBadge(label: 'Partiels ${summary.partial}', tone: BadgeTone.warning),
        StatusBadge(label: 'Absents ${summary.absent}', tone: BadgeTone.danger),
        Text(
          'Seuil ${(sheet.presenceThreshold * 100).round()} % '
          '(${formatDurationFr(sheet.requiredPresenceAt(now))})',
          style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// Tableau des participants d'une feuille, à l'instant [now].
class AttendanceTable extends StatelessWidget {
  final ConferenceAttendance sheet;
  final DateTime now;
  final String emptyLabel;

  const AttendanceTable({
    super.key,
    required this.sheet,
    required this.now,
    this.emptyLabel = 'Aucun participant.',
  });

  static BadgeTone toneOf(AttendanceStatus status) => switch (status) {
        AttendanceStatus.present => BadgeTone.success,
        AttendanceStatus.partial => BadgeTone.warning,
        AttendanceStatus.absent => BadgeTone.danger,
      };

  @override
  Widget build(BuildContext context) {
    final entries = sheet.sortedEntries();
    const cell = TextStyle(fontSize: 12.5, color: AppColors.textSecondary);
    return AppDataTable<AttendanceEntry>(
      columns: const [
        AppColumn('Participant', flex: 3),
        AppColumn('Arrivée', width: 72),
        AppColumn('Départ', width: 72),
        AppColumn('Durée', width: 120),
        AppColumn('Statut', width: 112),
      ],
      rows: entries,
      rowHeight: 48,
      minWidth: 620,
      empty: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(emptyLabel,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(fontSize: 12.5)),
      ),
      footer: AppTableFooter(
        label: '${AppTableFooter.count(sheet.invitedCount, 'participant')}'
            ' · ${sheet.connectedCount()} en ligne',
      ),
      cells: (entry, _) {
        final status = sheet.statusOf(entry, now);
        final detail = entry.userId ?? entry.identity;
        return [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              if (detail != entry.label)
                Text(detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
          Text(
            entry.firstJoinedAt == null ? '—' : formatClock(entry.firstJoinedAt!),
            style: cell,
          ),
          Text(
            !entry.hasConnected
                ? '—'
                : entry.isConnected
                    ? 'En ligne'
                    : formatClock(entry.lastLeftAt!),
            style: cell,
          ),
          Text(
            entry.hasConnected
                ? '${formatDurationFr(entry.totalDuration(now))}'
                    '${entry.connectionCount > 1 ? ' · ${entry.connectionCount} conn.' : ''}'
                : '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: cell,
          ),
          StatusBadge(
              label: status.label,
              tone: toneOf(status),
              dot: entry.isConnected),
        ];
      },
    );
  }
}

/// Réunions terminées : une ligne par feuille, avec ses actions.
class _PastSheets extends StatelessWidget {
  final List<ConferenceAttendance> sheets;
  final void Function(ConferenceAttendance sheet) onOpen;
  final void Function(ConferenceAttendance sheet, AttendanceExportFormat format)
      onExport;
  final void Function(ConferenceAttendance sheet) onDelete;

  const _PastSheets({
    required this.sheets,
    required this.onOpen,
    required this.onExport,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    const cell = TextStyle(fontSize: 12.5, color: AppColors.textSecondary);
    return AppDataTable<ConferenceAttendance>(
      columns: [
        const AppColumn('Réunion', flex: 3),
        const AppColumn('Date', width: 118),
        const AppColumn('Durée', width: 86),
        const AppColumn('Présence', width: 150),
        AppColumn('Actions',
            width: TableActionIcon.columnWidth(4), align: TextAlign.right),
      ],
      rows: sheets,
      rowHeight: 52,
      minWidth: 720,
      onRowTap: onOpen,
      footer: AppTableFooter(
        label: AppTableFooter.count(
            sheets.length, 'réunion terminée', 'réunions terminées'),
      ),
      cells: (sheet, _) {
        final end = sheet.endedAt ?? DateTime.now();
        final summary = sheet.summaryAt(end);
        return [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(sheet.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              Text(sheet.hostName.isEmpty ? 'Hôte inconnu' : sheet.hostName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
          Text(formatShortDateTime(sheet.startedAt),
              maxLines: 1, overflow: TextOverflow.ellipsis, style: cell),
          Text(formatDurationFr(sheet.durationAt(end)),
              maxLines: 1, overflow: TextOverflow.ellipsis, style: cell),
          Text(
            '${summary.present} '
            '${summary.present == 1 ? 'présent' : 'présents'} / '
            '${summary.invited} ${summary.invited == 1 ? 'invité' : 'invités'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: cell,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TableActionIcon(
                icon: Icons.visibility_outlined,
                color: AppColors.primaryBlue,
                tooltip: 'Voir la feuille',
                onPressed: () => onOpen(sheet),
              ),
              TableActionIcon(
                icon: Icons.picture_as_pdf_outlined,
                color: AppColors.textSecondary,
                tooltip: 'Exporter en PDF',
                onPressed: () => onExport(sheet, AttendanceExportFormat.pdf),
              ),
              TableActionIcon(
                icon: Icons.table_view_outlined,
                color: AppColors.textSecondary,
                tooltip: 'Exporter en Excel',
                onPressed: () => onExport(sheet, AttendanceExportFormat.excel),
              ),
              TableActionIcon(
                icon: Icons.delete_outline,
                color: AppColors.danger,
                tooltip: 'Supprimer la feuille',
                onPressed: () => onDelete(sheet),
              ),
            ],
          ),
        ];
      },
    );
  }
}
