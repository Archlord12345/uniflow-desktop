import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/teacher.dart';
import '../widgets/app_breadcrumb.dart';
import '../widgets/user_avatar.dart';
import '../widgets/status_badge.dart';
import 'teacher_detail_screen.dart';

/// Page "Enseignants" : recherche, filtres, tableau paginé des enseignants.
/// Même structure que [StudentsScreen] pour rester cohérent visuellement.
///
/// Ce widget n'a pas de Scaffold/sidebar propre : il est affiché à
/// l'intérieur de [MainShell].
class TeachersScreen extends StatefulWidget {
  const TeachersScreen({super.key});

  @override
  State<TeachersScreen> createState() => _TeachersScreenState();
}

class _TeachersScreenState extends State<TeachersScreen> {
  final _searchController = TextEditingController();
  static const int totalTeachers = 312;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teachers = Teacher.mockList;

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTableHeader(),
                      ...teachers.map((t) => _TeacherRow(teacher: t)),
                      _buildPagination(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        border: Border(bottom: BorderSide(color: AppColors.inputBorder)),
      ),
      child: Row(
        children: [
          const Expanded(child: AppBreadcrumb(items: ['Accueil', 'Enseignants'])),
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
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: ouvrir le formulaire de création d'enseignant
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Ajouter enseignant'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
          ),
        ],
      ),
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
          SizedBox(width: 70, child: Text('ID', style: style)),
          Expanded(flex: 3, child: Text('NOM COMPLET', style: style)),
          Expanded(flex: 3, child: Text('EMAIL', style: style)),
          Expanded(flex: 2, child: Text('DÉPARTEMENT', style: style)),
          Expanded(flex: 2, child: Text('STATUT', style: style)),
          SizedBox(width: 90, child: Text('ACTIONS', style: style)),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Affichage de 1 à ${Teacher.mockList.length} sur $totalTeachers enseignants',
            style: AppTextStyles.body.copyWith(fontSize: 13),
          ),
          Row(
            children: [
              const _PageArrow(icon: Icons.chevron_left),
              const SizedBox(width: 6),
              const _PageButton(label: '1', isActive: true),
              const SizedBox(width: 6),
              const _PageButton(label: '2'),
              const SizedBox(width: 6),
              const _PageButton(label: '3'),
              const SizedBox(width: 6),
              const Text('...', style: TextStyle(color: AppColors.textMuted)),
              const SizedBox(width: 6),
              const _PageButton(label: '32'),
              const SizedBox(width: 6),
              const _PageArrow(icon: Icons.chevron_right),
            ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.inputBorder))),
      child: Row(
        children: [
          SizedBox(width: 70, child: Text(teacher.id, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                InitialsAvatar(initials: teacher.initials, backgroundColor: teacher.avatarColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Pr. ${teacher.fullName}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(flex: 3, child: Text(teacher.email, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: Text(teacher.departement, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
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

class _PageButton extends StatelessWidget {
  final String label;
  final bool isActive;

  const _PageButton({required this.label, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isActive ? AppColors.primaryBlue : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isActive ? null : Border.all(color: AppColors.inputBorder),
      ),
      child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isActive ? Colors.white : AppColors.textSecondary)),
    );
  }
}

class _PageArrow extends StatelessWidget {
  final IconData icon;

  const _PageArrow({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.inputBorder)),
      child: Icon(icon, size: 18, color: AppColors.textMuted),
    );
  }
}
