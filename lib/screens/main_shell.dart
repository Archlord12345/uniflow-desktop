import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_sidebar.dart';
import 'dashboard_screen.dart';
import 'students_screen.dart';
import 'programs_screen.dart';
import 'teachers_screen.dart';
import 'teaching_units_screen.dart';
import 'classrooms_screen.dart';
import 'schedule_screen.dart';
import 'management_screens.dart';
import 'academic_management_screens.dart';
import 'messaging_screen.dart';

/// Coquille principale de l'application une fois connecté : affiche la
/// sidebar fixe à gauche (jamais reconstruite lors du changement de page)
/// et la page active à droite.
///
/// Utiliser un shell unique évite de dupliquer la sidebar dans chaque écran
/// et permet de garder son état (ex: item sélectionné) au même endroit.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // Page actuellement affichée ; le dashboard est la page d'accueil par défaut.
  SidebarItem _selected = SidebarItem.dashboard;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          AppSidebar(
            selected: _selected,
            onSelect: (item) => setState(() => _selected = item),
          ),
          // Expanded : la zone de contenu occupe tout l'espace restant
          // à droite de la sidebar (largeur fixe).
          // AnimatedSwitcher anime la transition entre deux pages (fondu +
          // léger glissement vertical) au lieu d'un changement instantané et
          // sec — rend la navigation beaucoup plus "vivante".
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                final offsetAnimation = Tween<Offset>(
                  begin: const Offset(0, 0.02),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: offsetAnimation, child: child),
                );
              },
              // La clé change à chaque item sélectionné : c'est ce qui
              // indique à AnimatedSwitcher qu'il doit jouer la transition.
              child: KeyedSubtree(
                key: ValueKey(_selected),
                child: _buildContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Retourne l'écran correspondant à l'item sélectionné. Chaque entrée du
  /// référentiel Desktop possède désormais un écran navigable.
  Widget _buildContent() {
    switch (_selected) {
      case SidebarItem.dashboard:
        return const DashboardScreen();
      case SidebarItem.students:
        return const StudentsScreen();
      case SidebarItem.programs:
        return const ProgramsScreen();
      case SidebarItem.teachers:
        return const TeachersScreen();
      case SidebarItem.ue:
        return const TeachingUnitsScreen();
      case SidebarItem.classrooms:
        return const ClassroomsScreen();
      case SidebarItem.structure:
        return const StructureManagementScreen();
      case SidebarItem.schedule:
        return const ScheduleScreen();
      case SidebarItem.attendance:
        return const AttendanceScreen();
      case SidebarItem.assignments:
        return const AssignmentsManagementScreen();
      case SidebarItem.grades:
        return const GradesManagementScreen();
      case SidebarItem.library:
        return const LibraryManagementScreen();
      case SidebarItem.conferences:
        return const ConferencesScreen();
      case SidebarItem.sentinelle:
        return const SentinelleManagementScreen();
      case SidebarItem.teams:
        return const TeamsScreen();
      case SidebarItem.communications:
        return const MessagingScreen();
      case SidebarItem.payments:
        return const PaymentsManagementScreen();
      case SidebarItem.statistics:
        return const StatisticsScreen();
      case SidebarItem.settings:
        return const SettingsScreen();
      default:
        return _ComingSoonPlaceholder(label: _selected.label);
    }
  }
}

/// Repli de sécurité pour une future entrée ajoutée à la sidebar.
class _ComingSoonPlaceholder extends StatelessWidget {
  final String label;

  const _ComingSoonPlaceholder({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.construction_outlined, size: 40, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            'Page "$label" à venir',
            style: const TextStyle(fontSize: 15, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
