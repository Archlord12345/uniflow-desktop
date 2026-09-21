import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/appwrite_models.dart';
import '../models/attendance_models.dart';
import '../models/student.dart';
import '../models/user_role.dart';
import '../providers/analytics_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/directory_provider.dart';
import '../repositories/management_repository.dart';
import '../services/uniflow_api.dart';
import '../theme/app_theme.dart';
import '../ui/app_button.dart';
import '../ui/app_data_table.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/data_state_view.dart';
import '../widgets/motion.dart';
import 'academic_management_screens.dart' show selectedCourseIdProvider;

/// Présences : séances d'un cours, appel manuel, émission du QR de séance
/// (`/attendance-secure`), liste des émargements et assiduité globale.
///
/// L'émission d'un QR exige la position de la salle : le serveur refuse tout
/// émargement hors d'un rayon autour de l'émetteur, et un poste fixe n'a pas
/// de GPS. Les coordonnées sont donc saisies (et mémorisées pour la session).
class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

final _sessionsProvider =
    FutureProvider.family<List<AttendanceSessionInfo>, String>((ref, courseId) {
  return ref.watch(attendanceApiProvider).sessionsOf(courseId);
});

final _recordsProvider =
    FutureProvider.family<List<AttendanceRecordInfo>, String>((ref, sessionId) {
  return ref.watch(attendanceApiProvider).recordsOf(sessionId);
});

final _selectedSessionProvider = StateProvider<String?>((ref) => null);

/// Hauteur des boutons posés dans une carte, à côté d'un titre `h3` : la
/// hauteur standard (44 px) écrase le titre de la séance ; 38 px reste
/// cliquable à la souris et laisse le titre mener la ligne.
const double _inlineButtonHeight = 38;

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentRoleProvider);
    final canRoll = role == UserRole.teacher ||
        role == UserRole.admin ||
        role == UserRole.delegate;
    final courseId = ref.watch(selectedCourseIdProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTopBar(
          title: 'Présences',
          subtitle: 'Séances, appel, QR d\'émargement et assiduité',
          actions: [
            if (canRoll && courseId != null && _tab == 0)
              AppButton(
                label: 'Faire l\'appel',
                icon: Icons.playlist_add_check_outlined,
                onPressed: () => _newRoll(context, courseId),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 18, 28, 0),
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                      value: 0,
                      icon: Icon(Icons.event_note_outlined, size: 16),
                      label: Text('Séances')),
                  ButtonSegment(
                      value: 1,
                      icon: Icon(Icons.insights_outlined, size: 16),
                      label: Text('Assiduité')),
                ],
                selected: {_tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
              ),
              if (_tab == 0) const _CoursePickerInline(),
            ],
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: kMotionMedium,
            transitionBuilder: pageTransition,
            child: _tab == 0
                ? (courseId == null
                    ? const DataEmptyView(
                        icon: Icons.event_available_outlined,
                        message: 'Aucun cours dans votre périmètre.')
                    : _SessionsView(
                        key: ValueKey(courseId),
                        courseId: courseId,
                        canRoll: canRoll))
                : const _AttendanceStatsView(key: ValueKey('stats')),
          ),
        ),
      ],
    );
  }

  Future<void> _newRoll(BuildContext context, String courseId) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _RollDialog(courseId: courseId),
    );
    if (saved == true) ref.invalidate(_sessionsProvider(courseId));
  }
}

class _CoursePickerInline extends ConsumerWidget {
  const _CoursePickerInline();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(scopedCoursesProvider).valueOrNull ??
        const <AcademicCourse>[];
    final selected = ref.watch(selectedCourseIdProvider);
    final value = courses.any((c) => c.id == selected)
        ? selected
        : (courses.isEmpty ? null : courses.first.id);
    if (value != selected) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => ref.read(selectedCourseIdProvider.notifier).state = value);
    }
    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          items: [
            for (final c in courses)
              DropdownMenuItem(
                  value: c.id,
                  child: Text('${c.code} · ${c.name}',
                      overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) {
            ref.read(selectedCourseIdProvider.notifier).state = v;
            ref.read(_selectedSessionProvider.notifier).state = null;
          },
        ),
      ),
    );
  }
}

