import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../models/program_tree.dart';
import '../providers/program_provider.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/status_badge.dart';
import '../widgets/simple_tab_bar.dart';

/// Page "Programmes & Facultés" : arborescence Université > Filière > Niveau
/// à gauche, détail du niveau sélectionné à droite.
///
/// L'arborescence est construite depuis les UE de `academic_courses` : il n'y
/// a plus de jeu de données d'exemple. Si la base est vide, la page le dit.
///
/// Comme les autres pages internes, ce widget n'a pas de Scaffold/sidebar
/// propre : il est affiché à l'intérieur de [MainShell].
class ProgramsScreen extends ConsumerStatefulWidget {
  const ProgramsScreen({super.key});

  @override
  ConsumerState<ProgramsScreen> createState() => _ProgramsScreenState();
}

class _ProgramsScreenState extends ConsumerState<ProgramsScreen> {
  /// Niveau sélectionné, identifié par « université|filière|code » : la liste
  /// est reconstruite à chaque rechargement, une référence directe deviendrait
  /// obsolète.
  String? _selectedKey;

  /// Éléments repliés. L'arborescence est dépliée par défaut : mémoriser les
  /// replis plutôt que les dépliages évite d'avoir à initialiser l'état une
  /// fois les données chargées.
  final Set<String> _collapsed = {};

  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static String _keyOf(FacultyNode faculty, DepartmentNode department, ProgramNode program) =>
      '${faculty.name}|${department.name}|${program.code}';

  @override
  Widget build(BuildContext context) {
    final treeAsync = ref.watch(programTreeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTopBar(
          title: 'Programmes & Facultés',
          subtitle: 'Hiérarchie des universités, filières et niveaux',
          actions: [
            TopBarIconButton(icon: Icons.search),
            TopBarIconButton(icon: Icons.notifications_none_rounded, showDot: true),
            ElevatedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('La création de programmes se fait depuis la '
                      'gestion des UE : chaque UE porte sa filière et son niveau.'),
                ),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Ajouter programme'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              ),
            ),
          ],
        ),
        Expanded(
          child: treeAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _Message(
              icon: Icons.cloud_off_outlined,
              title: 'Programmes indisponibles',
              message: '$error',
            ),
            data: (faculties) {
              if (faculties.isEmpty) {
                return const _Message(
                  icon: Icons.account_tree_outlined,
                  title: 'Aucune UE enregistrée',
                  message: 'L\'arborescence se construit à partir de la collection '
                      '« academic_courses » : chaque UE y porte une université, une '
                      'filière et un niveau. Ajoutez des UE pour voir la hiérarchie '
                      'apparaître ici.',
                );
              }
              return _buildBody(faculties);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBody(List<FacultyNode> faculties) {
    final visible = _filtered(faculties);
    final selected = _resolveSelected(visible) ?? _resolveSelected(faculties);

    return Row(
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
                Expanded(
                  child: visible.isEmpty
                      ? const Center(
                          child: Text(
                            'Aucun résultat pour cette recherche.',
                            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                          ),
                        )
                      : ListView(
                          children: [
                            for (final faculty in visible) _buildFacultyNode(faculty),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
        // ----- Panneau droit : détail du niveau sélectionné -----
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: selected == null
                ? const Text(
                    'Sélectionnez un niveau dans l\'arborescence.',
                    style: TextStyle(color: AppColors.textMuted),
                  )
                : _ProgramDetailPanel(program: selected),
          ),
        ),
      ],
    );
  }

  /// Restreint l'arborescence aux niveaux dont le libellé, la filière ou le
  /// code contient la recherche. Les parents d'un niveau retenu sont conservés
  /// pour garder la hiérarchie lisible.
  List<FacultyNode> _filtered(List<FacultyNode> faculties) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return faculties;

    final result = <FacultyNode>[];
    for (final faculty in faculties) {
      final departments = <DepartmentNode>[];
      for (final department in faculty.departments) {
        final programs = department.programs
            .where((program) =>
                program.name.toLowerCase().contains(query) ||
                program.program.toLowerCase().contains(query) ||
                program.code.toLowerCase().contains(query))
            .toList();
        if (programs.isNotEmpty) {
          departments.add(DepartmentNode(name: department.name, programs: programs));
        }
      }
      if (departments.isNotEmpty) {
        result.add(FacultyNode(name: faculty.name, departments: departments));
      }
    }
    return result;
  }

  /// Le niveau sélectionné s'il existe encore, sinon le premier de la liste.
  ProgramNode? _resolveSelected(List<FacultyNode> faculties) {
    final key = _selectedKey;
    for (final faculty in faculties) {
      for (final department in faculty.departments) {
        for (final program in department.programs) {
          if (key == null || _keyOf(faculty, department, program) == key) {
            return program;
          }
        }
      }
    }
    return null;
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _query = value),
      decoration: InputDecoration(
        hintText: 'Rechercher une filière, un niveau...',
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textMuted),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
              ),
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

  bool _isExpanded(String key) => !_collapsed.contains(key);

  void _toggle(String key) {
    setState(() {
      if (_collapsed.contains(key)) {
        _collapsed.remove(key);
      } else {
        _collapsed.add(key);
      }
    });
  }

