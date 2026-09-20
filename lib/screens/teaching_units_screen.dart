import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../models/teaching_unit.dart';
import '../providers/directory_provider.dart';
import '../widgets/data_state_view.dart';
import '../widgets/filter_dropdown.dart';
import '../widgets/status_badge.dart';

/// Page "Gestion des UE" : cartes statistiques, recherche + filtres,
/// tableau des unités d'enseignement.
///
/// Les UE sont lues dans `academic_courses` d'Appwrite (effectifs compris) ;
/// elles étaient auparavant codées en dur. Les colonnes dont la base ne
/// contient pas la donnée — semestre, capacité, statut — n'existent plus.
///
/// Ce widget n'a pas de Scaffold/sidebar propre : il est affiché à
/// l'intérieur de [MainShell].
class TeachingUnitsScreen extends ConsumerStatefulWidget {
  const TeachingUnitsScreen({super.key});

  @override
  ConsumerState<TeachingUnitsScreen> createState() =>
      _TeachingUnitsScreenState();
}

class _TeachingUnitsScreenState extends ConsumerState<TeachingUnitsScreen> {
  final _searchController = TextEditingController();
  String? _niveau;
  String? _departement;

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

  List<TeachingUnit> _filtered(List<TeachingUnit> units) {
    final query = _searchController.text.trim().toLowerCase();
    return units.where((unit) {
      if (_niveau != null && unit.niveau != _niveau) return false;
      if (_departement != null && unit.departement != _departement) {
        return false;
      }
      if (query.isEmpty) return true;
      return unit.intitule.toLowerCase().contains(query) ||
          unit.code.toLowerCase().contains(query) ||
          unit.enseignant.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final unitsAsync = ref.watch(teachingUnitsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTopBar(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: unitsAsync.when(
              loading: () => const DataLoadingView(
                label: 'Chargement des unités d\'enseignement…',
              ),
              error: (error, _) => DataErrorView(
                error: error,
                onRetry: () => ref.invalidate(teachingUnitsProvider),
              ),
              data: (units) => _buildContent(units),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(List<TeachingUnit> allUnits) {
    final units = _filtered(allUnits);

    // Les statistiques portent sur l'ensemble des UE, pas sur le résultat
    // filtré : elles décrivent le catalogue, pas la recherche en cours.
    final credits = allUnits.fold<int>(0, (sum, u) => sum + u.credits);
    final heures = allUnits.fold<int>(0, (sum, u) => sum + u.heures);
    final enseignants = allUnits
        .map((u) => u.enseignant)
        .where((name) => name.isNotEmpty)
        .toSet()
        .length;

    final niveaux = allUnits
        .map((u) => u.niveau)
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final departements = allUnits
        .map((u) => u.departement)
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
                child: _UeStatCard(
                    icon: Icons.menu_book_outlined,
                    iconColor: AppColors.primaryBlue,
                    value: allUnits.length.toString(),
                    label: 'Total UE')),
            const SizedBox(width: 16),
            Expanded(
                child: _UeStatCard(
                    icon: Icons.school_outlined,
                    iconColor: AppColors.success,
                    value: enseignants.toString(),
                    label: 'Enseignants')),
            const SizedBox(width: 16),
            Expanded(
                child: _UeStatCard(
                    icon: Icons.description_outlined,
                    iconColor: const Color(0xFFF5A623),
                    value: credits.toString(),
                    label: 'Crédits totaux')),
            const SizedBox(width: 16),
            Expanded(
                child: _UeStatCard(
                    icon: Icons.access_time,
                    iconColor: const Color(0xFFA855F7),
                    value: '${heures}h',
                    label: 'Heures totales')),
          ],
        ),
        const SizedBox(height: 20),
        _buildFiltersRow(niveaux, departements),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            // Le tableau aligne dix colonnes dont sept à largeur fixe : 595 px
            // incompressibles, plus la gouttière. Dans une fenêtre plus
            // étroite, `Row` n'avait d'autre issue que de déborder de 273 px.
            // Les colonnes ne se compriment pas sans devenir illisibles, et
            // les tronquer toutes reviendrait à ne plus rien montrer : la vue
            // défile donc horizontalement, comme n'importe quel tableau large.
            const double minTableWidth = 980;
            final width = constraints.maxWidth < minTableWidth
                ? minTableWidth
                : constraints.maxWidth;

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.inputBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTableHeader(),
                      if (units.isEmpty)
                        DataEmptyView(
                          icon: Icons.menu_book_outlined,
                          message: allUnits.isEmpty
                              ? 'Aucune UE dans `academic_courses`.\nLes unités apparaissent ici une fois créées.'
                              : 'Aucune UE ne correspond aux critères sélectionnés.',
                        )
                      else
                        ...units.asMap().entries.map(
                              (e) => _UnitRow(
                                  unit: e.value,
                                  isLast: e.key == units.length - 1),
                            ),
                      _buildFooter(units),
                    ],
                  ),
                ),
              ),
            );
          },
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
                Text('Gestion des UE', style: AppTextStyles.h1),
                SizedBox(height: 4),
                Text('Administration · Unités d\'Enseignement',
                    style: AppTextStyles.body),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: ouvrir le formulaire de création d'UE
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nouvelle UE'),
            style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersRow(List<String> niveaux, List<String> departements) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Rechercher par nom, code, enseignant...',
              hintStyle:
                  const TextStyle(color: AppColors.textMuted, fontSize: 14),
              prefixIcon: const Icon(Icons.search,
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
                  borderSide: const BorderSide(
                      color: AppColors.primaryBlue, width: 1.5)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilterDropdown(
            anyLabel: 'Tous départements',
            value: _departement,
            options: departements,
            onChanged: (value) => setState(() => _departement = value),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilterDropdown(
            anyLabel: 'Tous niveaux',
            value: _niveau,
            options: niveaux,
            onChanged: (value) => setState(() => _niveau = value),
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    const style = TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: 0.3);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.inputBorder))),
      child: const Row(
        children: [
          SizedBox(width: 80, child: Text('CODE', style: style)),
          Expanded(flex: 4, child: Text('UE', style: style)),
          Expanded(flex: 3, child: Text('PROGRAMME', style: style)),
          SizedBox(width: 100, child: Text('NIVEAU', style: style)),
          SizedBox(width: 120, child: Text('TYPE', style: style)),
          Expanded(flex: 3, child: Text('ENSEIGNANT', style: style)),
          SizedBox(width: 70, child: Text('CRÉDITS', style: style)),
          SizedBox(width: 65, child: Text('HEURES', style: style)),
          SizedBox(width: 80, child: Text('INSCRITS', style: style)),
          SizedBox(width: 80, child: Text('ACTIONS', style: style)),
        ],
      ),
    );
  }

  /// Pied de tableau : décompte réel des lignes affichées.
  Widget _buildFooter(List<TeachingUnit> units) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Text(
            units.length <= 1
                ? '${units.length} UE affichée'
                : '${units.length} UE affichées',
            style: AppTextStyles.body.copyWith(fontSize: 13),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => ref.invalidate(teachingUnitsProvider),
            icon: const Icon(Icons.refresh, size: 18),
            color: AppColors.textSecondary,
            tooltip: 'Recharger depuis Appwrite',
          ),
        ],
      ),
    );
  }
}

