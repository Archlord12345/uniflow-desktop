import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dashboard_models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/stat_card.dart';
import '../widgets/user_avatar.dart';
import '../repositories/academic_repository.dart';
import '../providers/auth_provider.dart';
import '../utils/avatar.dart';
import '../models/appwrite_models.dart';

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

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final user = ref.watch(currentUserProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTopBar(user),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                statsAsync.when(
                  data: (stats) => _StatGrid(
                    cards: [
                      StatCard(
                        label: 'Étudiants',
                        value: '${stats['studentCount']}',
                        delta: 'Direct',
                        icon: Icons.person_outline,
                        iconBackground: AppColors.primaryBlue,
                      ),
                      StatCard(
                        label: 'Enseignants',
                        value: '${stats['teacherCount']}',
                        delta: 'Direct',
                        icon: Icons.school_outlined,
                        iconBackground: AppColors.teal,
                      ),
                      StatCard(
                        label: 'Cours actifs',
                        value: '${stats['courseCount']}',
                        delta: 'Total',
                        icon: Icons.badge_outlined,
                        iconBackground: AppColors.warning,
                      ),
                      StatCard(
                        label: 'Sessions',
                        value: '${stats['sessionCount']}',
                        delta: 'Historique',
                        icon: Icons.event_note_outlined,
                        iconBackground: AppColors.purple,
                      ),
                    ],
                  ),
                  loading: () => const Center(child: LinearProgressIndicator()),
                  error: (e, _) => Text('Erreur stats: $e'),
                ),
                const SizedBox(height: 18),

                // ----- Graphique des inscriptions + graphique en anneau -----
                // Côte à côte quand la fenêtre est assez large, empilés sinon :
                // deux graphiques dans une fenêtre étroite deviennent illisibles.
                _ResponsiveRow(
                  breakpoint: 900,
                  left: const _EnrollmentChartCard(),
                  right: const _AttendanceDonutCard(),
                ),
                const SizedBox(height: 18),

                // ----- Activités récentes (pleine largeur) -----
                const _RecentActivityCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Barre du haut spécifique au dashboard : recherche globale + notif + avatar
  /// (pas de titre de page ici, contrairement aux autres écrans — fidèle à
  /// la maquette où le nom de l'utilisateur est affiché dans la sidebar).
  Widget _buildTopBar(UniFlowUser? user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        border: Border(bottom: BorderSide(color: AppColors.inputBorder)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Sous ce seuil, la barre de recherche ne peut plus cohabiter avec
          // les icônes de droite : elle passe sur sa propre ligne.
          final narrow = constraints.maxWidth < 520;

          final searchBox = Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.inputBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, size: 18, color: AppColors.textMuted),
                const SizedBox(width: 10),
                const Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Rechercher globalement...',
                      hintStyle:
                          TextStyle(color: AppColors.textMuted, fontSize: 13.5),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          );

          final trailing = <Widget>[
            // Cloche sans pastille : la version précédente affichait un « 4 »
            // codé en dur, donc un nombre de notifications non lues qui
            // n'existait pas. Tant qu'aucun compteur réel n'alimente ce badge,
            // mieux vaut ne rien afficher qu'un chiffre inventé.
            const TopBarIconButton(
              icon: Icons.notifications_none_rounded,
              tooltip: 'Notifications',
            ),
            const SizedBox(width: 18),
            // `initialsOf` plutôt que `name.substring(0, 1)` : un nom vide faisait
            // planter la construction de l'en-tête.
            InitialsAvatar(
              initials: user == null ? '?' : initialsOf(user.name),
              avatarFileId: user?.avatarFileId,
              size: 36,
            ),
          ];

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Spacer(),
                    ...trailing,
                  ],
                ),
                const SizedBox(height: 14),
                searchBox,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: searchBox),
              const SizedBox(width: 20),
              ...trailing,
            ],
          );
        },
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
                    if (i > 0) SizedBox(width: gap),
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
              if (i > 0) SizedBox(height: gap),
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
            children: [left, SizedBox(height: gap), right],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: left),
              SizedBox(width: gap),
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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          // `FittedBox` : la carte a une hauteur fixe (180 px) et le message
          // occupe deux ou trois lignes. Avec une police système agrandie, la
          // colonne dépassait cette hauteur et Flutter signalait un
          // débordement vers le bas. Ici l'ensemble se réduit légèrement au
          // lieu de déborder.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.insights_outlined,
                    size: 34, color: AppColors.textMuted),
                const SizedBox(height: 12),
                SizedBox(
                  width: 220,
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                        height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
          height: 180,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) =>
            _ChartEmpty(message: 'Inscriptions indisponibles.\n$error'),
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
                FlLine(color: AppColors.inputBorder, strokeWidth: 1),
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
                  if (index < 0 || index >= months.length)
                    return const SizedBox.shrink();
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
          height: 180,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) =>
            _ChartEmpty(message: 'Présences indisponibles.\n$error'),
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
                      color: const Color(0xFFE8724C),
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
                    color: const Color(0xFFE8724C),
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
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Aucune activité enregistrée pour le moment.',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final entry in entries) _ActivityRow(entry: entry)],
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: LinearProgressIndicator(),
        ),
        error: (error, _) => Text(
          'Activités indisponibles : $error',
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
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
    ActivityKind.schedule: Color(0xFF8B5CF6),
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
