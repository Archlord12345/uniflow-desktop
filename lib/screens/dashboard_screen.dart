import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_destination.dart';
import '../models/appwrite_models.dart';
import '../models/dashboard_models.dart';
import '../models/dashboard_overview.dart';
import '../models/user_role.dart';
import '../providers/analytics_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/directory_provider.dart';
import '../providers/navigation_provider.dart';
import '../repositories/academic_repository.dart';
import '../router/route_guard.dart';
import '../theme/app_theme.dart';
import '../ui/app_button.dart';
import '../utils/french_date.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/data_state_view.dart';
import '../widgets/stat_card.dart';

/// Chiffres du tableau de bord d'un apprenant ou d'un enseignant, dans son
/// périmètre. L'administration ne s'en sert pas : elle a ses compteurs
/// globaux ([dashboardStatsProvider]) et ses graphiques.
final dashboardOverviewProvider =
    FutureProvider<DashboardOverview>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return DashboardOverview.empty;
  final repository = ref.watch(academicRepositoryProvider);
  final (courses, assignments, grades, attendance, students) = await (
    ref.watch(scopedCoursesProvider.future),
    repository.getAssignments(),
    repository.getAllGrades(),
    ref.watch(studentAttendanceProvider.future),
    ref.watch(studentsProvider.future),
  ).wait;
  return DashboardOverview.compute(
    role: user.userRole,
    userId: user.id,
    courses: courses,
    assignments: assignments,
    grades: grades,
    attendance: attendance,
    studentCount: students.length,
  );
});

final dashboardStatsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  // Recalculé à chaque changement de compte : les caches du compte précédent
  // survivaient à la déconnexion.
  ref.watch(currentUserProvider.select((u) => u?.id));
  return ref.read(academicRepositoryProvider).getGlobalStats();
});

/// Inscriptions des 6 derniers mois, comptées depuis `academic_enrollments`.
final dashboardEnrollmentsProvider =
    FutureProvider<List<MonthlyCount>>((ref) async {
  // Recalculé à chaque changement de compte : les caches du compte précédent
  // survivaient à la déconnexion.
  ref.watch(currentUserProvider.select((u) => u?.id));
  return ref.read(academicRepositoryProvider).getEnrollmentsByMonth();
});

/// Répartition des présences. `null` = pas de données exploitables, ce que la
/// carte distingue explicitement d'un taux nul.
final dashboardAttendanceProvider =
    FutureProvider<AttendanceBreakdown?>((ref) async {
  // Recalculé à chaque changement de compte : les caches du compte précédent
  // survivaient à la déconnexion.
  ref.watch(currentUserProvider.select((u) => u?.id));
  return ref.read(academicRepositoryProvider).getAttendanceBreakdown();
});

/// Derniers documents créés, toutes collections confondues.
final dashboardActivityProvider =
    FutureProvider<List<ActivityEntry>>((ref) async {
  // Recalculé à chaque changement de compte : les caches du compte précédent
  // survivaient à la déconnexion.
  ref.watch(currentUserProvider.select((u) => u?.id));
  return ref.read(academicRepositoryProvider).getRecentActivity();
});

