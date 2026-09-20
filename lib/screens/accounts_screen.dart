import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_role.dart';
import '../providers/auth_provider.dart';
import '../repositories/management_repository.dart';
import '../repositories/reference_repository.dart';
import '../services/uniflow_api.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/data_state_view.dart';
import '../widgets/motion.dart';
import '../widgets/program_filter.dart';

/// Gestion des comptes universitaires par l'administration.
///
/// Toute écriture passe par `/admin-directory` : la Function pose le rôle sur
/// les labels Appwrite (clé serveur) et refait la matrice de droits. Côté
/// desktop, on n'affiche que ce que l'appelant a le droit de faire : les rôles
/// TEACHER / DELEGATE / STUDENT pour une administration, ADMIN en plus pour le
/// `superadmin`.
class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  String? _program;
  String? _level;
  String _search = '';

  ({String? program, String? level}) get _filter =>
      (program: _program, level: _level);

  Future<void> _refresh() async {
    ref.invalidate(managedAccountsProvider(_filter));
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(managedAccountsProvider(_filter));
    final isSuperAdmin = ref.watch(isSuperAdminProvider);
    final user = ref.watch(currentUserProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTopBar(
          title: 'Comptes',
          subtitle: isSuperAdmin
              ? 'Administrateur de la plateforme : tous les établissements'
              : 'Comptes de ${user?.university ?? 'votre établissement'}',
          actions: [
            FilledButton.icon(
              onPressed: () => _openEditor(context),
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
              label: const Text('Créer un compte'),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 18, 28, 0),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  onChanged: (v) =>
                      setState(() => _search = v.trim().toLowerCase()),
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search, size: 18),
                    hintText: 'Nom, email ou matricule',
                  ),
                ),
              ),
              ProgramFilter(
                program: _program,
                level: _level,
                onProgramChanged: (v) => setState(() {
                  _program = v;
                  _level = null;
                }),
                onLevelChanged: (v) => setState(() => _level = v),
              ),
              IconButton(
                  tooltip: 'Actualiser',
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh)),
            ],
          ),
        ),
        Expanded(
          child: accounts.when(
            loading: () => const Padding(
                padding: EdgeInsets.all(28), child: TableSkeleton(rows: 8)),
            error: (error, _) => DataErrorView(error: error, onRetry: _refresh),
            data: (items) {
              final filtered = items.where((a) {
                if (_search.isEmpty) return true;
                return a.name.toLowerCase().contains(_search) ||
                    a.email.toLowerCase().contains(_search) ||
                    a.matricule.toLowerCase().contains(_search);
              }).toList()
                ..sort((a, b) => a.name.compareTo(b.name));
              if (filtered.isEmpty) {
                return const DataEmptyView(
                  icon: Icons.manage_accounts_outlined,
                  message: 'Aucun compte ne correspond à ce filtre.',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(28),
                itemCount: filtered.length,
                itemBuilder: (context, i) => CascadeIn(
                  index: i,
                  child: _AccountTile(
                    account: filtered[i],
                    canEdit: isSuperAdmin || filtered[i].role != 'ADMIN',
                    onEdit: () => _openEditor(context, existing: filtered[i]),
                    onDelete: () => _delete(filtered[i]),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _openEditor(BuildContext context,
      {ManagedAccount? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _AccountEditorDialog(existing: existing),
    );
    if (saved == true) _refresh();
  }

  Future<void> _delete(ManagedAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce compte ?'),
        content: Text(
          '${account.name} (${account.email}) sera supprimé d\'Appwrite. '
          'Un compte qui porte des notes ou des présences est refusé par le serveur : '
          'passez-le alors en SUSPENDED.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(adminDirectoryApiProvider).delete(account.userId);
      if (mounted) showFeedback(context, message: 'Compte supprimé.');
      _refresh();
    } on ApiException catch (e) {
      if (mounted) {
        showFeedback(context,
            message: 'Suppression refusée.', detail: e.message, success: false);
      }
    } catch (e) {
      if (mounted) {
        showFeedback(context,
            message: 'Suppression impossible.', detail: '$e', success: false);
      }
    }
  }
}

class _AccountTile extends StatelessWidget {
  final ManagedAccount account;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AccountTile({
    required this.account,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final role = parseUserRole(account.role);
    final suspended = account.status != 'ACTIVE';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary50,
            child: Text(
              account.name.isEmpty
                  ? '?'
                  : account.name.characters.first.toUpperCase(),
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.primaryBlue),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        account.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Badge(text: role.label, color: AppColors.primaryBlue),
                    if (account.isSuperAdmin) ...[
                      const SizedBox(width: 6),
                      const _Badge(
                          text: 'Superadmin', color: AppColors.tealDark),
                    ],
                    if (suspended) ...[
                      const SizedBox(width: 6),
                      _Badge(text: account.status, color: AppColors.danger),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    account.email,
                    if (account.matricule.isNotEmpty) account.matricule,
                    if (account.program.isNotEmpty)
                      '${account.program}${account.level.isNotEmpty ? ' · ${account.level}' : ''}',
                    if (account.university.isNotEmpty) account.university,
                  ].join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          if (canEdit) ...[
            IconButton(
                tooltip: 'Modifier',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 19)),
            IconButton(
              tooltip: 'Supprimer',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline,
                  size: 19, color: AppColors.textMuted),
            ),
          ] else
            const Tooltip(
              message: 'Réservé à l\'administrateur de la plateforme',
              child: Icon(Icons.lock_outline,
                  size: 18, color: AppColors.textMuted),
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      );
}

/// Formulaire de création / modification d'un compte.
class _AccountEditorDialog extends ConsumerStatefulWidget {
  final ManagedAccount? existing;
  const _AccountEditorDialog({this.existing});

  @override
  ConsumerState<_AccountEditorDialog> createState() =>
      _AccountEditorDialogState();
}

class _AccountEditorDialogState extends ConsumerState<_AccountEditorDialog> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _email = TextEditingController(text: widget.existing?.email ?? '');
  late final _matricule =
      TextEditingController(text: widget.existing?.matricule ?? '');
  late final _university =
      TextEditingController(text: widget.existing?.university ?? '');
  final _password = TextEditingController();

  late String _role = widget.existing?.role ?? 'STUDENT';
  late String? _program = (widget.existing?.program ?? '').isEmpty
      ? null
      : widget.existing!.program;
  late String? _level =
      (widget.existing?.level ?? '').isEmpty ? null : widget.existing!.level;
  late String _status = widget.existing?.status ?? 'ACTIVE';
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.existing != null;
  bool get _isLearner => _role == 'STUDENT' || _role == 'DELEGATE';

  @override
  void dispose() {
    for (final c in [_name, _email, _matricule, _university, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || !_email.text.contains('@')) {
      setState(() => _error = 'Nom et email valides requis.');
      return;
    }
    if (!_isEdit && _password.text.length < 8) {
      setState(() => _error =
          'Le mot de passe initial doit contenir au moins 8 caractères.');
      return;
    }
    if (_isLearner && (_program == null || _level == null)) {
      setState(
          () => _error = 'Filière et niveau sont requis pour un apprenant.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final draft = AccountDraft(
      name: _name.text,
      email: _email.text,
      role: _role,
      password: _isEdit ? null : _password.text,
      university: _university.text.trim(),
      program: _program ?? '',
      level: _level ?? '',
      matricule: _matricule.text.trim(),
      status: _status,
    );
    try {
      final api = ref.read(adminDirectoryApiProvider);
      final result = _isEdit
          ? await api.update(widget.existing!.userId, draft)
          : await api.create(draft);
      if (!mounted) return;
      final enrollments = result['enrollments'];
      showFeedback(
        context,
        message: _isEdit ? 'Compte mis à jour.' : 'Compte créé.',
        detail: enrollments is int && enrollments > 0
            ? 'Inscrit automatiquement à $enrollments cours de sa filière.'
            : null,
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin = ref.watch(isSuperAdminProvider);
    final reference = ref.watch(academicReferenceProvider).valueOrNull;
    final roles = [
      if (isSuperAdmin) 'ADMIN',
      'TEACHER',
      'DELEGATE',
      'STUDENT',
    ];
    final programs = reference?.programCodes ?? const <String>[];
    final levels = reference?.levelsOf(_program) ?? const <String>[];

    return AlertDialog(
      title: Text(
          _isEdit ? 'Modifier le compte' : 'Créer un compte universitaire'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nom complet')),
              const SizedBox(height: 12),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              if (!_isEdit) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mot de passe initial',
                    helperText:
                        'À communiquer à la personne ; elle pourra le changer.',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('role-$_role'),
                initialValue: roles.contains(_role) ? _role : roles.last,
                decoration: const InputDecoration(labelText: 'Rôle'),
                items: [
                  for (final r in roles)
                    DropdownMenuItem(
                        value: r, child: Text(parseUserRole(r).label)),
                ],
                onChanged: (v) => setState(() => _role = v ?? 'STUDENT'),
              ),
              if (isSuperAdmin) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _university,
                  decoration: const InputDecoration(
                    labelText: 'Université',
                    helperText: 'Nom tel qu\'enregistré sur les profils.',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (programs.isNotEmpty)
                DropdownButtonFormField<String>(
                  key: ValueKey('program-$_program'),
                  initialValue: programs.contains(_program) ? _program : null,
                  decoration: const InputDecoration(labelText: 'Filière'),
                  items: [
                    for (final code in programs)
                      DropdownMenuItem(
                        value: code,
                        child: Text(
                            reference?.programByCode(code)?.displayName ?? code,
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() {
                    _program = v;
                    _level = null;
                  }),
                )
              else
                TextField(
                  controller: TextEditingController(text: _program ?? ''),
                  onChanged: (v) =>
                      _program = v.trim().isEmpty ? null : v.trim(),
                  decoration:
                      const InputDecoration(labelText: 'Code de filière'),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('level-$_level-$_program'),
                initialValue: levels.contains(_level) ? _level : null,
                decoration: const InputDecoration(labelText: 'Niveau'),
                items: [
                  for (final l in levels)
                    DropdownMenuItem(value: l, child: Text(l))
                ],
                onChanged:
                    levels.isEmpty ? null : (v) => setState(() => _level = v),
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: _matricule,
                  decoration: const InputDecoration(
                      labelText: 'Matricule (facultatif)')),
              if (_isEdit) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Statut'),
                  items: const [
                    DropdownMenuItem(value: 'ACTIVE', child: Text('Actif')),
                    DropdownMenuItem(
                        value: 'SUSPENDED', child: Text('Suspendu')),
                    DropdownMenuItem(value: 'INACTIVE', child: Text('Inactif')),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? 'ACTIVE'),
                ),
              ],
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
              : Text(_isEdit ? 'Enregistrer' : 'Créer'),
        ),
      ],
    );
  }
}
