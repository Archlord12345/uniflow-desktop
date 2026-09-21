import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/classroom.dart';
import '../models/reference_models.dart';
import '../models/user_role.dart';
import '../providers/auth_provider.dart';
import '../providers/directory_provider.dart';
import '../repositories/reference_repository.dart';
import '../theme/app_theme.dart';
import '../ui/app_button.dart';
import '../ui/app_data_table.dart';
import '../ui/app_dialog.dart';
import '../ui/status_badge.dart';
import '../ui/table_action_icon.dart';
import '../widgets/app_page_bar.dart';
import '../widgets/data_state_view.dart';
import '../widgets/motion.dart';

/// Page « Salles ».
///
/// Le catalogue vient du référentiel `classrooms` (code, nature, capacité,
/// bâtiment), l'occupation de l'emploi du temps. L'administration crée,
/// modifie et supprime les salles du catalogue ; les autres rôles consultent.
///
/// Ce widget n'a pas de Scaffold propre : il est affiché dans [MainShell].
/// Le tableau est un [AppDataTable] (planche « Salles ») : la version maison
/// avait des marges de 24 px là où les autres tableaux en ont 20 et pas de
/// fond d'en-tête.
class ClassroomsScreen extends ConsumerStatefulWidget {
  const ClassroomsScreen({super.key});

  @override
  ConsumerState<ClassroomsScreen> createState() => _ClassroomsScreenState();
}

class _ClassroomsScreenState extends ConsumerState<ClassroomsScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Classroom> _filtered(List<Classroom> classrooms) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return classrooms;
    return classrooms.where((room) {
      return room.nom.toLowerCase().contains(query) ||
          room.type.toLowerCase().contains(query) ||
          room.batiment.toLowerCase().contains(query);
    }).toList();
  }

  void _refresh() {
    ref.invalidate(academicReferenceProvider);
    ref.invalidate(classroomsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final classroomsAsync = ref.watch(classroomsProvider);
    final isAdmin = ref.watch(currentRoleProvider) == UserRole.admin;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPageBar(
          breadcrumb: const ['Accueil', 'Salles'],
          subtitle: 'Catalogue des salles et occupation par l\'emploi du temps',
          actions: [
            if (isAdmin)
              AppButton(
                label: 'Ajouter une salle',
                icon: Icons.add,
                onPressed: () => _edit(context),
              ),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSearchRow(),
                const SizedBox(height: AppSpacing.lg),
                classroomsAsync.when(
                  loading: () => const DataLoadingView(
                      label: 'Chargement du catalogue des salles…'),
                  error: (error, _) =>
                      DataErrorView(error: error, onRetry: _refresh),
                  data: (classrooms) =>
                      _buildTable(_filtered(classrooms), isAdmin),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Colonnes de la planche « Salles » ; la colonne d'actions n'existe que
  /// pour l'administration, seule à pouvoir modifier le catalogue.
  static List<AppColumn> _columns(bool isAdmin) => [
        const AppColumn('Salle', flex: 3),
        const AppColumn('Capacité', width: 96),
        const AppColumn('Créneaux', width: 96),
        const AppColumn('Nature', flex: 2),
        if (isAdmin)
          AppColumn('Actions',
              width: TableActionIcon.columnWidth(2), align: TextAlign.right),
      ];

  /// Trois colonnes fixes (272 px) plus les gouttières : en dessous, la
  /// colonne « Salle » n'a plus la place de l'icône et du nom (débordement de
  /// 29 px mesuré à 420 px) ; le tableau défile alors horizontalement.
  static const double _minTableWidth = 680;

  Widget _buildTable(List<Classroom> classrooms, bool isAdmin) {
    final query = _searchController.text.trim();
    return AppDataTable<Classroom>(
      columns: _columns(isAdmin),
      rows: classrooms,
      minWidth: _minTableWidth,
      cells: (room, _) => _ClassroomRow.cells(
        room,
        actions: !isAdmin
            ? null
            : room.isCatalogued
                ? _ClassroomRow.actions(
                    onEdit: () => _edit(context, existing: room),
                    onDelete: () => _delete(room),
                  )
                : const SizedBox.shrink(),
      ),
      empty: DataEmptyView(
        icon: Icons.meeting_room_outlined,
        message: query.isEmpty
            ? (isAdmin
                ? 'Aucune salle au catalogue. Ajoutez la première avec « Ajouter une salle ».'
                : 'Aucune salle déclarée ni planifiée.')
            : 'Aucune salle ne correspond à « $query ».',
      ),
      footer: AppTableFooter(
        label: AppTableFooter.count(classrooms.length, 'salle'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh, size: 18),
            color: AppColors.textSecondary,
            tooltip: 'Recharger depuis Appwrite',
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, {Classroom? existing}) async {
    final reference = ref.read(academicReferenceProvider).valueOrNull;
    final current = existing == null
        ? null
        : reference?.classrooms
            .where((c) => c.id == existing.referenceId)
            .firstOrNull;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _ClassroomEditorDialog(existing: current, reference: reference),
    );
    if (saved == true) _refresh();
  }

  Future<void> _delete(Classroom room) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Retirer cette salle du catalogue ?',
      message: '« ${room.nom} » ne sera plus proposée dans les formulaires. '
          'Les créneaux déjà planifiés qui la citent sont conservés.',
      confirmLabel: 'Retirer',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref
          .read(referenceRepositoryProvider)
          .deleteClassroom(room.referenceId);
      if (mounted) showFeedback(context, message: 'Salle retirée.');
      _refresh();
    } on AppwriteException catch (e) {
      if (mounted) {
        showFeedback(context,
            message: 'Suppression refusée.',
            detail: _permissionHint(e),
            success: false);
      }
    }
  }

  Widget _buildSearchRow() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Rechercher une salle, un bâtiment...',
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        prefixIcon:
            const Icon(Icons.search, size: 20, color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.cardWhite,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.inputBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.inputBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppColors.primaryBlue, width: 1.5)),
      ),
    );
  }
}

