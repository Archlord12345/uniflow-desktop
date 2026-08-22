import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_card.dart';
import '../widgets/user_avatar.dart';

/// Page "Dashboard" : recherche globale, 4 cartes statistiques, graphique
/// des inscriptions, graphique en anneau du flux de présence, et activités
/// récentes. Fidèle à la maquette "UniFlow Desktop Partie 1".
///
/// Ce widget n'a pas de Scaffold/sidebar propre : il est affiché à
/// l'intérieur de [MainShell].
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                  children: const [
                    Expanded(
                      child: StatCard(
                        label: 'Étudiants',
                        value: '1 248',
                        delta: '12%',
                        icon: Icons.person_outline,
                        iconBackground: Color(0xFF1E3A8A),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: StatCard(
                        label: 'Enseignants',
                        value: '312',
                        delta: '5%',
                        icon: Icons.person_outline,
                        iconBackground: AppColors.primaryBlue,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: StatCard(
                        label: 'Cours actifs',
                        value: '24',
                        delta: '0%',
                        isPositive: false,
                        icon: Icons.badge_outlined,
                        iconBackground: Color(0xFFF5A623),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: StatCard(
                        label: 'Sessions aujourd\'hui',
                        value: '156',
                        delta: '8%',
                        icon: Icons.event_note_outlined,
                        iconBackground: Color(0xFF0FBFA0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // ----- Graphique des inscriptions + graphique en anneau -----
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Expanded(child: _EnrollmentChartCard()),
                      const SizedBox(width: 18),
                      const Expanded(child: _AttendanceDonutCard()),
                    ],
                  ),
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
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        border: Border(bottom: BorderSide(color: AppColors.inputBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
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
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Rechercher globalement...',
                        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13.5),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none_rounded, size: 24, color: AppColors.textSecondary),
              Positioned(
                top: -4,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: const Text(
                    '4',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 18),
          const InitialsAvatar(initials: 'AD', size: 36),
        ],
      ),
    );
  }
}

/// Carte "Inscriptions par mois" — graphique en courbe (sans remplissage
/// sous la courbe cette fois, fidèle à la nouvelle maquette).
class _EnrollmentChartCard extends StatelessWidget {
  const _EnrollmentChartCard();

  static const List<double> _values = [180, 300, 220, 260, 450, 480];
  static const List<String> _months = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Inscriptions par mois', style: AppTextStyles.h2),
          const SizedBox(height: 18),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 600,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 150,
                  getDrawingHorizontalLine: (value) => FlLine(color: AppColors.inputBorder, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= _months.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(_months[index], style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 150,
                      reservedSize: 34,
                      getTitlesWidget: (value, meta) =>
                          Text(value.toInt().toString(), style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
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
                          FlDotCirclePainter(radius: 3.5, color: AppColors.primaryBlue, strokeWidth: 2, strokeColor: Colors.white),
                    ),
                    spots: [for (int i = 0; i < _values.length; i++) FlSpot(i.toDouble(), _values[i])],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte "Flux de présence global" — graphique en anneau (donut) avec
/// légende des 3 statuts (Présent / Absent / Retard).
class _AttendanceDonutCard extends StatelessWidget {
  const _AttendanceDonutCard();

  static const _present = 62.0;
  static const _absent = 25.0;
  static const _late = 13.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Flux de présence global', style: AppTextStyles.h2),
          const SizedBox(height: 18),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 46,
                      sections: [
                        PieChartSectionData(
                          value: _present,
                          color: AppColors.teal,
                          radius: 22,
                          showTitle: false,
                        ),
                        PieChartSectionData(
                          value: _absent,
                          color: AppColors.deepBlue,
                          radius: 22,
                          showTitle: false,
                        ),
                        PieChartSectionData(
                          value: _late,
                          color: const Color(0xFFE8724C),
                          radius: 22,
                          showTitle: false,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    _LegendRow(color: AppColors.teal, label: 'Présent', value: '62%'),
                    SizedBox(height: 14),
                    _LegendRow(color: AppColors.deepBlue, label: 'Absent', value: '25%'),
                    SizedBox(height: 14),
                    _LegendRow(color: Color(0xFFE8724C), label: 'Retard', value: '13%'),
                  ],
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

  const _LegendRow({required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
      ],
    );
  }
}

/// Carte "Activités récentes" pleine largeur, avec une icône colorée par
/// type d'événement (inscription, cours, planning, conférence).
class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard();

  static const List<_ActivityData> _activities = [
    _ActivityData(
      icon: Icons.person_add_alt_outlined,
      iconColor: AppColors.primaryBlue,
      title: 'Raphaël Onana inscrit',
      time: "Aujourd'hui, 10:24",
    ),
    _ActivityData(
      icon: Icons.menu_book_outlined,
      iconColor: AppColors.success,
      title: 'Cours IA avancé créé',
      time: "Aujourd'hui, 09:15",
    ),
    _ActivityData(
      icon: Icons.schedule_outlined,
      iconColor: Color(0xFF8B5CF6),
      title: 'Mise à jour emplois du temps',
      time: 'Hier, 16:42',
    ),
    _ActivityData(
      icon: Icons.videocam_outlined,
      iconColor: Color(0xFFE8724C),
      title: 'Conférence "IA et Société" planifiée',
      time: 'Hier, 11:08',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Activités récentes', style: AppTextStyles.h2),
          const SizedBox(height: 14),
          for (final activity in _activities) _ActivityRow(data: activity),
        ],
      ),
    );
  }
}

class _ActivityData {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String time;

  const _ActivityData({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.time,
  });
}

class _ActivityRow extends StatelessWidget {
  final _ActivityData data;

  const _ActivityRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: data.iconColor.withOpacity(0.12), borderRadius: BorderRadius.circular(9)),
            child: Icon(data.icon, size: 17, color: data.iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              data.title,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),
          Text(data.time, style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
