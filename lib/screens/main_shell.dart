import 'dart:async';

import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_destination.dart';
import '../providers/appwrite_provider.dart';
import '../providers/auth_provider.dart';
import '../router/route_guard.dart';
import '../ui/ui.dart';
import 'academic_management_screens.dart';
import 'access_denied_screen.dart';
import 'accounts_screen.dart';
import 'attendance_screen.dart';
import 'classrooms_screen.dart';
import 'dashboard_screen.dart';
import 'management_screens.dart';
import 'messaging_screen.dart';
import 'notifications_screen.dart';
import 'personal_workspace_screen.dart';
import 'programs_screen.dart';
import 'schedule_screen.dart';
import 'session_flow.dart';
import 'students_screen.dart';
import 'teachers_screen.dart';
import 'teaching_units_screen.dart';
import 'teams_screen.dart';

/// Destination courante de la coquille, partagée pour que n'importe quel écran
/// (une fiche, un bouton « voir mes devoirs ») puisse demander une navigation
/// sans tenir la coquille par la main.
final currentDestinationProvider =
    StateProvider<AppDestination?>((ref) => null);

/// Coquille principale une fois connecté : barre latérale à gauche (repliée en
/// rail sur une fenêtre étroite), écran actif à droite.
///
/// **Toute** destination passe par la garde [canAccess] : si l'écran demandé
/// est refusé au couple (rôle, type de compte), c'est l'écran « accès refusé »
/// qui s'affiche, jamais l'écran lui-même. La barre latérale ne propose que
/// les écrans autorisés, mais la coquille ne s'y fie pas : une destination
/// peut venir d'ailleurs.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  /// Intervalle entre deux vérifications de session. Un jeton Appwrite
  /// révoqué depuis la console ou expiré laissait la coquille ouverte avec des
  /// listes qui échouaient une à une ; on préfère renvoyer à la connexion.
  static const Duration sessionCheckInterval = Duration(minutes: 5);

  @override
  ConsumerState<MainShell> createState() => _MainShellState();

  /// Écran de chaque destination. Le `switch` est exhaustif : ajouter une
  /// destination sans écran ne compile pas, ce qui remplace l'ancien repli
  /// « page à venir ».
  static Widget buildDestination(AppDestination destination) =>
      _buildDestination(destination);
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer =
        Timer.periodic(MainShell.sessionCheckInterval, (_) => _verifySession());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _verifySession();
  }

  Future<void> _verifySession() async {
    if (_checking || ref.read(currentUserProvider) == null) return;
    _checking = true;
    try {
      await ref.read(appwriteServiceProvider).account.get();
    } on AppwriteException catch (error) {
      // Seul un 401 signe une session morte ; une coupure réseau (code 0,
      // 5xx) ne doit pas éjecter l'utilisateur.
      if (error.code == 401 && mounted) {
        showFeedback(context,
            message: 'Session expirée',
            detail: 'Reconnectez-vous pour continuer.',
            success: false);
        await signOutToLogin(context, ref);
      }
    } catch (_) {
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentRoleProvider);
    final accountType = ref.watch(currentAccountTypeProvider);
    final home = homeDestination(role: role, accountType: accountType);
    final selected = ref.watch(currentDestinationProvider) ?? home;
    final allowed = canAccess(selected, role: role, accountType: accountType);

    void select(AppDestination destination) =>
        ref.read(currentDestinationProvider.notifier).state = destination;

    return AppShell(
      selected: selected,
      onSelect: select,
      body: AnimatedSwitcher(
        duration: kMotionMedium,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: pageTransition,
        child: KeyedSubtree(
          key: ValueKey('${selected.id}-$allowed'),
          child: allowed
              ? _buildDestination(selected)
              : AccessDeniedScreen(
                  destination: selected,
                  role: role,
                  accountType: accountType,
                  onBackHome: () => select(home),
                ),
        ),
      ),
    );
  }
}

Widget _buildDestination(AppDestination destination) {
  switch (destination) {
    case AppDestination.dashboard:
      return const DashboardScreen();
    case AppDestination.personalWorkspace:
      return const PersonalWorkspaceScreen();
    case AppDestination.notifications:
      return const NotificationsScreen();
    case AppDestination.students:
      return const StudentsScreen();
    case AppDestination.programs:
      return const ProgramsScreen();
    case AppDestination.teachers:
      return const TeachersScreen();
    case AppDestination.teachingUnits:
      return const TeachingUnitsScreen();
    case AppDestination.classrooms:
      return const ClassroomsScreen();
    case AppDestination.structure:
      return const StructureManagementScreen();
    case AppDestination.schedule:
      return const ScheduleScreen();
    case AppDestination.attendance:
      return const AttendanceScreen();
    case AppDestination.assignments:
      return const AssignmentsManagementScreen();
    case AppDestination.grades:
      return const GradesManagementScreen();
    case AppDestination.library:
      return const LibraryManagementScreen();
    case AppDestination.conferences:
      return const ConferencesScreen();
    case AppDestination.sentinelle:
      return const SentinelleManagementScreen();
    case AppDestination.teams:
      return const TeamsScreen();
    case AppDestination.messaging:
      return const MessagingScreen();
    case AppDestination.payments:
      return const PaymentsManagementScreen();
    case AppDestination.accounts:
      return const AccountsScreen();
    case AppDestination.statistics:
      return const StatisticsScreen();
    case AppDestination.settings:
      return const SettingsScreen();
  }
}
