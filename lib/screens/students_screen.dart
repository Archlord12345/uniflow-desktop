import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../models/student.dart';
import '../providers/directory_provider.dart';
import '../widgets/app_page_bar.dart';
import '../widgets/data_state_view.dart';
import '../widgets/user_avatar.dart';
import '../widgets/status_badge.dart';
import 'student_detail_screen.dart';

/// Page "Étudiants" : fil d'Ariane, filtres, tableau des étudiants.
///
/// Les lignes proviennent de la collection `academic_directory` d'Appwrite,
/// jointe aux profils `users` (pseudo, photo). Ce widget n'a pas de
/// Scaffold/sidebar propre : il est affiché à l'intérieur de [MainShell].
class StudentsScreen extends ConsumerStatefulWidget {
  const StudentsScreen({super.key});

  @override
  ConsumerState<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends ConsumerState<StudentsScreen> {
  final _searchController = TextEditingController();
  // Lignes cochées dans le tableau (par identifiant Appwrite)
  final Set<String> _checkedIds = {};

  @override
  void initState() {
    super.initState();
    // Le champ pilote le filtrage : sans ce réabonnement, la liste ne se
    // rafraîchirait qu'au prochain événement sans rapport.
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Student> _filtered(List<Student> students) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return students;
    return students.where((student) {
      return student.fullName.toLowerCase().contains(query) ||
          student.matricule.toLowerCase().contains(query) ||
          student.email.toLowerCase().contains(query) ||
          student.programme.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTopBar(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFiltersRow(),
                const SizedBox(height: 18),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.inputBorder),
                  ),
                  child: studentsAsync.when(
                    loading: () => const DataLoadingView(
                      label: 'Chargement de l\'annuaire académique…',
                    ),
                    error: (error, _) => DataErrorView(
                      error: error,
                      onRetry: () => ref.invalidate(directoryProvider),
                    ),
                    data: (students) => _buildTable(_filtered(students)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTable(List<Student> students) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTableHeader(students),
        if (students.isEmpty)
          DataEmptyView(
            icon: Icons.people_outline,
            message: _searchController.text.trim().isEmpty
                ? 'Aucun étudiant dans l\'annuaire académique.\nLes comptes apparaissent ici une fois inscrits.'
                : 'Aucun étudiant ne correspond à « ${_searchController.text.trim()} ».',
          )
        else
          ...students.asMap().entries.map((entry) => _StudentRow(
                index: entry.key + 1,
                student: entry.value,
                isChecked: _checkedIds.contains(entry.value.id),
                onCheckedChanged: (checked) => setState(() {
                  if (checked) {
                    _checkedIds.add(entry.value.id);
                  } else {
                    _checkedIds.remove(entry.value.id);
                  }
                }),
              )),
        _buildFooter(students),
      ],
    );
  }

  /// Barre du haut : fil d'Ariane "Accueil / Étudiants" + boutons d'action.
  Widget _buildTopBar() {
    return AppPageBar(
      breadcrumb: const ['Accueil', 'Étudiants'],
      actions: [
        OutlinedButton.icon(
          onPressed: () {
            // TODO: ouvrir le panneau de filtres avancés
          },
          icon:
              const Icon(Icons.tune, size: 17, color: AppColors.textSecondary),
          label: const Text('Filtres avancés'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: const BorderSide(color: AppColors.inputBorder),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {
            // TODO: ouvrir le formulaire de création d'étudiant
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Ajouter étudiant'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
        ),
      ],
    );
  }

  /// Rangée de recherche + filtres déroulants (Programme / Niveau / Statut) + Export.
  ///
  /// En dessous du seuil, les quatre contrôles ne tiennent plus sur une ligne :
  /// chacun recevait moins que sa largeur minimale (bordure + flèche) et la
  /// ligne débordait. Ils se replient alors sur plusieurs rangées.
  Widget _buildFiltersRow() {
    final searchField = TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Rechercher un étudiant...',
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

    final exportButton = OutlinedButton.icon(
      onPressed: () {
        // TODO: exporter la liste des étudiants (CSV/Excel)
      },
      icon: const Icon(Icons.file_upload_outlined,
          size: 17, color: AppColors.textSecondary),
      label: const Text('Export'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        side: const BorderSide(color: AppColors.inputBorder),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final filters = <Widget>[
          SizedBox(width: 160, child: _FilterDropdown(label: 'Programme')),
          SizedBox(width: 160, child: _FilterDropdown(label: 'Niveau')),
          SizedBox(width: 160, child: _FilterDropdown(label: 'Statut')),
          exportButton,
        ];

        if (constraints.maxWidth < 900) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchField,
              const SizedBox(height: 12),
              Wrap(spacing: 12, runSpacing: 12, children: filters),
            ],
          );
        }

        return Row(
          children: [
            Expanded(flex: 2, child: searchField),
            const SizedBox(width: 12),
            for (final filter in filters) ...[
              if (filter != exportButton) Expanded(child: filter) else filter,
              const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }

  Widget _buildTableHeader(List<Student> students) {
    const style = TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: 0.3);
    final allChecked = students.isNotEmpty &&
        students.every((s) => _checkedIds.contains(s.id));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.inputBorder))),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Checkbox(
              value: allChecked,
              onChanged: (v) => setState(() {
                if (v == true) {
                  _checkedIds.addAll(students.map((s) => s.id));
                } else {
                  _checkedIds.clear();
                }
              }),
              activeColor: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(width: 28, child: Text('#', style: style)),
          const Expanded(flex: 3, child: Text('NOM', style: style)),
          const Expanded(flex: 2, child: Text('N° ÉTUDIANT', style: style)),
          const Expanded(flex: 3, child: Text('PSEUDO / EMAIL', style: style)),
          const Expanded(flex: 2, child: Text('PROGRAMME', style: style)),
          const Expanded(flex: 2, child: Text('NIVEAU', style: style)),
          const Expanded(flex: 2, child: Text('STATUT', style: style)),
          const Expanded(flex: 2, child: Text('INSCRIT LE', style: style)),
          const SizedBox(width: 100, child: Text('ACTIONS', style: style)),
        ],
      ),
    );
  }