class _SessionsView extends ConsumerWidget {
  final String courseId;
  final bool canRoll;
  const _SessionsView(
      {super.key, required this.courseId, required this.canRoll});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(_sessionsProvider(courseId));
    final selectedSession = ref.watch(_selectedSessionProvider);
    return sessions.when(
      loading: () => const DataLoadingView(label: 'Chargement des séances…'),
      error: (e, _) => DataErrorView(
          error: e, onRetry: () => ref.invalidate(_sessionsProvider(courseId))),
      data: (items) {
        if (items.isEmpty) {
          return DataEmptyView(
            icon: Icons.event_note_outlined,
            message: canRoll
                ? 'Aucune séance pour ce cours. « Faire l\'appel » crée la séance du jour.'
                : 'Aucune séance enregistrée pour ce cours.',
          );
        }
        final current = items.any((s) => s.id == selectedSession)
            ? selectedSession!
            : items.first.id;
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final list = _SessionList(
              sessions: items,
              selected: current,
              onSelect: (id) =>
                  ref.read(_selectedSessionProvider.notifier).state = id,
            );
            final detail = _SessionDetail(
              key: ValueKey(current),
              session: items.firstWhere((s) => s.id == current),
              canRoll: canRoll,
            );
            if (wide) {
              return Padding(
                padding: const EdgeInsets.all(28),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 300, child: list),
                    const SizedBox(width: 20),
                    Expanded(child: detail),
                  ],
                ),
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child:
                  Column(children: [list, const SizedBox(height: 20), detail]),
            );
          },
        );
      },
    );
  }
}

