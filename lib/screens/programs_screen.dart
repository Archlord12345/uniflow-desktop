import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/program_tree.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/status_badge.dart';
import '../widgets/simple_tab_bar.dart';

/// Page "Programmes & Facultés" : arborescence Faculté > Département >
/// Programme à gauche, panneau de détail du programme sélectionné à droite.
///
/// Comme les autres pages internes, ce widget n'a pas de Scaffold/sidebar
/// propre : il est affiché à l'intérieur de [MainShell].
class ProgramsScreen extends StatefulWidget {
  const ProgramsScreen({super.key});

  @override
  State<ProgramsScreen> createState() => _ProgramsScreenState();
}

class _ProgramsScreenState extends State<ProgramsScreen> {
  // Programme actuellement affiché dans le panneau de droite.
  // On démarre directement sur "Licence Informatique" pour matcher la maquette.
  ProgramNode _selectedProgram = ProgramTreeData.licenceInformatique;

  // Suit quelles facultés/départements sont actuellement dépliés dans
  // l'arborescence. On utilise le nom comme clé pour simplifier (à
  // remplacer par un id stable si deux entités pouvaient avoir le même nom).
  final Set<String> _expandedFaculties = {'Faculté des Sciences'};
  final Set<String> _expandedDepartments = {"Département d'Informatique"};

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTopBar(
          title: 'Programmes & Facultés',
          subtitle: 'Hiérarchie des facultés, départements et programmes',
          actions: [
            TopBarIconButton(icon: Icons.search),
            TopBarIconButton(icon: Icons.notifications_none_rounded, showDot: true),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: ouvrir le formulaire de création de programme
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Ajouter programme'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              ),
            ),
          ],
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ----- Panneau gauche : recherche + arborescence -----
              SizedBox(
                width: 360,
                child: Container(
                  decoration: const BoxDecoration(
                    border: Border(right: BorderSide(color: AppColors.inputBorder)),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSearchField(),
                      const SizedBox(height: 20),
                      Expanded(child: _buildTree()),
                    ],
                  ),
                ),
              ),
              // ----- Panneau droit : détail du programme sélectionné -----
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: _ProgramDetailPanel(program: _selectedProgram),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Rechercher une entité...',
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.cardWhite,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
        ),
      ),
    );
  }

  /// Construit l'arborescence complète : une entrée par faculté, chacune
  /// pouvant être dépliée pour révéler ses départements, eux-mêmes
  /// dépliables pour révéler leurs programmes.
  Widget _buildTree() {
    return ListView(
      children: [
        for (final faculty in ProgramTreeData.faculties) _buildFacultyNode(faculty),
      ],
    );
  }

  Widget _buildFacultyNode(FacultyNode faculty) {
    final isExpanded = _expandedFaculties.contains(faculty.name);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() {
            if (isExpanded) {
              _expandedFaculties.remove(faculty.name);
            } else {
              _expandedFaculties.add(faculty.name);
            }
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                  size: 18,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                const Icon(Icons.account_balance_outlined, size: 18, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    faculty.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Départements affichés uniquement si la faculté est dépliée,
        // avec un léger décalage + une ligne verticale pour marquer la hiérarchie.
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Container(
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: AppColors.inputBorder)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final dept in faculty.departments) _buildDepartmentNode(dept),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDepartmentNode(DepartmentNode dept) {
    final isExpanded = _expandedDepartments.contains(dept.name);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() {
            if (isExpanded) {
              _expandedDepartments.remove(dept.name);
            } else {
              _expandedDepartments.add(dept.name);
            }
          }),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                  size: 16,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    dept.name,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final program in dept.programs) _buildProgramLeaf(program),
              ],
            ),
          ),
      ],
    );
  }

  /// Feuille de l'arborescence : un programme cliquable qui met à jour
  /// le panneau de détail à droite. Mis en surbrillance bleue s'il
  /// correspond au programme actuellement sélectionné.
  Widget _buildProgramLeaf(ProgramNode program) {
    final isSelected = program.name == _selectedProgram.name;

    return InkWell(
      onTap: () => setState(() => _selectedProgram = program),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEAF1FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: AppColors.primaryBlue.withOpacity(0.3)) : null,
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              size: 15,
              color: isSelected ? AppColors.primaryBlue : AppColors.textMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                program.name,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  color: isSelected ? AppColors.primaryBlue : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Panneau de droite affichant le détail complet du programme sélectionné :
/// en-tête, statistiques, onglets, curriculum par semestre.
class _ProgramDetailPanel extends StatefulWidget {
  final ProgramNode program;

  const _ProgramDetailPanel({required this.program});

  @override
  State<_ProgramDetailPanel> createState() => _ProgramDetailPanelState();
}

class _ProgramDetailPanelState extends State<_ProgramDetailPanel> {
  int _selectedTab = 0;
  static const _tabs = ['Curriculum (Semestres)', 'Enseignants', 'Prérequis', 'Documents'];

  // Suit quels semestres sont actuellement dépliés (affichent leurs modules).
  final Set<String> _expandedSemesters = {};

  @override
  void didUpdateWidget(covariant _ProgramDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Quand on change de programme sélectionné dans l'arbre, on réinitialise
    // les semestres dépliés pour éviter d'afficher un état incohérent.
    if (oldWidget.program.name != widget.program.name) {
      _expandedSemesters.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final program = widget.program;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ----- En-tête : nom, statut, id, boutons éditer/supprimer -----
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    program.name,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      StatusBadge(
                        label: program.isActive ? 'ACTIF' : 'INACTIF',
                        backgroundColor: program.isActive ? const Color(0xFFDFF5E4) : const Color(0xFFFFE0E9),
                      ),
                      const SizedBox(width: 8),
                      Text('• ID: ${program.id}', style: AppTextStyles.body),
                    ],
                  ),
                ],
              ),
            ),
            _SquareIconButton(icon: Icons.edit_outlined, onTap: () {}),
            const SizedBox(width: 10),
            _SquareIconButton(icon: Icons.delete_outline, onTap: () {}, isDanger: true),
          ],
        ),
        const SizedBox(height: 28),

        // ----- Détails du programme + statistiques rapides -----
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DÉTAILS DU PROGRAMME',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.4),
                  ),
                  const SizedBox(height: 14),
                  _DetailRow(label: 'Code', value: program.code),
                  _DetailRow(label: 'Niveau', value: program.niveau),
                  _DetailRow(label: 'Durée', value: program.duree),
                  _DetailRow(label: 'Responsable', value: program.responsable, isLink: true),
                ],
              ),
            ),
            const SizedBox(width: 32),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'STATISTIQUES RAPIDES',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.4),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _StatBox(label: 'Étudiants', value: program.studentsCount.toString())),
                      const SizedBox(width: 12),
                      Expanded(child: _StatBox(label: 'Matières (UE)', value: program.ueCount.toString())),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),

        // ----- Onglets -----
        SimpleTabBar(
          tabs: _tabs,
          selectedIndex: _selectedTab,
          onTabSelected: (i) => setState(() => _selectedTab = i),
        ),
        const SizedBox(height: 20),

        if (_selectedTab == 0)
          Column(
            children: [
              for (final semester in program.semesters) _buildSemesterCard(semester),
            ],
          )
        else
          Container(
            padding: const EdgeInsets.all(40),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.inputBorder),
            ),
            child: Text(
              '${_tabs[_selectedTab]} — contenu à venir',
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
      ],
    );
  }

  /// Une carte de semestre : en-tête toujours visible (avec compteurs),
  /// et tableau des modules affiché seulement si des modules sont fournis
  /// ou si l'utilisateur a cliqué pour déplier ce semestre.
  Widget _buildSemesterCard(CurriculumSemester semester) {
    final hasModulesData = semester.modules.isNotEmpty;
    final isExpanded = _expandedSemesters.contains(semester.label);
    final showModules = hasModulesData || isExpanded;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: hasModulesData
                ? null
                : () => setState(() => _expandedSemesters.add(semester.label)),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: showModules
                  ? const BoxDecoration(
                      color: AppColors.inputFill,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    )
                  : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(semester.label, style: AppTextStyles.h2),
                  Text(
                    '${semester.totalModules} Modules • ${semester.totalEcts} ECTS',
                    style: AppTextStyles.body,
                  ),
                ],
              ),
            ),
          ),
          if (showModules && hasModulesData) _buildModulesTable(semester.modules),
          if (!showModules)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Cliquez pour voir les détails des modules du ${semester.label.toLowerCase()}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
            ),
          if (showModules && !hasModulesData)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Aucun module renseigné pour ce semestre pour le moment.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModulesTable(List<CurriculumModule> modules) {
    const headerStyle = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.4);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Expanded(flex: 3, child: Text('MODULE', style: headerStyle)),
              Expanded(flex: 2, child: Text('TYPE', style: headerStyle)),
              Expanded(child: Text('CRÉDITS', style: headerStyle, textAlign: TextAlign.right)),
            ],
          ),
          const SizedBox(height: 12),
          for (final module in modules)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(module.name, style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: StatusBadge(label: module.type, backgroundColor: module.typeColor),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      module.credits.toString(),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLink;

  const _DetailRow({required this.label, required this.value, this.isLink = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.body),
          Row(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: isLink ? AppColors.primaryBlue : AppColors.textPrimary,
                ),
              ),
              if (isLink) ...[
                const SizedBox(width: 4),
                const Icon(Icons.open_in_new, size: 13, color: AppColors.primaryBlue),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;

  const _StatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDanger;

  const _SquareIconButton({required this.icon, required this.onTap, this.isDanger = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.inputBorder),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: isDanger ? AppColors.danger : AppColors.textSecondary),
      ),
    );
  }
}
