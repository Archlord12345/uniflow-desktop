import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../widgets/uni_icons.dart';
import '../models/student.dart';
import '../providers/directory_provider.dart';
import '../ui/app_button.dart';
import '../ui/app_data_table.dart';
import '../ui/status_badge.dart';
import '../ui/table_action_icon.dart';
import '../widgets/app_page_bar.dart';
import '../widgets/data_state_view.dart';
import '../widgets/user_avatar.dart';
import 'student_detail_screen.dart';

/// Page "Étudiants" : fil d'Ariane, filtres, tableau des étudiants.
///
/// Les lignes proviennent de la collection `academic_directory` d'Appwrite,
/// jointe aux profils `users` (pseudo, photo). Ce widget n'a pas de
/// Scaffold/sidebar propre : il est affiché à l'intérieur de [MainShell].
///
/// Le tableau est un [AppDataTable] comme celui des enseignants : les deux
/// annuaires avaient chacun leur en-tête, leurs marges et leur pied, et se
/// distinguaient à l'œil alors que les planches les dessinent identiques.
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
                const SizedBox(height: AppSpacing.lg),
                studentsAsync.when(
                  loading: () => const DataLoadingView(
                    label: 'Chargement de l\'annuaire académique…',
                  ),
                  error: (error, _) => DataErrorView(
                    error: error,
                    onRetry: () => ref.invalidate(directoryProvider),
                  ),
                  data: (students) => _buildTable(_filtered(students)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Colonnes de la planche « Étudiants » : sélection, rang, puis les champs
  /// de l'annuaire ; la colonne d'actions a la largeur exacte de trois icônes.
  List<AppColumn> _columns(List<Student> students) {
    final allChecked = students.isNotEmpty &&
        students.every((s) => _checkedIds.contains(s.id));
    return [
      AppColumn(
        'Sélection',
        width: 32,
        header: _RowCheckbox(
          value: allChecked,
          onChanged: (v) => setState(() {
            if (v) {
              _checkedIds.addAll(students.map((s) => s.id));
            } else {
              _checkedIds.clear();
            }
          }),
        ),
      ),
      const AppColumn('#', width: 28),
      const AppColumn('Nom', flex: 3),
      const AppColumn('N° étudiant', flex: 2),
      const AppColumn('Pseudo / email', flex: 3),
      const AppColumn('Programme', flex: 2),
      const AppColumn('Niveau', flex: 2),
      const AppColumn('Statut', flex: 2),
      const AppColumn('Inscrit le', flex: 2),
      AppColumn('Actions', width: TableActionIcon.columnWidth(3)),
    ];
  }

  /// Dix colonnes, dont trois fixes (sélection, rang, actions) : sous ce
  /// seuil, la colonne « Nom » ne gardait que quelques pixels pour l'avatar
  /// et le tableau défile horizontalement.
  static const double _minTableWidth = 960;

  Widget _buildTable(List<Student> students) {
    final query = _searchController.text.trim();
    return AppDataTable<Student>(
      columns: _columns(students),
      rows: students,
      minWidth: _minTableWidth,
      cells: (student, index) => _StudentRow.cells(
        context,
        student,
        index: index + 1,
        isChecked: _checkedIds.contains(student.id),
        onCheckedChanged: (checked) => setState(() {
          if (checked) {
            _checkedIds.add(student.id);
          } else {
            _checkedIds.remove(student.id);
          }
        }),
      ),
      onRowTap: (student) => _StudentRow.open(context, student),
      empty: DataEmptyView(
        icon: UniIcons.students(),
        message: query.isEmpty
            ? 'Aucun étudiant dans l\'annuaire académique.\nLes comptes apparaissent ici une fois inscrits.'
            : 'Aucun étudiant ne correspond à « $query ».',
      ),
      footer: _buildFooter(students),
    );
  }

  /// Barre du haut : fil d'Ariane "Accueil / Étudiants" + boutons d'action.
  Widget _buildTopBar() {
    return AppPageBar(
      breadcrumb: const ['Accueil', 'Étudiants'],
      actions: [
        AppButton.secondary(
          label: 'Filtres avancés',
          icon: UniIcons.sliders(UniIconStyle.bold),
          onPressed: () {
            // TODO: ouvrir le panneau de filtres avancés
          },
        ),
        AppButton(
          label: 'Ajouter étudiant',
          icon: UniIcons.add(UniIconStyle.bold),
          onPressed: () {
            // TODO: ouvrir le formulaire de création d'étudiant
          },
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
        prefixIcon: PhosphorIcon(UniIcons.search(UniIconStyle.bold),
            size: 20, color: AppColors.textMuted),
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

    final exportButton = AppButton.secondary(
      label: 'Export',
      icon: UniIcons.export(UniIconStyle.bold),
      // Même hauteur que le champ de recherche voisin (bordure comprise).
      height: 48,
      onPressed: () {
        // TODO: exporter la liste des étudiants (CSV/Excel)
      },
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final filters = <Widget>[
          const SizedBox(
              width: 160, child: _FilterDropdown(label: 'Programme')),
          const SizedBox(width: 160, child: _FilterDropdown(label: 'Niveau')),
          const SizedBox(width: 160, child: _FilterDropdown(label: 'Statut')),
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

  /// Pied de tableau : le décompte réel remplace la pagination factice ; la
  /// sélection en cours s'affiche en pastille.
  Widget _buildFooter(List<Student> students) {
    final selected = _checkedIds.length;
    return AppTableFooter(
      label: AppTableFooter.count(students.length, 'étudiant'),
      actions: [
        if (selected > 0) ...[
          StatusBadge(
            label: '$selected sélectionné${selected > 1 ? 's' : ''}',
            tone: BadgeTone.info,
          ),
          const SizedBox(width: AppSpacing.md),
        ],
        IconButton(
          onPressed: () => ref.invalidate(directoryProvider),
          icon: PhosphorIcon(UniIcons.refresh(UniIconStyle.bold), size: 18),
          color: AppColors.textSecondary,
          tooltip: 'Recharger depuis Appwrite',
        ),
      ],
    );
  }
}

/// Case à cocher d'une ligne ou de l'en-tête, ramenée à la hauteur de la
/// ligne : la case Material réserve 48 px de cible tactile et forçait les
/// lignes à 48 px de haut quand le reste du tableau en fait 52 — la colonne
/// de sélection débordait sous l'en-tête gris.
class _RowCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _RowCheckbox({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Checkbox(
        value: value,
        onChanged: (v) => onChanged(v ?? false),
        activeColor: AppColors.primaryBlue,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
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
          PhosphorIcon(UniIcons.chevronDown(UniIconStyle.bold),
              size: 18, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

/// Cellules d'une ligne du tableau des étudiants, dans l'ordre des colonnes de
/// `_StudentsScreenState._columns`.
abstract final class _StudentRow {
  static const _muted = TextStyle(fontSize: 13, color: AppColors.textSecondary);

  static void open(BuildContext context, Student student) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => StudentDetailScreen(student: student)));
  }

  static List<Widget> cells(
    BuildContext context,
    Student student, {
    required int index,
    required bool isChecked,
    required ValueChanged<bool> onCheckedChanged,
  }) {
    // Le pseudo est le référent affiché ; l'email ne sert que de repli pour les
    // comptes qui n'en ont pas encore.
    final hasHandle = (student.username ?? '').isNotEmpty;
    final handle = hasHandle
        ? '@${student.username}'
        : (student.email.isNotEmpty ? student.email : '—');

    return [
      _RowCheckbox(value: isChecked, onChanged: onCheckedChanged),
      Text(index.toString(), style: _muted),
      Row(
        children: [
          InitialsAvatar(
            initials: student.initials,
            backgroundColor: student.avatarColor,
            avatarFileId: student.avatarFileId,
            size: 34,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              student.fullName.isEmpty ? '—' : student.fullName,
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      _text(_orDash(student.matricule)),
      Text(
        handle,
        style: TextStyle(
          fontSize: 13,
          color: hasHandle ? AppColors.primaryBlue : AppColors.textSecondary,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      _text(_orDash(student.programme)),
      _text(_orDash(student.niveau)),
      StatusBadge.fromStatus(student.statut),
      _text(_orDash(student.inscritLe)),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TableActionIcon(
            icon: UniIcons.eye(UniIconStyle.bold),
            color: AppColors.primaryBlue,
            tooltip: 'Voir la fiche',
            onPressed: () => open(context, student),
          ),
          TableActionIcon(
            icon: UniIcons.edit(UniIconStyle.bold),
            color: AppColors.warning,
            tooltip: 'Modifier',
            onPressed: () {
              // TODO: ouvrir le formulaire d'édition
            },
          ),
          TableActionIcon(
            icon: UniIcons.delete(UniIconStyle.bold),
            color: AppColors.danger,
            tooltip: 'Supprimer',
            onPressed: () {
              // TODO: confirmer puis supprimer l'étudiant
            },
          ),
        ],
      ),
    ];
  }

  static Widget _text(String value) =>
      Text(value, style: _muted, maxLines: 1, overflow: TextOverflow.ellipsis);

  /// Un champ absent de la base s'affiche « — » plutôt que vide : la colonne
  /// reste lisible et rien n'est inventé.
  static String _orDash(String value) => value.trim().isEmpty ? '—' : value;
}
