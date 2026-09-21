import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../widgets/uni_icons.dart';
import '../models/teacher.dart';
import '../providers/directory_provider.dart';
import '../ui/app_button.dart';
import '../ui/app_data_table.dart';
import '../ui/status_badge.dart';
import '../ui/table_action_icon.dart';
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
    AppColumn('Actions', width: TableActionIcon.side * 2 + 8),
  ];

  Widget _buildTable(List<Teacher> teachers) {
    final query = _searchController.text.trim();
    return AppDataTable<Teacher>(
      columns: columns,
      rows: teachers,
      cells: (teacher, _) => _TeacherRow.cells(context, teacher),
      onRowTap: (teacher) => _TeacherRow.open(context, teacher),
      empty: DataEmptyView(
        icon: UniIcons.teachers(),
        message: query.isEmpty
            ? 'Aucun enseignant dans l\'annuaire académique.'
            : 'Aucun enseignant ne correspond à « $query ».',
      ),
      footer: AppTableFooter(
        label: AppTableFooter.count(teachers.length, 'enseignant'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(directoryProvider),
            icon: PhosphorIcon(UniIcons.refresh(UniIconStyle.bold), size: 18),
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
        AppButton.secondary(
          label: 'Filtres avancés',
          icon: UniIcons.sliders(UniIconStyle.bold),
          onPressed: () {
            // TODO: ouvrir le panneau de filtres avancés
          },
        ),
        AppButton(
          label: 'Ajouter enseignant',
          icon: UniIcons.add(UniIconStyle.bold),
          onPressed: () {
            // TODO: ouvrir le formulaire de création d'enseignant
          },
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
          TableActionIcon(
            icon: UniIcons.eye(UniIconStyle.bold),
            color: AppColors.primaryBlue,
            tooltip: 'Voir la fiche',
            onPressed: () => open(context, teacher),
          ),
          TableActionIcon(
            icon: UniIcons.edit(UniIconStyle.bold),
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