/// Le schéma n'ouvre `classrooms` qu'en lecture au niveau collection : une
/// écriture refusée (401) est signalée comme telle, pas comme une panne.
String _permissionHint(AppwriteException e) {
  if (e.code == 401) {
    return 'Appwrite refuse l\'écriture sur « classrooms » : la collection doit '
        'accorder create("users") avec sécurité par document, ou passer par un '
        'service de la Function. À signaler au propriétaire du schéma.';
  }
  return e.message ?? 'Erreur Appwrite (${e.code}).';
}

/// Cellules d'une ligne du tableau des salles, dans l'ordre de
/// `_ClassroomsScreenState._columns`. [actions] vaut `null` hors
/// administration (la colonne n'existe pas) et un espace vide pour une salle
/// hors catalogue, qu'on ne peut ni modifier ni retirer.
abstract final class _ClassroomRow {
  static const _muted = TextStyle(fontSize: 13, color: AppColors.textSecondary);

  static List<Widget> cells(Classroom classroom, {required Widget? actions}) {
    return [
      Row(
        children: [
          Icon(
            classroom.isCatalogued
                ? Icons.meeting_room_outlined
                : Icons.help_outline,
            size: 18,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  classroom.nom,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  classroom.batiment.isNotEmpty
                      ? classroom.batiment
                      : (classroom.isCatalogued
                          ? 'Bâtiment non renseigné'
                          : 'Hors catalogue (emploi du temps)'),
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      Text(
        classroom.capacite > 0 ? '${classroom.capacite} places' : '—',
        style: _muted,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      Text(
        '${classroom.creneaux} · ${classroom.cours} UE',
        style: _muted,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      classroom.type.isEmpty
          ? const Text('—',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted))
          : StatusBadge(label: classroom.type),
      if (actions != null) actions,
    ];
  }

  static Widget actions(
      {required VoidCallback onEdit, required VoidCallback onDelete}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TableActionIcon(
          icon: Icons.edit_outlined,
          color: AppColors.warning,
          tooltip: 'Modifier',
          onPressed: onEdit,
        ),
        TableActionIcon(
          icon: Icons.delete_outline,
          color: AppColors.danger,
          tooltip: 'Retirer',
          onPressed: onDelete,
        ),
      ],
    );
  }
}

class _ClassroomEditorDialog extends ConsumerStatefulWidget {
  final ClassroomRef? existing;
  final AcademicReference? reference;
  const _ClassroomEditorDialog({this.existing, this.reference});

  @override
  ConsumerState<_ClassroomEditorDialog> createState() =>
      _ClassroomEditorDialogState();
}

class _ClassroomEditorDialogState
    extends ConsumerState<_ClassroomEditorDialog> {
  late final _code = TextEditingController(text: widget.existing?.code ?? '');
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _building =
      TextEditingController(text: widget.existing?.building ?? '');
  late final _capacity = TextEditingController(
      text: widget.existing == null ? '' : '${widget.existing!.capacity}');
  late String _kind = widget.existing?.kind ?? 'SALLE';
  late String? _university = widget.existing?.universityCode ??
      (widget.reference?.universities.length == 1
          ? widget.reference!.universities.first.code
          : null);
  late String? _faculty = (widget.existing?.facultyCode ?? '').isEmpty
      ? null
      : widget.existing!.facultyCode;
  bool _busy = false;
  String? _error;

  static const _kinds = ['AMPHI', 'SALLE', 'LABO', 'TD', 'BUREAU'];

  @override
  void dispose() {
    for (final c in [_code, _name, _building, _capacity]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final universityCode =
        _university ?? ref.read(currentUserProvider)?.university ?? '';
    if (_code.text.trim().isEmpty || universityCode.isEmpty) {
      setState(
          () => _error = 'Le code de la salle et l\'université sont requis.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final room = ClassroomRef(
      id: widget.existing?.id ?? '',
      universityCode: universityCode,
      facultyCode: _faculty ?? '',
      code: _code.text.trim().toUpperCase(),
      name: _name.text.trim(),
      kind: _kind,
      capacity: int.tryParse(_capacity.text.trim()) ?? 0,
      building: _building.text.trim(),
    );
    try {
      final repo = ref.read(referenceRepositoryProvider);
      if (widget.existing == null) {
        await repo.createClassroom(room);
      } else {
        await repo.updateClassroom(room);
      }
      if (!mounted) return;
      showFeedback(context,
          message: widget.existing == null
              ? 'Salle ajoutée.'
              : 'Salle mise à jour.');
      Navigator.pop(context, true);
    } on AppwriteException catch (e) {
      setState(() {
        _busy = false;
        _error = _permissionHint(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reference = widget.reference;
    final universities =
        reference?.universities.where((u) => u.active).toList() ??
            const <University>[];
    final faculties = _university == null
        ? const <Faculty>[]
        : (reference?.facultiesOf(_university!) ?? const <Faculty>[]);
    return AlertDialog(
      title: Text(
          widget.existing == null ? 'Ajouter une salle' : 'Modifier la salle'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (universities.length > 1) ...[
                DropdownButtonFormField<String>(
                  initialValue: _university,
                  decoration: const InputDecoration(labelText: 'Université'),
                  items: [
                    for (final u in universities)
                      DropdownMenuItem(
                          value: u.code,
                          child: Text(u.displayName,
                              overflow: TextOverflow.ellipsis))
                  ],
                  onChanged: (v) => setState(() {
                    _university = v;
                    _faculty = null;
                  }),
                ),
                const SizedBox(height: 12),
              ],
              if (faculties.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  key: ValueKey('faculty-$_university'),
                  initialValue: faculties.any((f) => f.code == _faculty)
                      ? _faculty
                      : null,
                  decoration:
                      const InputDecoration(labelText: 'Faculté (facultatif)'),
                  items: [
                    for (final f in faculties)
                      DropdownMenuItem(
                          value: f.code,
                          child: Text(f.name, overflow: TextOverflow.ellipsis))
                  ],
                  onChanged: (v) => setState(() => _faculty = v),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                      child: TextField(
                          controller: _code,
                          autofocus: true,
                          decoration: const InputDecoration(
                              labelText: 'Code (ex. A101)'))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _kinds.contains(_kind) ? _kind : 'SALLE',
                      decoration: const InputDecoration(labelText: 'Nature'),
                      items: [
                        for (final k in _kinds)
                          DropdownMenuItem(value: k, child: Text(k))
                      ],
                      onChanged: (v) => setState(() => _kind = v ?? 'SALLE'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: _name,
                  decoration:
                      const InputDecoration(labelText: 'Nom (facultatif)')),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: TextField(
                          controller: _building,
                          decoration:
                              const InputDecoration(labelText: 'Bâtiment'))),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 130,
                    child: TextField(
                        controller: _capacity,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Capacité')),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: const TextStyle(
                        color: AppColors.danger, fontSize: 12.5)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        AppButton.secondary(
            label: 'Annuler',
            onPressed: _busy ? null : () => Navigator.pop(context, false)),
        AppButton(
          label: widget.existing == null ? 'Ajouter' : 'Enregistrer',
          loading: _busy,
          onPressed: _busy ? null : _save,
        ),
      ],
    );
  }
}