  /// Pied de tableau : le décompte réel remplace la pagination factice.
  Widget _buildFooter(List<Student> students) {
    final selected = _checkedIds.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Text(
            students.length <= 1
                ? '${students.length} étudiant'
                : '${students.length} étudiants',
            style: AppTextStyles.body.copyWith(fontSize: 13),
          ),
          if (selected > 0) ...[
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$selected sélectionné${selected > 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryBlue,
                ),
              ),
            ),
          ],
          const Spacer(),
          IconButton(
            onPressed: () => ref.invalidate(directoryProvider),
            icon: const Icon(Icons.refresh, size: 18),
            color: AppColors.textSecondary,
            tooltip: 'Recharger depuis Appwrite',
          ),
        ],
      ),
    );
  }
}

/// Filtre déroulant simple (visuel uniquement pour l'instant — à connecter
/// à une vraie logique de filtrage plus tard).
class _FilterDropdown extends StatelessWidget {
  final String label;

  const _FilterDropdown({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
          border: Border.all(color: AppColors.inputBorder),
          borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // `Expanded` + ellipse : le libellé du filtre est le seul contenu
          // souple de la ligne, et « Programme » tronquait la flèche hors du
          // cadre dans une fenêtre étroite.
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13.5, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.keyboard_arrow_down,
              size: 18, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

/// Une ligne du tableau représentant un étudiant.
class _StudentRow extends StatelessWidget {
  final int index;
  final Student student;
  final bool isChecked;
  final ValueChanged<bool> onCheckedChanged;

  const _StudentRow({
    required this.index,
    required this.student,
    required this.isChecked,
    required this.onCheckedChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Le pseudo est le référent affiché ; l'email ne sert que de repli pour les
    // comptes qui n'en ont pas encore.
    final handle = (student.username ?? '').isNotEmpty
        ? '@${student.username}'
        : (student.email.isNotEmpty ? student.email : '—');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.inputBorder))),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Checkbox(
              value: isChecked,
              onChanged: (v) => onCheckedChanged(v ?? false),
              activeColor: AppColors.primaryBlue,
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              index.toString(),
              style:
                  const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                InitialsAvatar(
                  initials: student.initials,
                  backgroundColor: student.avatarColor,
                  avatarFileId: student.avatarFileId,
                  size: 34,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    student.fullName.isEmpty ? '—' : student.fullName,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
              flex: 2,
              child: Text(_orDash(student.matricule),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary))),
          Expanded(
            flex: 3,
            child: Text(
              handle,
              style: TextStyle(
                fontSize: 13,
                color: student.username != null && student.username!.isNotEmpty
                    ? AppColors.primaryBlue
                    : AppColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
              flex: 2,
              child: Text(_orDash(student.programme),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary))),
          Expanded(
              flex: 2,
              child: Text(_orDash(student.niveau),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary))),
          Expanded(
            flex: 2,
            child: Align(
                alignment: Alignment.centerLeft,
                child: StatusBadge(
                    label: student.statut,
                    backgroundColor: student.statutColor)),
          ),
          Expanded(
              flex: 2,
              child: Text(_orDash(student.inscritLe),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary))),
          SizedBox(
            width: 100,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_red_eye_outlined, size: 17),
                  color: AppColors.primaryBlue,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 30, minHeight: 30),
                  tooltip: 'Voir la fiche',
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => StudentDetailScreen(student: student)));
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  color: const Color(0xFFF5A623),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 30, minHeight: 30),
                  tooltip: 'Modifier',
                  onPressed: () {
                    // TODO: ouvrir le formulaire d'édition
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 16),
                  color: AppColors.danger,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 30, minHeight: 30),
                  tooltip: 'Supprimer',
                  onPressed: () {
                    // TODO: confirmer puis supprimer l'étudiant
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Un champ absent de la base s'affiche « — » plutôt que vide : la colonne
  /// reste lisible et rien n'est inventé.
  static String _orDash(String value) => value.trim().isEmpty ? '—' : value;
}