/// Petite carte statistique (icône + valeur + libellé), utilisée pour les
/// 4 cartes en haut de la page "Gestion des UE".
class _UeStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _UeStatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 14),
          Text(value,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.body.copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}

class _UnitRow extends StatelessWidget {
  final TeachingUnit unit;
  final bool isLast;

  const _UnitRow({required this.unit, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final taux = unit.tauxRemplissage;
    // Le pourcentage n'est affiché que si la capacité d'accueil est connue.
    final tauxColor = taux == null
        ? AppColors.textMuted
        : (taux == 0
            ? AppColors.danger
            : (taux >= 50 ? AppColors.success : const Color(0xFFF5A623)));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: isLast
          ? null
          : const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.inputBorder))),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              _orDash(unit.code),
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryBlue),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              _orDash(unit.intitule),
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(_orDash(unit.departement),
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
                overflow: TextOverflow.ellipsis),
          ),
          SizedBox(
            width: 100,
            child: Align(
              alignment: Alignment.centerLeft,
              child: StatusBadge(
                label: _orDash(unit.niveau),
                backgroundColor: AppColors.inputFill,
                textColor: AppColors.textSecondary,
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: Align(
              alignment: Alignment.centerLeft,
              child: unit.type.isEmpty
                  ? const Text('—',
                      style:
                          TextStyle(fontSize: 13, color: AppColors.textMuted))
                  : StatusBadge(
                      label: unit.type, backgroundColor: unit.typeColor),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(_orDash(unit.enseignant),
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
                overflow: TextOverflow.ellipsis),
          ),
          SizedBox(
            width: 70,
            child: Row(
              children: [
                const Icon(Icons.description_outlined,
                    size: 13, color: AppColors.textMuted),
                const SizedBox(width: 3),
                Text(unit.credits.toString(),
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
          SizedBox(
            width: 65,
            child: Row(
              children: [
                const Icon(Icons.access_time,
                    size: 13, color: AppColors.textMuted),
                const SizedBox(width: 3),
                Text('${unit.heures}h',
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            child: Row(
              children: [
                const Icon(Icons.people_alt_outlined,
                    size: 13, color: AppColors.textMuted),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    unit.inscrits.toString(),
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (taux != null) ...[
                  const SizedBox(width: 3),
                  Text('$taux%',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: tauxColor)),
                ],
              ],
            ),
          ),
          SizedBox(
            width: 80,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_red_eye_outlined, size: 15),
                  color: AppColors.primaryBlue,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 26, minHeight: 26),
                  tooltip: 'Voir le détail',
                  onPressed: () {
                    // TODO: naviguer vers une page de détail UE
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  color: const Color(0xFFF5A623),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 26, minHeight: 26),
                  tooltip: 'Modifier',
                  onPressed: () {
                    // TODO: ouvrir le formulaire d'édition de l'UE
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Un champ absent de la base s'affiche « — » plutôt que vide.
  static String _orDash(String value) => value.trim().isEmpty ? '—' : value;
}