class _SessionList extends StatelessWidget {
  final List<AttendanceSessionInfo> sessions;
  final String selected;
  final ValueChanged<String> onSelect;
  const _SessionList(
      {required this.sessions, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text('Séances', style: AppTextStyles.h3),
          ),
          for (var i = 0; i < sessions.length; i++)
            CascadeIn(
              index: i,
              child: ListTile(
                dense: true,
                selected: sessions[i].id == selected,
                selectedTileColor: AppColors.primary50,
                leading: const Icon(Icons.event_outlined, size: 18),
                title: Text(_formatDate(sessions[i].date),
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
                onTap: () => onSelect(sessions[i].id),
              ),
            ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _SessionDetail extends ConsumerWidget {
  final AttendanceSessionInfo session;
  final bool canRoll;
  const _SessionDetail(
      {super.key, required this.session, required this.canRoll});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(_recordsProvider(session.id));
    final directory = ref.watch(directoryProvider).valueOrNull ??
        const <AcademicDirectoryEntry>[];
    final names = {for (final e in directory) e.userId: e.name};

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Séance du ${_formatDate(session.date)}',
                  style: AppTextStyles.h3),
              if (canRoll) ...[
                AppButton.secondary(
                  label: 'Émettre le QR',
                  icon: Icons.qr_code_2,
                  height: _inlineButtonHeight,
                  onPressed: () => _issueQr(context, ref),
                ),
                AppButton.secondary(
                  label: 'Corriger l\'appel',
                  icon: Icons.edit_outlined,
                  height: _inlineButtonHeight,
                  onPressed: () async {
                    final saved = await showDialog<bool>(
                      context: context,
                      builder: (_) => _RollDialog(
                          courseId: session.courseId, date: session.date),
                    );
                    if (saved == true) {
                      ref.invalidate(_recordsProvider(session.id));
                    }
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          records.when(
            loading: () => const DataLoadingView(
                compact: true, label: 'Chargement des émargements…'),
            error: (e, _) => DataErrorView(
                error: e,
                onRetry: () => ref.invalidate(_recordsProvider(session.id))),
            data: (items) {
              if (items.isEmpty) {
                return const DataEmptyView(
                  compact: true,
                  message: 'Aucun émargement pour cette séance.',
                );
              }
              final counts = <String, int>{};
              for (final r in items) {
                counts[r.status] = (counts[r.status] ?? 0) + 1;
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final status in const [
                        'PRESENT',
                        'RETARD',
                        'JUSTIFIE',
                        'ABSENT'
                      ])
                        if ((counts[status] ?? 0) > 0)
                          _StatusChip(status: status, count: counts[status]!),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < items.length; i++)
                    CascadeIn(
                      index: i,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                  names[items[i].studentId] ??
                                      items[i].studentId,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            Text(
                              items[i].verificationMethod == 'QR_GEOFENCE'
                                  ? 'QR'
                                  : 'Manuel',
                              style: AppTextStyles.bodySmall,
                            ),
                            const SizedBox(width: 12),
                            _StatusChip(status: items[i].status),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _issueQr(BuildContext context, WidgetRef ref) async {
    final position = await showDialog<_Origin>(
      context: context,
      builder: (_) => _OriginDialog(initial: ref.read(_lastOriginProvider)),
    );
    if (position == null || !context.mounted) return;
    ref.read(_lastOriginProvider.notifier).state = position;
    try {
      final qr = await ref.read(attendanceApiProvider).issue(
            sessionId: session.id,
            courseId: session.courseId,
            latitude: position.latitude,
            longitude: position.longitude,
            radiusMeters: position.radius,
          );
      if (!context.mounted) return;
      await showDialog<void>(
          context: context, builder: (_) => _QrDialog(qr: qr));
      ref.invalidate(_recordsProvider(session.id));
    } on ApiException catch (e) {
      if (context.mounted) {
        showFeedback(context,
            message: 'QR refusé par le serveur.',
            detail: e.message,
            success: false);
      }
    }
  }
}

class _Origin {
  final double latitude;
  final double longitude;
  final int radius;
  const _Origin(this.latitude, this.longitude, this.radius);
}

final _lastOriginProvider = StateProvider<_Origin?>((ref) => null);

class _OriginDialog extends StatefulWidget {
  final _Origin? initial;
  const _OriginDialog({this.initial});

  @override
  State<_OriginDialog> createState() => _OriginDialogState();
}

class _OriginDialogState extends State<_OriginDialog> {
  late final _lat =
      TextEditingController(text: widget.initial?.latitude.toString() ?? '');
  late final _lon =
      TextEditingController(text: widget.initial?.longitude.toString() ?? '');
  late final _radius =
      TextEditingController(text: (widget.initial?.radius ?? 80).toString());
  String? _error;

  @override
  void dispose() {
    _lat.dispose();
    _lon.dispose();
    _radius.dispose();
    super.dispose();
  }

  void _submit() {
    final lat = double.tryParse(_lat.text.replaceAll(',', '.'));
    final lon = double.tryParse(_lon.text.replaceAll(',', '.'));
    final radius = int.tryParse(_radius.text) ?? 80;
    if (lat == null || lon == null || lat.abs() > 90 || lon.abs() > 180) {
      setState(() =>
          _error = 'Coordonnées invalides (latitude ±90, longitude ±180).');
      return;
    }
    Navigator.pop(context, _Origin(lat, lon, radius.clamp(20, 250)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Position de la salle'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Les étudiants ne peuvent émarger qu\'à proximité de ce point. '
              'Relevez les coordonnées de la salle une fois (carte, téléphone) ; '
              'elles sont mémorisées pour la session.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                    child: TextField(
                        controller: _lat,
                        autofocus: true,
                        decoration:
                            const InputDecoration(labelText: 'Latitude'))),
                const SizedBox(width: 10),
                Expanded(
                    child: TextField(
                        controller: _lon,
                        decoration:
                            const InputDecoration(labelText: 'Longitude'))),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _radius,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Rayon autorisé (m, 20 à 250)'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style:
                      const TextStyle(color: AppColors.danger, fontSize: 12.5)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
        FilledButton(onPressed: _submit, child: const Text('Émettre')),
      ],
    );
  }
}

/// QR affiché en grand, avec le compte à rebours de validité (15 min côté
/// serveur) et la révocation.
class _QrDialog extends ConsumerStatefulWidget {
  final IssuedQr qr;
  const _QrDialog({required this.qr});

  @override
  ConsumerState<_QrDialog> createState() => _QrDialogState();
}

class _QrDialogState extends ConsumerState<_QrDialog> {
  Timer? _timer;
  bool _revoked = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Duration get _remaining {
    final left = widget.qr.expiresAt.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _remaining;
    final expired = remaining == Duration.zero || _revoked;
    final mm = remaining.inMinutes.toString().padLeft(2, '0');
    final ss = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    return AlertDialog(
      title: const Text('QR d\'émargement'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedOpacity(
              duration: kMotionMedium,
              opacity: expired ? 0.25 : 1,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12)),
                child: QrImageView(
                    data: widget.qr.token,
                    size: 260,
                    backgroundColor: Colors.white),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              expired
                  ? (_revoked ? 'QR révoqué' : 'QR expiré')
                  : 'Valide encore $mm:$ss',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: expired ? AppColors.danger : AppColors.tealDark,
              ),
            ),
            const SizedBox(height: 4),
            Text('Rayon autorisé : ${widget.qr.radiusMeters} m',
                style: AppTextStyles.bodySmall),
            const SizedBox(height: 10),
            SelectableText(widget.qr.token,
                style:
                    AppTextStyles.bodySmall.copyWith(fontFamily: 'monospace')),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: widget.qr.token));
            showFeedback(context, message: 'Jeton copié.');
          },
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('Copier le jeton'),
        ),
        if (!expired)
          TextButton(
            onPressed: () async {
              try {
                await ref.read(attendanceApiProvider).revoke(widget.qr.token);
                if (mounted) setState(() => _revoked = true);
              } on ApiException catch (e) {
                if (context.mounted) {
                  showFeedback(context,
                      message: 'Révocation refusée.',
                      detail: e.message,
                      success: false);
                }
              }
            },
            child: const Text('Révoquer',
                style: TextStyle(color: AppColors.danger)),
          ),
        FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer')),
      ],
    );
  }
}

