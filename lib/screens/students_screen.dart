import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/student.dart';
import '../widgets/app_breadcrumb.dart';
import '../widgets/user_avatar.dart';
import '../widgets/status_badge.dart';
import 'student_detail_screen.dart';

/// Page "Étudiants" : fil d'Ariane, filtres, tableau paginé des étudiants.
/// Fidèle à la maquette "UniFlow Desktop Partie 1".
///
/// Ce widget n'a pas de Scaffold/sidebar propre : il est affiché à
/// l'intérieur de [MainShell].
class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final _searchController = TextEditingController();
  // Lignes cochées dans le tableau (par id étudiant)
  final Set<String> _checkedIds = {};

  static const int totalStudents = 198;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final students = Student.mockList;

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTableHeader(students),
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

  /// Barre du haut : fil d'Ariane "Accueil / Étudiants" + boutons d'action.
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        border: Border(bottom: BorderSide(color: AppColors.inputBorder)),
      ),
      child: Row(
        children: [
          const Expanded(child: AppBreadcrumb(items: ['Accueil', 'Étudiants'])),
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
              // TODO: ouvrir le formulaire de création d'étudiant
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Ajouter étudiant'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
          ),
        ],
      ),
    );
  }

  /// Rangée de recherche + filtres déroulants (Programme / Niveau / Statut) + Export.
  Widget _buildFiltersRow() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Rechercher un étudiant...',
              hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
              prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.cardWhite,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.inputBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.inputBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: _FilterDropdown(label: 'Programme')),
        const SizedBox(width: 12),
        Expanded(child: _FilterDropdown(label: 'Niveau')),
        const SizedBox(width: 12),
        Expanded(child: _FilterDropdown(label: 'Statut')),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: () {
            // TODO: exporter la liste des étudiants (CSV/Excel)
          },
          icon: const Icon(Icons.file_upload_outlined, size: 17, color: AppColors.textSecondary),
          label: const Text('Export'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: const BorderSide(color: AppColors.inputBorder),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader(List<Student> students) {
    const style = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.3);
    final allChecked = students.isNotEmpty && students.every((s) => _checkedIds.contains(s.id));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.inputBorder))),
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
          const Expanded(flex: 3, child: Text('EMAIL', style: style)),
          const Expanded(flex: 2, child: Text('PROGRAMME', style: style)),
          const Expanded(flex: 2, child: Text('NIVEAU', style: style)),
          const Expanded(flex: 2, child: Text('STATUT', style: style)),
          const Expanded(flex: 2, child: Text('INSCRIT LE', style: style)),
          const SizedBox(width: 100, child: Text('ACTIONS', style: style)),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('1 sur $totalStudents étudiants', style: AppTextStyles.body.copyWith(fontSize: 13)),
          Row(
            children: [
              const _PageArrow(icon: Icons.chevron_left),
              const SizedBox(width: 6),
              _PageButton(label: '1', isActive: true),
              const SizedBox(width: 6),
              const _PageButton(label: '2'),
              const SizedBox(width: 6),
              const _PageButton(label: '3'),
              const SizedBox(width: 6),
              const _PageButton(label: '4'),
              const SizedBox(width: 6),
              const _PageButton(label: '5'),
              const SizedBox(width: 6),
              const Text('...', style: TextStyle(color: AppColors.textMuted)),
              const SizedBox(width: 6),
              const _PageButton(label: '20'),
              const SizedBox(width: 6),
              const _PageArrow(icon: Icons.chevron_right),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(border: Border.all(color: AppColors.inputBorder), borderRadius: BorderRadius.circular(8)),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('10 par page', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                SizedBox(width: 6),
                Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textMuted),
              ],
            ),
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
      decoration: BoxDecoration(border: Border.all(color: AppColors.inputBorder), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary)),
          const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textMuted),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.inputBorder))),
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
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                InitialsAvatar(initials: student.initials, backgroundColor: student.avatarColor, size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    student.fullName,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(flex: 2, child: Text(student.matricule, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
          Expanded(flex: 3, child: Text(student.email, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: Text(student.programme, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
          Expanded(flex: 2, child: Text(student.niveau, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
          Expanded(
            flex: 2,
            child: Align(alignment: Alignment.centerLeft, child: StatusBadge(label: student.statut, backgroundColor: student.statutColor)),
          ),
          Expanded(flex: 2, child: Text(student.inscritLe, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
          SizedBox(
            width: 100,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_red_eye_outlined, size: 17),
                  color: AppColors.primaryBlue,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => StudentDetailScreen(student: student)));
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
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 16),
                  color: AppColors.danger,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
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
      child: Text(
        label,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isActive ? Colors.white : AppColors.textSecondary),
      ),
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