/// Tableau de bord, par rôle.
///
/// Même contenu que le web pour le même compte : l'administration voit les
/// compteurs de l'établissement, les inscriptions et les présences
/// (`AdminDashboardPage.tsx`) ; un apprenant ou un enseignant voit **ses**
/// cours, devoirs, notes et présences (`DashboardPage.tsx`). Le desktop
/// affichait auparavant les compteurs d'administration à tout le monde, y
/// compris à un étudiant, qui découvrait ainsi les effectifs de tout
/// l'établissement.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  /// Raccourcis proposés sous les indicateurs, par rôle. Filtrés ensuite par
  /// la garde de navigation pour qu'un compte personnel ne voie jamais un
  /// écran d'établissement.
  static const Map<UserRole, List<AppDestination>> quickActions = {
    UserRole.student: [
      AppDestination.schedule,
      AppDestination.assignments,
      AppDestination.grades,
      AppDestination.library,
    ],
    UserRole.delegate: [
      AppDestination.schedule,
      AppDestination.attendance,
      AppDestination.assignments,
      AppDestination.students,
    ],
    UserRole.teacher: [
      AppDestination.schedule,
      AppDestination.attendance,
      AppDestination.assignments,
      AppDestination.grades,
    ],
    UserRole.admin: [
      AppDestination.accounts,
      AppDestination.teachers,
      AppDestination.schedule,
      AppDestination.statistics,
    ],
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final role = ref.watch(currentRoleProvider);
    final accountType = ref.watch(currentAccountTypeProvider);

    final actions = [
      for (final destination in quickActions[role] ?? const <AppDestination>[])
        if (canAccess(destination, role: role, accountType: accountType))
          destination,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // La barre recherche + cloche + avatar qui coiffait cet écran a été
        // retirée : la recherche ne cherchait rien, la cloche n'ouvrait rien,
        // et l'avatar doublait celui de la barre latérale. Le web ouvre son
        // tableau de bord sur un salut personnalisé ; on fait de même.
        _DashboardHeader(user: user, role: role),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (role.isAdmin)
                  const _AdminStats()
                else
                  _RoleStats(role: role),
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _QuickActions(destinations: actions),
                ],
                if (role.isAdmin) ...[
                  const SizedBox(height: AppSpacing.lg),

                  // ----- Graphique des inscriptions + graphique en anneau -----
                  // Côte à côte quand la fenêtre est assez large, empilés sinon :
                  // deux graphiques dans une fenêtre étroite deviennent
                  // illisibles.
                  const _ResponsiveRow(
                    breakpoint: 900,
                    left: _EnrollmentChartCard(),
                    right: _AttendanceDonutCard(),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ----- Activités récentes (pleine largeur) -----
                  const _RecentActivityCard(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// En-tête : salut, rôle et date du jour, comme l'en-tête du tableau de bord
/// web (« Bonjour, Prénom — Enseignant · lundi 21 septembre 2026 »).
class _DashboardHeader extends ConsumerWidget {
  final UniFlowUser? user;
  final UserRole role;

  const _DashboardHeader({required this.user, required this.role});

  /// Le prénom seul, comme sur le web : « Bonjour, Awa » plutôt que le nom
  /// complet, trop long pour un titre.
  static String firstNameOf(String? fullName) {
    final trimmed = (fullName ?? '').trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final firstName = firstNameOf(user?.name);
    final greeting = greetingFor(now);

    return AppTopBar(
      title: firstName.isEmpty ? greeting : '$greeting, $firstName',
      subtitle: '${role.label} · ${formatLongDate(now)}',
      actions: [
        // Recharge les compteurs : le tableau de bord met en cache ses
        // requêtes tant que le compte ne change pas, et un enseignant qui
        // vient de saisir des notes veut les voir sans se déconnecter.
        TopBarIconButton(
          icon: Icons.refresh_rounded,
          tooltip: 'Actualiser',
          onTap: () {
            ref.invalidate(dashboardOverviewProvider);
            ref.invalidate(dashboardStatsProvider);
            ref.invalidate(dashboardEnrollmentsProvider);
            ref.invalidate(dashboardAttendanceProvider);
            ref.invalidate(dashboardActivityProvider);
          },
        ),
      ],
    );
  }
}

/// Compteurs de l'établissement : étudiants, enseignants, cours, sessions.
class _AdminStats extends ConsumerWidget {
  const _AdminStats();

  /// « — » plutôt que « null » : une clé absente de la réponse s'affichait
  /// littéralement « null » dans la carte.
  static String count(Map<String, dynamic> stats, String key) {
    final value = stats[key];
    return value == null ? '—' : '$value';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    return statsAsync.when(
      data: (stats) => _StatGrid(
        cards: [
          StatCard(
            label: 'Étudiants',
            value: count(stats, 'studentCount'),
            hint: 'Comptes actifs',
            icon: Icons.person_outline,
            iconBackground: AppColors.primaryBlue,
          ),
          StatCard(
            label: 'Enseignants',
            value: count(stats, 'teacherCount'),
            hint: 'Comptes actifs',
            icon: Icons.school_outlined,
            iconBackground: AppColors.teal,
          ),
          StatCard(
            label: 'Cours actifs',
            value: count(stats, 'courseCount'),
            hint: 'Toutes filières',
            icon: Icons.badge_outlined,
            iconBackground: AppColors.warning,
          ),
          StatCard(
            label: 'Sessions',
            value: count(stats, 'sessionCount'),
            hint: 'Historique',
            icon: Icons.event_note_outlined,
            iconBackground: AppColors.purple,
          ),
        ],
      ),
      loading: () => const DataLoadingView(
        label: 'Chargement des indicateurs…',
        compact: true,
      ),
      error: (error, _) => DataErrorView(
        title: 'Indicateurs indisponibles',
        error: error,
        compact: true,
        onRetry: () => ref.invalidate(dashboardStatsProvider),
      ),
    );
  }
}

/// Compteurs d'un apprenant (ses cours, devoirs à rendre, moyenne, présence)
/// ou d'un enseignant (ses cours, étudiants, devoirs, notes saisies).
class _RoleStats extends ConsumerWidget {
  final UserRole role;

  const _RoleStats({required this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(dashboardOverviewProvider);
    return overviewAsync.when(
      data: (overview) => _StatGrid(cards: cardsFor(role, overview)),
      loading: () => const DataLoadingView(
        label: 'Chargement de votre tableau de bord…',
        compact: true,
      ),
      error: (error, _) => DataErrorView(
        title: 'Tableau de bord indisponible',
        error: error,
        compact: true,
        onRetry: () => ref.invalidate(dashboardOverviewProvider),
      ),
    );
  }

  /// Cartes par rôle, exposées pour les tests : ce sont les mêmes quatre
  /// indicateurs que `DashboardPage.tsx` pour le même rôle.
  static List<StatCard> cardsFor(UserRole role, DashboardOverview overview) {
    if (role.isLearning) {
      return [
        StatCard(
          label: 'Mes cours',
          value: '${overview.courseCount}',
          hint: 'Ce semestre',
          icon: Icons.menu_book_outlined,
          iconBackground: AppColors.primaryBlue,
        ),
        StatCard(
          label: 'Devoirs à rendre',
          value: '${overview.assignmentCount}',
          hint:
              overview.assignmentCount == 0 ? 'Rien en attente' : 'En attente',
          icon: Icons.task_outlined,
          iconBackground: AppColors.warning,
        ),
        StatCard(
          label: 'Moyenne générale',
          value: overview.averageLabel,
          hint:
              '${overview.gradeCount} note${overview.gradeCount > 1 ? 's' : ''}',
          icon: Icons.grade_outlined,
          iconBackground: AppColors.teal,
        ),
        StatCard(
          label: 'Taux de présence',
          value: overview.attendanceLabel,
          hint: overview.attendanceRate == null
              ? 'Aucun appel enregistré'
              : 'Depuis la rentrée',
          icon: Icons.event_available_outlined,
          iconBackground: AppColors.purple,
        ),
      ];
    }
    return [
      StatCard(
        label: 'Mes cours',
        value: '${overview.courseCount}',
        hint: 'Enseignements',
        icon: Icons.menu_book_outlined,
        iconBackground: AppColors.primaryBlue,
      ),
      StatCard(
        label: 'Mes étudiants',
        value: '${overview.studentCount}',
        hint: 'Inscrits à mes cours',
        icon: Icons.people_alt_outlined,
        iconBackground: AppColors.teal,
      ),
      StatCard(
        label: 'Devoirs créés',
        value: '${overview.assignmentCount}',
        hint: 'Tous mes cours',
        icon: Icons.task_outlined,
        iconBackground: AppColors.warning,
      ),
      StatCard(
        label: 'Notes saisies',
        value: '${overview.gradeCount}',
        hint: overview.averageOn20 == null
            ? 'Aucune note'
            : 'Moyenne ${overview.averageLabel}',
        icon: Icons.grade_outlined,
        iconBackground: AppColors.purple,
      ),
    ];
  }
}

/// Rangée de raccourcis vers les écrans du rôle, comme la section « Accès
/// rapide » du tableau de bord web.
class _QuickActions extends ConsumerWidget {
  final List<AppDestination> destinations;

  const _QuickActions({required this.destinations});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Card(
      title: 'Accès rapide',
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final destination in destinations)
            AppButton.secondary(
              key: ValueKey('quick-${destination.id}'),
              label: destination.label,
              icon: destination.icon,
              height: 40,
              onPressed: () => ref
                  .read(currentDestinationProvider.notifier)
                  .state = destination,
            ),
        ],
      ),
    );
  }
}

/// Conteneur commun aux cartes du tableau de bord.
class _Card extends StatelessWidget {
  final String title;
  final Widget child;

  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        // `rounded-xl` du web = 12 px, comme les autres cartes de l'app.
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppColors.inputBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.h2,
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

/// Grille de cartes de statistiques qui s'adapte à la largeur disponible.
///
/// Remplace une `Row` de quatre `Expanded` : celle-ci conservait quatre
/// colonnes quelle que soit la largeur de la fenêtre, et chaque carte devenait
/// trop étroite pour son contenu — le libellé puis le delta finissaient par
/// déborder. Ici le nombre de colonnes suit la place réelle (4, 2 puis 1).
///
/// Chaque rangée est enveloppée dans un `IntrinsicHeight` avec des enfants
/// étirés, pour que les cartes d'une même rangée aient toutes la même hauteur
/// même si leurs libellés n'occupent pas le même nombre de lignes.
class _StatGrid extends StatelessWidget {
  final List<Widget> cards;
  static const double gap = 16;

  const _StatGrid({required this.cards});

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1000
            ? 4
            : width >= 640
                ? 2
                : 1;

        final rows = <Widget>[];
        for (var start = 0; start < cards.length; start += columns) {
          final remaining = cards.length - start;
          final take = remaining < columns ? remaining : columns;
          final slice = cards.sublist(start, start + take);

          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < columns; i++) ...[
                    if (i > 0) const SizedBox(width: gap),
                    // Une rangée incomplète est complétée par des cases vides :
                    // les cartes présentes gardent ainsi la même largeur que
                    // sur une rangée pleine.
                    Expanded(
                      child:
                          i < slice.length ? slice[i] : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: gap),
              rows[i],
            ],
          ],
        );
      },
    );
  }
}