  Widget _buildFacultyNode(FacultyNode faculty) {
    // Une recherche en cours force le dépli, sinon les résultats resteraient
    // cachés derrière une faculté repliée.
    final isExpanded = _query.isNotEmpty || _isExpanded(faculty.name);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _toggle(faculty.name),
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
        // Filières affichées uniquement si l'université est dépliée, avec un
        // léger décalage + une ligne verticale pour marquer la hiérarchie.
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
                  for (final department in faculty.departments)
                    _buildDepartmentNode(faculty, department),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDepartmentNode(FacultyNode faculty, DepartmentNode department) {
    final isExpanded = _query.isNotEmpty || _isExpanded(department.name);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _toggle(department.name),
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
                    department.name,
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
                for (final program in department.programs)
                  _buildProgramLeaf(faculty, department, program),
              ],
            ),
          ),
      ],
    );
  }

  /// Feuille de l'arborescence : un niveau cliquable qui met à jour le panneau
  /// de détail. Mis en surbrillance s'il est le niveau affiché.
  Widget _buildProgramLeaf(FacultyNode faculty, DepartmentNode department, ProgramNode program) {
    final isSelected = _selectedKey == _keyOf(faculty, department, program);

    return InkWell(
      onTap: () => setState(() => _selectedKey = _keyOf(faculty, department, program)),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEAF1FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3))
              : null,
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
            Text(
              '${program.ueCount}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Panneau de droite : en-tête, chiffres du niveau, onglets, liste des UE.
class _ProgramDetailPanel extends StatefulWidget {
  final ProgramNode program;

  const _ProgramDetailPanel({required this.program});

  @override
  State<_ProgramDetailPanel> createState() => _ProgramDetailPanelState();
}

class _ProgramDetailPanelState extends State<_ProgramDetailPanel> {
  int _selectedTab = 0;
  static const _tabs = ['Unités d\'enseignement', 'Enseignants'];

  @override
  void didUpdateWidget(covariant _ProgramDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Changer de niveau remet l'onglet sur les UE : rester sur « Enseignants »
    // ferait perdre le contexte de ce qu'on vient d'ouvrir.
    if (oldWidget.program.code != widget.program.code ||
        oldWidget.program.program != widget.program.program) {
      _selectedTab = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final program = widget.program;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ----- En-tête : niveau, filière, code -----
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${program.program} — ${program.name}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const StatusBadge(label: 'NIVEAU', backgroundColor: Color(0xFFDFF5E4)),
                const SizedBox(width: 8),
                Text('• Code : ${program.code}', style: AppTextStyles.body),
              ],
            ),
          ],
        ),
        const SizedBox(height: 28),

        // ----- Fiche + chiffres du niveau -----
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel('DÉTAILS DU NIVEAU'),
                  const SizedBox(height: 14),
                  _DetailRow(label: 'Filière', value: program.program),
                  _DetailRow(label: 'Niveau', value: program.name),
                  _DetailRow(label: 'Code', value: program.code),
                  _DetailRow(
                    label: 'Enseignants',
                    value: program.teachers.isEmpty
                        ? '—'
                        : '${program.teachers.length}',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 32),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel('STATISTIQUES'),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _StatBox(
                          label: 'Étudiants inscrits',
                          value: program.studentsCount.toString(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatBox(
                          label: 'Unités (UE)',
                          value: program.ueCount.toString(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),

        SimpleTabBar(
          tabs: _tabs,
          selectedIndex: _selectedTab,
          onTabSelected: (index) => setState(() => _selectedTab = index),
        ),
        const SizedBox(height: 20),

        if (_selectedTab == 0)
          program.modules.isEmpty
              ? const _Panel(
                  child: Text(
                    'Aucune UE enregistrée pour ce niveau.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                )
              : _buildModulesTable(program.modules)
        else
          _buildTeachers(program.teachers),
      ],
    );
  }

  Widget _buildModulesTable(List<CurriculumModule> modules) {
    const headerStyle = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.4);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Expanded(flex: 4, child: Text('MODULE', style: headerStyle)),
                Expanded(flex: 2, child: Text('CODE', style: headerStyle)),
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
                      flex: 4,
                      child: Text(module.name, style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(module.code, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
      ),
    );
  }

  Widget _buildTeachers(List<String> teachers) {
    if (teachers.isEmpty) {
      return const _Panel(
        child: Text(
          'Aucun enseignant renseigné sur les UE de ce niveau.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final teacher in teachers)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.inputFill,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.person_outline, size: 17, color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        teacher,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.4),
      );
}

/// Carte neutre pour les messages d'état.
class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: child,
      );
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.body),
          Text(
            value,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
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

/// État vide pleine page : icône, titre, explication.
class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _Message({required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      // `SingleChildScrollView` et non `Padding` : ce message occupe la hauteur
      // restante d'un `Expanded`, et à ×1.3 son contenu (icône, titre,
      // explication sur plusieurs lignes) réclame 401 px dans une fenêtre de
      // 620 qui n'en laisse que 319. Le bloc défile plutôt que de déborder.
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.textMuted),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