/// Appel manuel : un statut par apprenant inscrit au cours.
class _RollDialog extends ConsumerStatefulWidget {
  final String courseId;
  final DateTime? date;
  const _RollDialog({required this.courseId, this.date});

  @override
  ConsumerState<_RollDialog> createState() => _RollDialogState();
}

class _RollDialogState extends ConsumerState<_RollDialog> {
  late DateTime _date = widget.date ?? DateTime.now();
  final Map<String, String> _status = {};
  bool _busy = false;
  String? _error;

  static const _statuses = ['PRESENT', 'RETARD', 'JUSTIFIE', 'ABSENT'];

  @override
  Widget build(BuildContext context) {
    final students =
        ref.watch(studentsProvider).valueOrNull ?? const <Student>[];
    final enrollments = ref.watch(enrollmentsProvider).valueOrNull ??
        const <AcademicEnrollment>[];
    final enrolledIds = enrollments
        .where((e) => e.courseId == widget.courseId)
        .map((e) => e.studentId)
        .toSet();
    final roster = students.where((s) => enrolledIds.contains(s.id)).toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
    for (final s in roster) {
      _status.putIfAbsent(s.id, () => 'PRESENT');
    }

    return AlertDialog(
      title: Text('Appel du ${_formatDate(_date)}'),
      content: SizedBox(
        width: 520,
        height: 420,
        child: roster.isEmpty
            ? const Center(
                child: DataEmptyView(
                  compact: true,
                  message: 'Aucun apprenant inscrit à ce cours.',
                ),
              )
            : Column(
                children: [
                  Row(
                    children: [
                      if (widget.date == null)
                        TextButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _date,
                              firstDate: DateTime.now()
                                  .subtract(const Duration(days: 180)),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 1)),
                            );
                            if (picked != null) setState(() => _date = picked);
                          },
                          icon: const Icon(Icons.event_outlined, size: 16),
                          label: const Text('Changer la date'),
                        ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(() {
                          for (final s in roster) {
                            _status[s.id] = 'PRESENT';
                          }
                        }),
                        child: const Text('Tous présents'),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: roster.length,
                      itemBuilder: (context, i) {
                        final s = roster[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                  child: Text(s.fullName,
                                      overflow: TextOverflow.ellipsis)),
                              SegmentedButton<String>(
                                showSelectedIcon: false,
                                style: const ButtonStyle(
                                    visualDensity: VisualDensity.compact),
                                segments: [
                                  for (final st in _statuses)
                                    ButtonSegment(
                                        value: st,
                                        label: Text(_shortStatus(st),
                                            style:
                                                const TextStyle(fontSize: 11))),
                                ],
                                selected: {_status[s.id]!},
                                onSelectionChanged: (sel) =>
                                    setState(() => _status[s.id] = sel.first),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_error!,
                          style: const TextStyle(
                              color: AppColors.danger, fontSize: 12.5)),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, false),
            child: const Text('Annuler')),
        FilledButton(
          onPressed: _busy || roster.isEmpty ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Enregistrer l\'appel'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(attendanceApiProvider).roll(
          courseId: widget.courseId, date: _date, statusByStudent: _status);
      if (!mounted) return;
      showFeedback(context,
          message: 'Appel enregistré.', detail: '${_status.length} apprenants');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  static String _shortStatus(String s) => switch (s) {
        'PRESENT' => 'P',
        'RETARD' => 'R',
        'JUSTIFIE' => 'J',
        _ => 'A',
      };
}

class _StatusChip extends StatelessWidget {
  final String status;
  final int? count;
  const _StatusChip({required this.status, this.count});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'PRESENT' => ('Présent', AppColors.success),
      'RETARD' => ('Retard', AppColors.warning),
      'JUSTIFIE' => ('Justifié', AppColors.info),
      _ => ('Absent', AppColors.danger),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999)),
      child: Text(
        count == null ? label : '$label · $count',
        style: TextStyle(
            fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

/// Assiduité globale (agrégats calculés depuis `attendance_records`).
class _AttendanceStatsView extends ConsumerWidget {
  const _AttendanceStatsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(studentAttendanceProvider);
    return stats.when(
      loading: () =>
          const DataLoadingView(label: 'Calcul de l\'assiduité…'),
      error: (e, _) => DataErrorView(
          error: e, onRetry: () => ref.invalidate(studentAttendanceProvider)),
      data: (students) {
        if (students.isEmpty) {
          return const DataEmptyView(
            icon: Icons.insights_outlined,
            message:
                'Aucun émargement enregistré : l\'assiduité se calcule depuis les séances.',
          );
        }
        // Les moins assidus d'abord : c'est eux que l'administration cherche.
        final sorted = [...students]..sort((a, b) => a.rate.compareTo(b.rate));
        return SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: AppDataTable<StudentAttendance>(
            columns: _columns,
            rows: sorted,
            minWidth: 640,
            rowHeight: 44,
            cells: (s, _) => [
              Text(
                s.matricule.isEmpty ? s.name : '${s.name} · ${s.matricule}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
              _count(s.present),
              _count(s.late),
              _count(s.absent),
              Text(
                s.rateLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: s.status == AttendanceStatus.regular
                      ? AppColors.success
                      : AppColors.danger,
                ),
              ),
            ],
            footer: AppTableFooter(
              label: AppTableFooter.count(sorted.length, 'apprenant'),
            ),
          ),
        );
      },
    );
  }

  /// Compteurs alignés à droite pour que les chiffres se lisent en colonne.
  static const List<AppColumn> _columns = [
    AppColumn('Apprenant', flex: 3),
    AppColumn('Présent', width: 80, align: TextAlign.right),
    AppColumn('Retard', width: 80, align: TextAlign.right),
    AppColumn('Absent', width: 80, align: TextAlign.right),
    AppColumn('Taux', width: 90, align: TextAlign.right),
  ];

  static Widget _count(int n) => Text('$n',
      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary));
}

String _formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