/// Deux cartes côte à côte sur une fenêtre large, empilées en dessous du seuil.
///
/// Évite l'écueil d'une `Row` fixe : dans une fenêtre étroite, deux graphiques
/// côte à côte deviennent illisibles avant même de déborder.
class _ResponsiveRow extends StatelessWidget {
  final double breakpoint;
  final Widget left;
  final Widget right;
  static const double gap = 18;

  const _ResponsiveRow({
    required this.breakpoint,
    required this.left,
    required this.right,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, const SizedBox(height: gap), right],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: left),
              const SizedBox(width: gap),
              Expanded(child: right),
            ],
          ),
        );
      },
    );
  }
}

/// Message affiché à la place d'un graphique dont les données manquent.
///
/// La hauteur est fixée pour que la carte garde la même silhouette qu'avec un
/// graphique, y compris sous l'`IntrinsicHeight` qui aligne les deux cartes.
class _ChartEmpty extends StatelessWidget {
  final String message;

  const _ChartEmpty({required this.message});

  /// Hauteur d'un graphique : l'état vide occupe la même place pour que la
  /// carte voisine, alignée par `IntrinsicHeight`, ne change pas de taille.
  static const double chartHeight = 180;

  @override
  Widget build(BuildContext context) {
    // `DataEmptyView` (Uni à la loupe) plutôt qu'une icône grise : c'est le
    // même état vide que partout ailleurs. Il défile dans sa hauteur fixe, donc
    // une police système agrandie ne déborde plus vers le bas.
    return SizedBox(
      height: chartHeight,
      child: DataEmptyView(message: message, compact: true),
    );
  }
}

