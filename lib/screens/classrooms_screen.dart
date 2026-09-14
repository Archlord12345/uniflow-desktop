import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../models/classroom.dart';
import '../providers/directory_provider.dart';
import '../widgets/app_page_bar.dart';
import '../widgets/data_state_view.dart';
import '../widgets/status_badge.dart';

/// Page "Salles" (Gestion des Salles).
///
/// Appwrite n'a pas de collection `classrooms` : les salles listées sont les
/// libellés réellement présents dans l'emploi du temps (`academic_schedules`),
/// agrégés avec leur nombre de créneaux et d'UE. La page affichait auparavant
/// cinq salles inventées avec des capacités et des bâtiments qui n'existent
/// nulle part en base, ainsi qu'une pagination factice.
///
/// Ce widget n'a pas de Scaffold/sidebar propre : il est affiché à
/// l'intérieur de [MainShell].
class ClassroomsScreen extends ConsumerStatefulWidget {
  const ClassroomsScreen({super.key});

  @override
  ConsumerState<ClassroomsScreen> createState() => _ClassroomsScreenState();
}

class _ClassroomsScreenState extends ConsumerState<ClassroomsScreen> {
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

  List<Classroom> _filtered(List<Classroom> classrooms) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return classrooms;
    return classrooms.where((room) {
      return room.nom.toLowerCase().contains(query) ||
          room.type.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final classroomsAsync = ref.watch(classroomsProvider);

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
                  child: classroomsAsync.when(
                    loading: () => const DataLoadingView(
                      label: 'Chargement de l\'emploi du temps…',
                    ),
                    error: (error, _) => DataErrorView(
                      error: error,
                      onRetry: () => ref.invalidate(classroomsProvider),
                    ),
                    data: (classrooms) => _buildTable(_filtered(classrooms)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTable(List<Classroom> classrooms) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTableHeader(),
        if (classrooms.isEmpty)
          DataEmptyView(
            icon: Icons.meeting_room_outlined,
            message: _searchController.text.trim().isEmpty
                ? 'Aucune salle planifiée.\nLes salles apparaissent ici dès qu\'un créneau d\'emploi du temps les référence.'
                : 'Aucune salle ne correspond à « ${_searchController.text.trim()} ».',
          )
        else
          ...classrooms.map((room) => _ClassroomRow(classroom: room)),
        _buildFooter(classrooms),
      ],
    );
  }

  Widget _buildTopBar() {
    return AppPageBar(
      breadcrumb: const ['Accueil', 'Salles'],
      subtitle: 'Salles réellement utilisées par l\'emploi du temps',
      actions: [
        ElevatedButton.icon(
          onPressed: () {
            // TODO: ouvrir le formulaire de création de salle — nécessite
            // d'abord une collection `classrooms` côté Appwrite.
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Ajouter salle'),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
        ),
      ],
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
          Expanded(flex: 3, child: Text('SALLE', style: style)),
          SizedBox(width: 120, child: Text('CRÉNEAUX', style: style)),
          SizedBox(width: 120, child: Text('UE PLANIFIÉES', style: style)),
          Expanded(flex: 2, child: Text('TYPE DE CRÉNEAU', style: style)),
        ],
      ),
    );
  }

  /// Pied de tableau : décompte réel des salles affichées.
  Widget _buildFooter(List<Classroom> classrooms) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Text(
            classrooms.length <= 1 ? '${classrooms.length} salle' : '${classrooms.length} salles',
            style: AppTextStyles.body.copyWith(fontSize: 13),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => ref.invalidate(classroomsProvider),
            icon: const Icon(Icons.refresh, size: 18),
            color: AppColors.textSecondary,
            tooltip: 'Recharger depuis Appwrite',
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
          Expanded(
            flex: 3,
            child: Row(
              children: [
                const Icon(Icons.meeting_room_outlined, size: 18, color: AppColors.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    classroom.nom,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              classroom.creneaux <= 1 ? '${classroom.creneaux} créneau' : '${classroom.creneaux} créneaux',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              classroom.cours.toString(),
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: classroom.type.isEmpty
                  ? const Text('—', style: TextStyle(fontSize: 13, color: AppColors.textMuted))
                  : StatusBadge(label: classroom.type, backgroundColor: AppColors.inputFill, textColor: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
