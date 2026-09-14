import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../models/teacher.dart';
import '../providers/directory_provider.dart';
import '../widgets/app_page_bar.dart';
import '../widgets/data_state_view.dart';
import '../widgets/user_avatar.dart';
import '../widgets/status_badge.dart';
import 'teacher_detail_screen.dart';

/// Page "Enseignants" : recherche, tableau des enseignants.
///
/// Les lignes proviennent de la collection `academic_directory` d'Appwrite,
/// jointe aux profils `users` (pseudo, photo) ; elles étaient auparavant codées
/// en dur. Même structure que [StudentsScreen] pour rester cohérent.
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
                const SizedBox(height: 18),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.inputBorder),
                  ),
                  child: teachersAsync.when(
                    loading: () => const DataLoadingView(
                      label: 'Chargement de l\'annuaire académique…',
                    ),
                    error: (error, _) => DataErrorView(
                      error: error,
                      onRetry: () => ref.invalidate(directoryProvider),
                    ),
                    data: (teachers) => _buildTable(_filtered(teachers)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTable(List<Teacher> teachers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTableHeader(),
        if (teachers.isEmpty)
          DataEmptyView(
            icon: Icons.school_outlined,
            message: _searchController.text.trim().isEmpty
                ? 'Aucun enseignant dans l\'annuaire académique.'
                : 'Aucun enseignant ne correspond à « ${_searchController.text.trim()} ».',
          )
        else
          ...teachers.map((teacher) => _TeacherRow(teacher: teacher)),
        _buildFooter(teachers),
      ],
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
          icon: const Icon(Icons.tune, size: 17, color: AppColors.textSecondary),
          label: const Text('Filtres avancés'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: const BorderSide(color: AppColors.inputBorder),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {
            // TODO: ouvrir le formulaire de création d'enseignant
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Ajouter enseignant'),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
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
        prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.cardWhite,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.inputBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.inputBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5)),
      ),
    );
  }

  Widget _buildTableHeader() {
    const style = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.3);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.inputBorder))),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('NOM COMPLET', style: style)),
          Expanded(flex: 3, child: Text('PSEUDO / EMAIL', style: style)),
          Expanded(flex: 2, child: Text('DÉPARTEMENT', style: style)),
          Expanded(flex: 2, child: Text('STATUT', style: style)),
          SizedBox(width: 90, child: Text('ACTIONS', style: style)),
        ],
      ),
    );
  }

  /// Pied de tableau : le décompte réel remplace la pagination factice.
  Widget _buildFooter(List<Teacher> teachers) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Text(
            teachers.length <= 1
                ? '${teachers.length} enseignant'
                : '${teachers.length} enseignants',
            style: AppTextStyles.body.copyWith(fontSize: 13),
          ),
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

class _TeacherRow extends StatelessWidget {
  final Teacher teacher;

  const _TeacherRow({required this.teacher});

  @override
  Widget build(BuildContext context) {
    // Le pseudo est le référent affiché ; l'email ne sert que de repli.
    final handle = (teacher.username ?? '').isNotEmpty
        ? '@${teacher.username}'
        : (teacher.email.isNotEmpty ? teacher.email : '—');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.inputBorder))),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                InitialsAvatar(
                  initials: teacher.initials,
                  backgroundColor: teacher.avatarColor,
                  avatarFileId: teacher.avatarFileId,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    teacher.fullName.isEmpty ? '—' : 'Pr. ${teacher.fullName}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              handle,
              style: TextStyle(
                fontSize: 13,
                color: teacher.username != null && teacher.username!.isNotEmpty
                    ? AppColors.primaryBlue
                    : AppColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(flex: 2, child: Text(teacher.departement.isEmpty ? '—' : teacher.departement, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
          Expanded(
            flex: 2,
            child: Align(alignment: Alignment.centerLeft, child: StatusBadge(label: teacher.statut, backgroundColor: teacher.statutColor)),
          ),
          SizedBox(
            width: 90,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_red_eye_outlined, size: 17),
                  color: AppColors.primaryBlue,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                  tooltip: 'Voir la fiche',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => TeacherDetailScreen(teacher: teacher)),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  color: const Color(0xFFF5A623),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                  tooltip: 'Modifier',
                  onPressed: () {
                    // TODO: ouvrir le formulaire d'édition
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
