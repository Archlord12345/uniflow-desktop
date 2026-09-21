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
import '../widgets/app_page_bar.dart';
import '../widgets/data_state_view.dart';
import '../widgets/motion.dart';
import '../ui/status_badge.dart';

/// Page « Salles ».
///
/// Le catalogue vient du référentiel `classrooms` (code, nature, capacité,
/// bâtiment), l'occupation de l'emploi du temps. L'administration crée,
/// modifie et supprime les salles du catalogue ; les autres rôles consultent.
///
/// Ce widget n'a pas de Scaffold propre : il est affiché dans [MainShell].
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
              ElevatedButton.icon(
                onPressed: () => _edit(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ajouter une salle'),
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14)),
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
                const SizedBox(height: 18),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.inputBorder),
                  ),
                  child: classroomsAsync.when(
                    loading: () => const Padding(
                        padding: EdgeInsets.all(20),
                        child: TableSkeleton(rows: 5)),
                    error: (error, _) =>
                        DataErrorView(error: error, onRetry: _refresh),
                    data: (classrooms) =>
                        _buildTable(_filtered(classrooms), isAdmin),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTable(List<Classroom> classrooms, bool isAdmin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTableHeader(isAdmin),
        if (classrooms.isEmpty)
          DataEmptyView(
            icon: Icons.meeting_room_outlined,
            message: _searchController.text.trim().isEmpty
                ? (isAdmin
                    ? 'Aucune salle au catalogue. Ajoutez la première avec « Ajouter une salle ».'
                    : 'Aucune salle déclarée ni planifiée.')
                : 'Aucune salle ne correspond à « ${_searchController.text.trim()} ».',
          )
        else
          for (var i = 0; i < classrooms.length; i++)
            CascadeIn(
              index: i,
              child: _ClassroomRow(
                classroom: classrooms[i],
                canEdit: isAdmin && classrooms[i].isCatalogued,
                onEdit: () => _edit(context, existing: classrooms[i]),
                onDelete: () => _delete(classrooms[i]),
              ),
            ),
        _buildFooter(classrooms),
      ],
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Retirer cette salle du catalogue ?'),
        content:
            Text('« ${room.nom} » ne sera plus proposée dans les formulaires. '
                'Les créneaux déjà planifiés qui la citent sont conservés.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
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

  Widget _buildTableHeader(bool isAdmin) {
    const style = TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: 0.3);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.inputBorder))),
      child: Row(
        children: [
          const Expanded(flex: 3, child: Text('SALLE', style: style)),
          const SizedBox(width: 96, child: Text('CAPACITÉ', style: style)),
          const SizedBox(width: 96, child: Text('CRÉNEAUX', style: style)),
          const Expanded(flex: 2, child: Text('NATURE', style: style)),
          if (isAdmin) const SizedBox(width: 88),
        ],
      ),
    );
  }

  Widget _buildFooter(List<Classroom> classrooms) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Text(
            classrooms.length <= 1
                ? '${classrooms.length} salle'
                : '${classrooms.length} salles',
            style: AppTextStyles.body.copyWith(fontSize: 13),
          ),
          const Spacer(),
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

class _ClassroomRow extends StatelessWidget {
  final Classroom classroom;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ClassroomRow({
    required this.classroom,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.inputBorder))),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Icon(
                  classroom.isCatalogued
                      ? Icons.meeting_room_outlined
                      : Icons.help_outline,
                  size: 18,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        classroom.nom,
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary),
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
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 96,
            child: Text(
              classroom.capacite > 0 ? '${classroom.capacite} places' : '—',
              style:
                  const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          SizedBox(
            width: 96,
            child: Text(
              '${classroom.creneaux} · ${classroom.cours} UE',
              style:
                  const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: classroom.type.isEmpty
                  ? const Text('—',
                      style:
                          TextStyle(fontSize: 13, color: AppColors.textMuted))
                  : StatusBadge(label: classroom.type),
            ),
          ),
          if (canEdit)
            SizedBox(
              width: 88,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                      tooltip: 'Modifier',
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18)),
                  IconButton(
                      tooltip: 'Retirer',
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: AppColors.textMuted)),
                ],
              ),
            ),
        ],
      ),
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
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, false),
            child: const Text('Annuler')),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(widget.existing == null ? 'Ajouter' : 'Enregistrer'),
        ),
      ],
    );
  }
}
