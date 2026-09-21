import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../models/teacher.dart';
import '../providers/directory_provider.dart';
import '../ui/app_data_table.dart';
import '../ui/status_badge.dart';
import '../widgets/app_page_bar.dart';
import '../widgets/data_state_view.dart';
import '../widgets/user_avatar.dart';
import 'teacher_detail_screen.dart';

/// Page "Enseignants" : recherche, tableau des enseignants.
///
/// Les lignes proviennent de la collection `academic_directory` d'Appwrite,
/// jointe aux profils `users` (pseudo, photo) ; elles étaient auparavant codées
/// en dur. Même structure que [StudentsScreen] pour rester cohérent.
///
/// Le tableau est un [AppDataTable] (planche « Enseignants ») : en-tête gris
/// très clair en petites majuscules, lignes de 52 px, pied avec le décompte.
/// La version maison avait ses propres marges et sa propre graisse d'en-tête,
/// et ne ressemblait ni aux planches ni aux autres tableaux.
///
/// Ce widget n'a pas de Scaffold/sidebar propre : il est affiché à
/// l'intérieur de [MainShell].
class TeachersScreen extends ConsumerStatefulWidget {
  const TeachersScreen({super.key});

  @override
  ConsumerState<TeachersScreen> createState() => _TeachersScreenState();
}

class _TeachersScreenState extends ConsumerState<TeachersScreen> {
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

  List<Teacher> _filtered(List<Teacher> teachers) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return teachers;
    return teachers.where((teacher) {
      return teacher.fullName.toLowerCase().contains(query) ||
          teacher.email.toLowerCase().contains(query) ||
          teacher.departement.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final teachersAsync = ref.watch(teachersProvider);

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
                _buildSearchRow(),
                const SizedBox(height: AppSpacing.lg),
                teachersAsync.when(
                  loading: () => const DataLoadingView(
                    label: 'Chargement de l\'annuaire académique…',
                  ),
                  error: (error, _) => DataErrorView(
                    error: error,
                    onRetry: () => ref.invalidate(directoryProvider),
                  ),
                  data: (teachers) => _buildTable(_filtered(teachers)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Colonnes de la planche « Enseignants » ; la colonne d'actions a une
  /// largeur fixe pour que deux icônes n'y soient jamais comprimées.
  static const List<AppColumn> columns = [
    AppColumn('Nom complet', flex: 3),
    AppColumn('Pseudo / email', flex: 3),
    AppColumn('Département', flex: 2),
    AppColumn('Statut', flex: 2),
    AppColumn('Actions', width: 80),
  ];

  Widget _buildTable(List<Teacher> teachers) {
    final query = _searchController.text.trim();
    return AppDataTable<Teacher>(
      columns: columns,
      rows: teachers,
      cells: (teacher, _) => _TeacherRow.cells(context, teacher),
      onRowTap: (teacher) => _TeacherRow.open(context, teacher),
      empty: DataEmptyView(
        icon: Icons.school_outlined,
        message: query.isEmpty
            ? 'Aucun enseignant dans l\'annuaire académique.'
            : 'Aucun enseignant ne correspond à « $query ».',
      ),
      footer: AppTableFooter(
        label: AppTableFooter.count(teachers.length, 'enseignant'),
        actions: [
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

  Widget _buildTopBar() {
    return AppPageBar(
      breadcrumb: const ['Accueil', 'Enseignants'],
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
            // TODO: ouvrir le formulaire de création d'enseignant
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Ajouter enseignant'),
          style: ElevatedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
        ),
      ],
    );
  }

  Widget _buildSearchRow() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Rechercher un enseignant...',
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

/// Cellules d'une ligne du tableau des enseignants, dans l'ordre de
/// [_TeachersScreenState.columns].
class _TeacherRow {
  _TeacherRow._();

  static void open(BuildContext context, Teacher teacher) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TeacherDetailScreen(teacher: teacher)),
    );
  }

  static List<Widget> cells(BuildContext context, Teacher teacher) {
    // Le pseudo est le référent affiché ; l'email ne sert que de repli.
    final hasHandle = (teacher.username ?? '').isNotEmpty;
    final handle = hasHandle
        ? '@${teacher.username}'
        : (teacher.email.isNotEmpty ? teacher.email : '—');

    return [
      Row(
        children: [
          InitialsAvatar(
            initials: teacher.initials,
            backgroundColor: teacher.avatarColor,
            avatarFileId: teacher.avatarFileId,
            size: 34,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              teacher.fullName.isEmpty ? '—' : 'Pr. ${teacher.fullName}',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      Text(
        handle,
        style: TextStyle(
          fontSize: 13,
          color: hasHandle ? AppColors.primaryBlue : AppColors.textSecondary,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      Text(
        teacher.departement.isEmpty ? '—' : teacher.departement,
        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      StatusBadge.fromStatus(teacher.statut),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionIcon(
            icon: Icons.remove_red_eye_outlined,
            color: AppColors.primaryBlue,
            tooltip: 'Voir la fiche',
            onPressed: () => open(context, teacher),
          ),
          _ActionIcon(
            icon: Icons.edit_outlined,
            color: AppColors.warning,
            tooltip: 'Modifier',
            onPressed: () {
              // TODO: ouvrir le formulaire d'édition
            },
          ),
        ],
      ),
    ];
  }
}

/// Icône d'action de 36 px, sans la cible tactile de 48 px de Material :
/// deux `IconButton` standard font 96 px et débordaient de la colonne
/// « Actions » de 80 px (le test le signalait : « overflowed by 16 pixels »).
/// Sur un bureau, le pointeur n'a pas besoin de la marge tactile.
class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  static const double side = 36;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 17),
      color: color,
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        padding: EdgeInsets.zero,
        fixedSize: const Size.square(side),
        minimumSize: const Size.square(side),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
