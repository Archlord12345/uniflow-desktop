import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/teaching_unit.dart';
import '../widgets/status_badge.dart';

/// Page "Gestion des UE" : cartes statistiques, recherche + filtres,
/// tableau riche des unités d'enseignement (crédits, heures, inscrits,
/// statut). Fidèle à la maquette "Gestion des UE".
///
/// Ce widget n'a pas de Scaffold/sidebar propre : il est affiché à
/// l'intérieur de [MainShell].
class TeachingUnitsScreen extends StatefulWidget {
  const TeachingUnitsScreen({super.key});

  @override
  State<TeachingUnitsScreen> createState() => _TeachingUnitsScreenState();
}

class _TeachingUnitsScreenState extends State<TeachingUnitsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final units = TeachingUnit.mockList;
    final totalUE = units.length;
    final actives = units.where((u) => u.statut == 'Active').length;
    final planifiees = units.where((u) => u.statut == 'Planifiée').length;
    final creditsTotal = units.fold<int>(0, (sum, u) => sum + u.credits);

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
                // ----- 4 cartes statistiques -----
                Row(
                  children: [
                    Expanded(
                      child: _UeStatCard(
                        icon: Icons.menu_book_outlined,
                        iconColor: AppColors.primaryBlue,
                        value: totalUE.toString(),
                        label: 'Total UE',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _UeStatCard(
                        icon: Icons.menu_book_outlined,
                        iconColor: AppColors.success,
                        value: actives.toString(),
                        label: 'Actives',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _UeStatCard(
                        icon: Icons.menu_book_outlined,
                        iconColor: const Color(0xFFF5A623),
                        value: planifiees.toString(),
                        label: 'Planifiées',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _UeStatCard(
                        icon: Icons.menu_book_outlined,
                        iconColor: const Color(0xFFA855F7),
                        value: creditsTotal.toString(),
                        label: 'Crédits totaux',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ----- Recherche + filtres + export -----
                _buildFiltersRow(),
                const SizedBox(height: 18),

                // ----- Tableau -----
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
                      ...units.asMap().entries.map(
                            (e) => _UnitRow(unit: e.value, isLast: e.key == units.length - 1),
                          ),
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
                Text('Gestion des UE', style: AppTextStyles.h1),
                SizedBox(height: 4),
                Text("Administration · Unités d'Enseignement 2026", style: AppTextStyles.body),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: ouvrir le formulaire de création d'UE
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nouvelle UE'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
          ),
        ],
      ),
    );
  }

  /// Rangée de recherche + 3 filtres déroulants (département, niveau,
  /// statut) + bouton Export.
  Widget _buildFiltersRow() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Rechercher par nom, code, enseignant...',
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
        Expanded(child: _FilterDropdown(label: 'Tous départements')),
        const SizedBox(width: 12),
        Expanded(child: _FilterDropdown(label: 'Tous niveaux')),
        const SizedBox(width: 12),
        Expanded(child: _FilterDropdown(label: 'Tous statuts')),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: () {
            // TODO: exporter la liste des UE (CSV/Excel)
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

  Widget _buildTableHeader() {
    const style = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.3);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.inputBorder))),
      child: const Row(
        children: [
          SizedBox(width: 70, child: Text('CODE', style: style)),
          Expanded(flex: 3, child: Text('UE', style: style)),
          Expanded(flex: 2, child: Text('DÉPARTEMENT', style: style)),
          SizedBox(width: 60, child: Text('NIVEAU', style: style)),
          SizedBox(width: 110, child: Text('TYPE', style: style)),
          Expanded(flex: 2, child: Text('ENSEIGNANT', style: style)),
          SizedBox(width: 60, child: Text('CRÉDITS', style: style)),
          SizedBox(width: 55, child: Text('HEURES', style: style)),
          SizedBox(width: 85, child: Text('INSCRITS', style: style)),
          SizedBox(width: 80, child: Text('STATUT', style: style)),
          SizedBox(width: 90, child: Text('ACTIONS', style: style)),
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
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.body.copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}

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

class _UnitRow extends StatelessWidget {
  final TeachingUnit unit;
  final bool isLast;

  const _UnitRow({required this.unit, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final taux = unit.tauxRemplissage;
    // Couleur du pourcentage d'inscription : vert si bien rempli, orange
    // si partiellement, rouge si vide (ex: UE tout juste planifiée).
    final tauxColor = taux == 0
        ? AppColors.danger
        : (taux >= 50 ? AppColors.success : const Color(0xFFF5A623));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: isLast
          ? null
          : const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.inputBorder))),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(unit.code, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primaryBlue)),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unit.intitule,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(unit.semestre, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
              ],
            ),
          ),
          Expanded(flex: 2, child: Text(unit.departement, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
          SizedBox(
            width: 60,
            child: Align(alignment: Alignment.centerLeft, child: StatusBadge(label: unit.niveau, backgroundColor: AppColors.inputFill, textColor: AppColors.textSecondary)),
          ),
          SizedBox(
            width: 110,
            child: Align(
              alignment: Alignment.centerLeft,
              child: StatusBadge(label: unit.type, backgroundColor: unit.typeColor),
            ),
          ),
          Expanded(flex: 2, child: Text(unit.enseignant, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis)),
          SizedBox(
            width: 60,
            child: Row(
              children: [
                const Icon(Icons.description_outlined, size: 13, color: AppColors.textMuted),
                const SizedBox(width: 3),
                Text(unit.credits.toString(), style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
          SizedBox(
            width: 55,
            child: Row(
              children: [
                const Icon(Icons.access_time, size: 13, color: AppColors.textMuted),
                const SizedBox(width: 3),
                Text('${unit.heures}h', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
          SizedBox(
            width: 85,
            child: Row(
              children: [
                const Icon(Icons.people_alt_outlined, size: 13, color: AppColors.textMuted),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    '${unit.inscrits}/${unit.placesTotal}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 3),
                Text('$taux%', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: tauxColor)),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            child: Align(alignment: Alignment.centerLeft, child: StatusBadge(label: unit.statut, backgroundColor: unit.statutColor)),
          ),
          SizedBox(
            width: 90,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_red_eye_outlined, size: 15),
                  color: AppColors.primaryBlue,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  onPressed: () {
                    // TODO: naviguer vers une page de détail UE
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  color: const Color(0xFFF5A623),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  onPressed: () {
                    // TODO: ouvrir le formulaire d'édition de l'UE
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 14),
                  color: AppColors.danger,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  onPressed: () {
                    // TODO: confirmer puis supprimer l'UE
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
