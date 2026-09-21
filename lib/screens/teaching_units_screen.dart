import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../models/teaching_unit.dart';
import '../providers/directory_provider.dart';
import '../ui/app_data_table.dart';
import '../ui/status_badge.dart';
import '../ui/table_action_icon.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/data_state_view.dart';
import '../widgets/filter_dropdown.dart';

/// Page "Gestion des UE" : cartes statistiques, recherche + filtres,
/// tableau des unités d'enseignement.
///
/// Les UE sont lues dans `academic_courses` d'Appwrite (effectifs compris) ;
/// elles étaient auparavant codées en dur. Les colonnes dont la base ne
/// contient pas la donnée — semestre, capacité, statut — n'existent plus.
///
/// Ce widget n'a pas de Scaffold/sidebar propre : il est affiché à
/// l'intérieur de [MainShell]. En-tête [AppTopBar] et tableau [AppDataTable]
/// comme les autres pages de gestion : la page avait sa propre barre de titre
/// et son propre tableau, qui différaient de ceux d'à côté par la graisse de
/// l'en-tête et l'absence de fond gris.
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
                    iconColor: AppColors.warning,
                    value: credits.toString(),
                    label: 'Crédits totaux')),
            const SizedBox(width: 16),
            Expanded(
                child: _UeStatCard(
                    icon: Icons.access_time,
                    iconColor: AppColors.purple,
                    value: '${heures}h',
                    label: 'Heures totales')),
          ],
        ),
        const SizedBox(height: 20),
        _buildFiltersRow(niveaux, departements),
        const SizedBox(height: 18),
        _buildTable(units, allUnits),
      ],
    );
  }

  /// Le tableau aligne dix colonnes dont sept à largeur fixe : 595 px
  /// incompressibles, plus neuf gouttières et les marges. Dans une fenêtre
  /// plus étroite, `Row` n'avait d'autre issue que de déborder de 273 px ;
  /// sous ce seuil le tableau défile horizontalement.
  static const double _minTableWidth = 1000;

  /// Colonnes de la planche « UE » ; les compteurs (crédits, heures, inscrits)
  /// ont une largeur fixe pour rester alignés d'une ligne à l'autre.
  static final List<AppColumn> _columns = [
    const AppColumn('Code', width: 80),
    const AppColumn('UE', flex: 4),
    const AppColumn('Programme', flex: 3),
    const AppColumn('Niveau', width: 100),
    const AppColumn('Type', width: 120),
    const AppColumn('Enseignant', flex: 3),
    const AppColumn('Crédits', width: 70),
    const AppColumn('Heures', width: 65),
    const AppColumn('Inscrits', width: 80),
    AppColumn('Actions', width: TableActionIcon.columnWidth(2)),
  ];

  Widget _buildTable(List<TeachingUnit> units, List<TeachingUnit> allUnits) {
    return AppDataTable<TeachingUnit>(
      columns: _columns,
      rows: units,
      minWidth: _minTableWidth,
      cells: (unit, _) => _UnitRow.cells(unit),
      empty: DataEmptyView(
        icon: Icons.menu_book_outlined,
        message: allUnits.isEmpty
            ? 'Aucune UE dans `academic_courses`.\nLes unités apparaissent ici une fois créées.'
            : 'Aucune UE ne correspond aux critères sélectionnés.',
      ),
      footer: AppTableFooter(
        label: AppTableFooter.count(units.length, 'UE affichée'),
        actions: [
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

  Widget _buildTopBar() {
    return AppTopBar(
      title: 'Gestion des UE',
      subtitle: 'Administration · Unités d\'Enseignement',
      actions: [
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

/// Cellules d'une ligne du tableau des UE, dans l'ordre de
/// `_TeachingUnitsScreenState._columns`.
abstract final class _UnitRow {
  static const _muted =
      TextStyle(fontSize: 13, color: AppColors.textSecondary);
  static const _counter =
      TextStyle(fontSize: 12.5, color: AppColors.textSecondary);

  static List<Widget> cells(TeachingUnit unit) {
    final taux = unit.tauxRemplissage;
    // Le pourcentage n'est affiché que si la capacité d'accueil est connue.
    final tauxColor = taux == null
        ? AppColors.textMuted
        : (taux == 0
            ? AppColors.danger
            : (taux >= 50 ? AppColors.success : AppColors.warning));

    return [
      Text(
        _orDash(unit.code),
        style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryBlue),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      Text(
        _orDash(unit.intitule),
        style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      Text(_orDash(unit.departement),
          style: _muted, maxLines: 1, overflow: TextOverflow.ellipsis),
      StatusBadge(label: _orDash(unit.niveau)),
      unit.type.isEmpty
          ? const Text('—',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted))
          : StatusBadge.fromStatus(unit.type),
      Text(_orDash(unit.enseignant),
          style: _muted, maxLines: 1, overflow: TextOverflow.ellipsis),
      _counterCell(Icons.description_outlined, unit.credits.toString()),
      _counterCell(Icons.access_time, '${unit.heures}h'),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_alt_outlined,
              size: 13, color: AppColors.textMuted),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              unit.inscrits.toString(),
              style: _counter,
              maxLines: 1,
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
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TableActionIcon(
            icon: Icons.remove_red_eye_outlined,
            color: AppColors.primaryBlue,
            tooltip: 'Voir le détail',
            onPressed: () {
              // TODO: naviguer vers une page de détail UE
            },
          ),
          TableActionIcon(
            icon: Icons.edit_outlined,
            color: AppColors.warning,
            tooltip: 'Modifier',
            onPressed: () {
              // TODO: ouvrir le formulaire d'édition de l'UE
            },
          ),
        ],
      ),
    ];
  }

  static Widget _counterCell(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textMuted),
        const SizedBox(width: 3),
        Text(value, style: _counter),
      ],
    );
  }

  /// Un champ absent de la base s'affiche « — » plutôt que vide.
  static String _orDash(String value) => value.trim().isEmpty ? '—' : value;
}
