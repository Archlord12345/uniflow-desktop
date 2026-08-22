import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/classroom.dart';
import '../widgets/app_breadcrumb.dart';
import '../widgets/status_badge.dart';

/// Page "Salles" (Gestion des Salles) : recherche, tableau paginé des
/// salles avec leur capacité, type, bâtiment et statut de disponibilité.
///
/// Ce widget n'a pas de Scaffold/sidebar propre : il est affiché à
/// l'intérieur de [MainShell].
class ClassroomsScreen extends StatefulWidget {
  const ClassroomsScreen({super.key});

  @override
  State<ClassroomsScreen> createState() => _ClassroomsScreenState();
}

class _ClassroomsScreenState extends State<ClassroomsScreen> {
  final _searchController = TextEditingController();
  static const int totalClassrooms = 156;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final classrooms = Classroom.mockList;

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
                      ...classrooms.map((c) => _ClassroomRow(classroom: c)),
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppBreadcrumb(items: ['Accueil', 'Salles']),
                SizedBox(height: 4),
                Text('Gérez les salles et leurs disponibilités', style: AppTextStyles.body),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: ouvrir le formulaire de création de salle
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Ajouter salle'),
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
        hintText: 'Rechercher une salle...',
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
          SizedBox(width: 70, child: Text('CODE', style: style)),
          Expanded(flex: 3, child: Text('NOM DE LA SALLE', style: style)),
          SizedBox(width: 80, child: Text('CAPACITÉ', style: style)),
          Expanded(flex: 2, child: Text('TYPE', style: style)),
          Expanded(flex: 2, child: Text('BÂTIMENT', style: style)),
          Expanded(flex: 2, child: Text('STATUT', style: style)),
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
            'Affichage de 1 à ${Classroom.mockList.length} sur $totalClassrooms salles',
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
              const _PageButton(label: '16'),
              const SizedBox(width: 6),
              const _PageArrow(icon: Icons.chevron_right),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClassroomRow extends StatelessWidget {
  final Classroom classroom;

  const _ClassroomRow({required this.classroom});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.inputBorder))),
      child: Row(
        children: [
          SizedBox(width: 70, child: Text(classroom.code, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
          Expanded(flex: 3, child: Text(classroom.nom, style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary))),
          SizedBox(width: 80, child: Text(classroom.capacite.toString(), style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
          Expanded(flex: 2, child: Text(classroom.type, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
          Expanded(flex: 2, child: Text(classroom.batiment, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
          Expanded(
            flex: 2,
            child: Align(alignment: Alignment.centerLeft, child: StatusBadge(label: classroom.statut, backgroundColor: classroom.statutColor)),
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