/// Carte "Inscriptions par mois" — courbe alimentée par les inscriptions
/// réellement enregistrées dans `academic_enrollments`.
class _EnrollmentChartCard extends ConsumerWidget {
  const _EnrollmentChartCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enrollmentsAsync = ref.watch(dashboardEnrollmentsProvider);

    return _Card(
      title: 'Inscriptions par mois',
      child: enrollmentsAsync.when(
        data: (months) {
          if (months.isEmpty || months.every((month) => month.count == 0)) {
            return const _ChartEmpty(
              message:
                  'Aucune inscription enregistrée sur les 6 derniers mois.\n'
                  'La courbe se remplit depuis la collection « academic_enrollments ».',
            );
          }
          return _EnrollmentLineChart(months: months);
        },
        loading: () => const SizedBox(
          height: _ChartEmpty.chartHeight,
          child: DataLoadingView(
              label: 'Chargement des inscriptions…', compact: true),
        ),
        error: (error, _) => SizedBox(
          height: _ChartEmpty.chartHeight,
          child: DataErrorView(
            title: 'Inscriptions indisponibles',
            error: error,
            compact: true,
            onRetry: () => ref.invalidate(dashboardEnrollmentsProvider),
          ),
        ),
      ),
    );
  }
}

class _EnrollmentLineChart extends StatelessWidget {
  final List<MonthlyCount> months;

  const _EnrollmentLineChart({required this.months});

  /// Plafond de l'axe vertical, arrondi au pas supérieur pour que la courbe ne
  /// touche jamais le bord haut du cadre.
  static double _axisMax(int maxCount) {
    if (maxCount <= 0) return 10;
    final step = maxCount <= 10
        ? 2
        : maxCount <= 50
            ? 10
            : maxCount <= 200
                ? 50
                : 100;
    return ((maxCount / step).ceil() * step).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final maxCount =
        months.map((month) => month.count).reduce((a, b) => a > b ? a : b);
    final maxY = _axisMax(maxCount);
    final interval = maxY / 5;

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (value) =>
                const FlLine(color: AppColors.inputBorder, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= months.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(months[index].label,
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.textMuted)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: interval,
                reservedSize: 34,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textMuted),
                ),
              ),
            ),
          ),
          lineTouchData: const LineTouchData(enabled: true),
          lineBarsData: [
            LineChartBarData(
              isCurved: true,
              color: AppColors.primaryBlue,
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                        radius: 3.5,
                        color: AppColors.primaryBlue,
                        strokeWidth: 2,
                        strokeColor: Colors.white),
              ),
              spots: [
                for (int i = 0; i < months.length; i++)
                  FlSpot(i.toDouble(), months[i].count.toDouble()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte "Flux de présence global" — anneau alimenté par les enregistrements
/// de présence. Affiche un état vide explicite quand la collection est absente
/// ou ne contient rien, plutôt qu'une répartition inventée.
class _AttendanceDonutCard extends ConsumerWidget {
  const _AttendanceDonutCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendanceAsync = ref.watch(dashboardAttendanceProvider);

    return _Card(
      title: 'Flux de présence global',
      child: attendanceAsync.when(
        data: (breakdown) {
          if (breakdown == null || breakdown.total == 0) {
            return const _ChartEmpty(
              message: 'Aucune donnée de présence.\n'
                  'La répartition se calcule depuis la collection « attendance_records ».',
            );
          }
          return _AttendanceDonut(breakdown: breakdown);
        },
        loading: () => const SizedBox(
          height: _ChartEmpty.chartHeight,
          child: DataLoadingView(
              label: 'Chargement des présences…', compact: true),
        ),
        error: (error, _) => SizedBox(
          height: _ChartEmpty.chartHeight,
          child: DataErrorView(
            title: 'Présences indisponibles',
            error: error,
            compact: true,
            onRetry: () => ref.invalidate(dashboardAttendanceProvider),
          ),
        ),
      ),
    );
  }
}

class _AttendanceDonut extends StatelessWidget {
  final AttendanceBreakdown breakdown;

  const _AttendanceDonut({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    String percent(int value) => '${breakdown.percentOf(value).round()}%';

    return SizedBox(
      height: 180,
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 46,
                sections: [
                  PieChartSectionData(
                      value: breakdown.present.toDouble(),
                      color: AppColors.teal,
                      radius: 22,
                      showTitle: false),
                  PieChartSectionData(
                      value: breakdown.absent.toDouble(),
                      color: AppColors.deepBlue,
                      radius: 22,
                      showTitle: false),
                  PieChartSectionData(
                      value: breakdown.late.toDouble(),
                      color: AppColors.warning,
                      radius: 22,
                      showTitle: false),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          // `Flexible` et non une colonne rigide : dans une carte étroite, la
          // légende doit pouvoir se réduire au lieu de comprimer l'anneau
          // jusqu'à le faire disparaître.
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendRow(
                    color: AppColors.teal,
                    label: 'Présent',
                    value: percent(breakdown.present)),
                const SizedBox(height: 14),
                _LegendRow(
                    color: AppColors.deepBlue,
                    label: 'Absent',
                    value: percent(breakdown.absent)),
                const SizedBox(height: 14),
                _LegendRow(
                    color: AppColors.warning,
                    label: 'Retard',
                    value: percent(breakdown.late)),
                const SizedBox(height: 14),
                Text(
                  '${breakdown.total} enregistrement${breakdown.total > 1 ? 's' : ''}',
                  maxLines: 2,
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _LegendRow(
      {required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Carte "Activités récentes" : les derniers documents créés dans l'annuaire,
/// les cours et l'emploi du temps, fusionnés par date de création.
class _RecentActivityCard extends ConsumerWidget {
  const _RecentActivityCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(dashboardActivityProvider);

    return _Card(
      title: 'Activités récentes',
      child: activityAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return const DataEmptyView(
              message: 'Aucune activité enregistrée pour le moment.',
              compact: true,
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final entry in entries) _ActivityRow(entry: entry)],
          );
        },
        loading: () => const DataLoadingView(
            label: 'Chargement des activités…', compact: true),
        error: (error, _) => DataErrorView(
          title: 'Activités indisponibles',
          error: error,
          compact: true,
          onRetry: () => ref.invalidate(dashboardActivityProvider),
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final ActivityEntry entry;

  const _ActivityRow({required this.entry});

  static const Map<ActivityKind, IconData> _icons = {
    ActivityKind.enrollment: Icons.person_add_alt_outlined,
    ActivityKind.course: Icons.menu_book_outlined,
    ActivityKind.schedule: Icons.schedule_outlined,
  };

  static const Map<ActivityKind, Color> _colors = {
    ActivityKind.enrollment: AppColors.primaryBlue,
    ActivityKind.course: AppColors.success,
    ActivityKind.schedule: AppColors.purple,
  };

  /// « Nom ajouté à l'annuaire », « Cours « X » créé »…
  String get _title {
    switch (entry.kind) {
      case ActivityKind.enrollment:
        return '${entry.subject} ajouté à l\'annuaire';
      case ActivityKind.course:
        return 'Cours « ${entry.subject} » créé';
      case ActivityKind.schedule:
        return 'Créneau en ${entry.subject} ajouté';
    }
  }

  /// Date relative lisible : « Aujourd'hui, 10:24 », « Hier, 16:42 »,
  /// « Il y a 3 jours, 09:15 », puis la date complète au-delà d'une semaine.
  String get _time {
    final moment = entry.createdAt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(moment.year, moment.month, moment.day);
    final clock =
        '${moment.hour.toString().padLeft(2, '0')}:${moment.minute.toString().padLeft(2, '0')}';

    final days = today.difference(day).inDays;
    if (days <= 0) return "Aujourd'hui, $clock";
    if (days == 1) return 'Hier, $clock';
    if (days < 7) return 'Il y a $days jours, $clock';
    return '${moment.day.toString().padLeft(2, '0')}/${moment.month.toString().padLeft(2, '0')}/${moment.year}';
  }

  @override
  Widget build(BuildContext context) {
    final color = _colors[entry.kind] ?? AppColors.primaryBlue;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9)),
            child: Icon(_icons[entry.kind] ?? Icons.circle_outlined,
                size: 17, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _title,
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
            ),
          ),
          Text(_time,
              style:
                  const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
