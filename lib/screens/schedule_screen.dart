import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../models/schedule_event.dart';
import '../providers/schedule_provider.dart';
import '../widgets/app_breadcrumb.dart';
import '../widgets/status_badge.dart';

/// Page "Emploi du temps" : grille hebdomadaire alimentée par
/// `academic_schedules`, légende des types de séance, navigation de semaine,
/// et un panneau de détail qui s'ouvre au clic sur un cours.
///
/// Ce widget n'a pas de Scaffold/sidebar propre : il est affiché à
/// l'intérieur de [MainShell]. La sidebar admin reste celle utilisée
/// partout ailleurs dans l'app pour la cohérence, seul le contenu de la
/// page reprend la maquette du calendrier.
class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  static const double _startHour = 8;
  static const double _endHour = 18;
  static const double _hourHeight = 64;
  static const double _hourColumnWidth = 60;

  /// Identité du cours sélectionné, plutôt que l'objet lui-même : les créneaux
  /// sont reconstruits à chaque rechargement (changement de semaine, retour sur
  /// la page), une référence directe deviendrait vite obsolète.
  String? _selectedKey;

  @override
  Widget build(BuildContext context) {
    final weekAsync = ref.watch(scheduleWeekProvider);
    // `valueOrNull` conserve la semaine précédente pendant un rechargement :
    // la barre d'outils et la légende ne clignotent pas.
    final week = weekAsync.valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTopBar(),
        _buildToolbar(week),
        if (week != null && week.unplacedCount > 0) _buildUnplacedBanner(week),
        _buildLegend(),
        Expanded(
          child: weekAsync.when(
            data: (data) {
              final selected = _findSelected(data.events);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildCalendarGrid(data)),
                  if (selected != null) _buildDetailPanel(selected),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _ScheduleError(
              error: error,
              onRetry: () => ref.invalidate(scheduleWeekProvider),
            ),
          ),
        ),
      ],
    );
  }

  String _keyOf(ScheduleEvent event) =>
      '${event.dayIndex}|${event.startHour}|${event.endHour}|${event.title}|${event.salle}';

  ScheduleEvent? _findSelected(List<ScheduleEvent> events) {
    final key = _selectedKey;
    if (key == null) return null;
    for (final event in events) {
      if (_keyOf(event) == key) return event;
    }
    return null;
  }

  void _toggleSelection(ScheduleEvent event) {
    final key = _keyOf(event);
    setState(() => _selectedKey = _selectedKey == key ? null : key);
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        border: Border(bottom: BorderSide(color: AppColors.inputBorder)),
      ),
      child: const AppBreadcrumb(items: ['Accueil', 'Emploi du temps']),
    );
  }

  /// Signale les créneaux lus en base mais non plaçables : sans ce bandeau, une
  /// valeur de `dayOfWeek` ou d'horaire dans un format inattendu se traduirait
  /// par une grille silencieusement incomplète.
  Widget _buildUnplacedBanner(ScheduleWeek week) {
    final count = week.unplacedCount;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
      color: const Color(0xFFFFF6E5),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 17, color: Color(0xFFB27B16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count créneau${count > 1 ? 'x' : ''} de la base n\'ont pas pu être '
              'positionnés (jour ou horaire illisible) et ne figurent pas dans la grille.',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF8A5F0B)),
            ),
          ),
        ],
      ),
    );
  }

  /// Barre d'outils : navigation de semaine, filtres, boutons d'export.
  Widget _buildToolbar(ScheduleWeek? week) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        border: Border(bottom: BorderSide(color: AppColors.inputBorder)),
      ),
      // Deux groupes distincts plutôt qu'un seul Wrap avec un Spacer : un
      // Spacer est un Expanded, et un Expanded placé dans un Wrap lève
      // « wants to apply ParentData of type FlexParentData to a RenderObject
      // which has been set up to accept WrapParentData » — le Wrap donne à ses
      // enfants des contraintes non bornées sur l'axe principal, un Flex ne
      // peut donc pas y calculer sa répartition.
      //
      // Chaque groupe est un Wrap dans un Flexible : le premier occupe la
      // moitié gauche, le second la moitié droite et s'aligne sur son bord via
      // WrapAlignment.end. Sur une fenêtre étroite, chaque groupe se replie sur
      // plusieurs lignes au lieu de déborder.
      child: Row(
        children: [
          Flexible(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RoundIconButton(
                      icon: Icons.chevron_left,
                      onTap: () => ref.read(weekOffsetProvider.notifier).state--,
                    ),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        // `Flexible` + ellipse : « 13 – 19 septembre 2026 » est
                        // long, et la rangée poussait les flèches hors de la
                        // barre dans une fenêtre étroite.
                        child: Text(
                          week?.rangeLabel ?? '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                      ),
                    ),
                    _RoundIconButton(
                      icon: Icons.chevron_right,
                      onTap: () => ref.read(weekOffsetProvider.notifier).state++,
                    ),
                    if (week != null && _offsetOf(week) != 0)
                      TextButton(
                        onPressed: () => ref.read(weekOffsetProvider.notifier).state = 0,
                        child: const Text('Aujourd\'hui'),
                      ),
                  ],
                ),
                const _FilterDropdown(label: 'Programme'),
                const _FilterDropdown(label: 'Niveau'),
                const _FilterDropdown(label: 'Semestre'),
                _ViewToggle(),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    // TODO: exporter l'emploi du temps en PDF
                  },
                  icon: const Icon(Icons.download_outlined, size: 16, color: AppColors.textSecondary),
                  label: const Text('Export PDF'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.inputBorder),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    // TODO: imprimer l'emploi du temps
                  },
                  icon: const Icon(Icons.print_outlined, size: 16, color: AppColors.textSecondary),
                  label: const Text('Imprimer'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.inputBorder),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: générer automatiquement l'emploi du temps
                  },
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Auto-générer'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _offsetOf(ScheduleWeek week) {
    final currentMonday = DateTime.now();
    final today = DateTime(currentMonday.year, currentMonday.month, currentMonday.day);
    final thisMonday = today.subtract(Duration(days: today.weekday - DateTime.monday));
    return week.weekStart.difference(thisMonday).inDays ~/ 7;
  }

  /// Légende des 4 types de séance (couleurs), au-dessus de la grille.
  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        border: Border(bottom: BorderSide(color: AppColors.inputBorder)),
      ),
      // `Wrap` : quatre entrées de légende ne tiennent pas sur une ligne dans
      // une fenêtre étroite ; elles se replient au lieu de déborder.
      child: Wrap(
        spacing: 20,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final type in SessionType.values)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: type.color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(type.label, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
              ],
            ),
        ],
      ),
    );
  }

  /// La grille hebdomadaire : colonne des heures à gauche, 6 colonnes de
  /// jours, événements positionnés en absolu selon leur horaire.
  Widget _buildCalendarGrid(ScheduleWeek week) {
    if (week.events.isEmpty) {
      return _EmptyWeek(weekStart: week.weekStart);
    }

    final hourCount = (_endHour - _startHour).round();
    final totalHeight = hourCount * _hourHeight;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final gridWidth = constraints.maxWidth;
          final dayColumnWidth = (gridWidth - _hourColumnWidth) / ScheduleWeek.dayCount;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // En-tête des jours
              Row(
                children: [
                  SizedBox(width: _hourColumnWidth),
                  for (final day in week.dayLabels)
                    SizedBox(
                      width: dayColumnWidth,
                      child: Text(
                        day,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              // Corps de la grille : lignes d'heures + colonnes de jours en fond,
              // événements positionnés par-dessus avec Stack.
              SizedBox(
                height: totalHeight,
                child: Stack(
                  children: [
                    // Fond : lignes horizontales (une par heure) + labels d'heure
                    Column(
                      children: [
                        for (int h = 0; h < hourCount; h++)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: _hourColumnWidth,
                                height: _hourHeight,
                                child: Text(
                                  '${(_startHour + h).toInt().toString().padLeft(2, '0')}h00',
                                  style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  height: _hourHeight,
                                  decoration: const BoxDecoration(
                                    border: Border(top: BorderSide(color: AppColors.inputBorder)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    // Colonnes verticales séparant les jours
                    Positioned.fill(
                      child: Row(
                        children: [
                          SizedBox(width: _hourColumnWidth),
                          for (int i = 0; i < ScheduleWeek.dayCount; i++)
                            Container(
                              width: dayColumnWidth,
                              decoration: const BoxDecoration(
                                border: Border(left: BorderSide(color: AppColors.inputBorder)),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Événements positionnés selon jour/horaire
                    for (final event in week.events)
                      Positioned(
                        left: _hourColumnWidth + event.dayIndex * dayColumnWidth + 3,
                        top: (event.startHour - _startHour) * _hourHeight,
                        width: dayColumnWidth - 6,
                        height: event.durationHours * _hourHeight - 4,
                        child: _EventBlock(
                          event: event,
                          isSelected: _selectedKey == _keyOf(event),
                          onTap: () => _toggleSelection(event),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Panneau de détail du cours sélectionné, affiché à droite de la grille.
  Widget _buildDetailPanel(ScheduleEvent event) {
    return Container(
      width: 300,
      margin: const EdgeInsets.fromLTRB(0, 24, 24, 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Cours sélectionné', style: AppTextStyles.h2),
                InkWell(
                  onTap: () => setState(() => _selectedKey = null),
                  child: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 14),
            StatusBadge(
              label: event.type.label,
              backgroundColor: event.type.color.withValues(alpha: 0.15),
              textColor: event.type.color,
            ),
            const SizedBox(height: 10),
            Text(event.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 18),
            _DetailField(label: 'Enseignant', value: event.enseignant),
            _DetailField(label: 'Salle', value: event.salle.isEmpty ? '—' : event.salle),
            _DetailField(label: 'Groupe', value: event.groupe),
            _DetailField(label: 'Type', value: event.type.label),
            _DetailField(label: 'Description', value: event.description.isEmpty ? '—' : event.description),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  // TODO: afficher la liste des étudiants inscrits à ce cours
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.inputBorder),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Voir les étudiants'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: ajouter ce cours au calendrier personnel
                },
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13)),
                child: const Text('Ajouter au calendrier'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Affiché quand la base ne contient aucun créneau plaçable pour la semaine.
class _EmptyWeek extends StatelessWidget {
  final DateTime weekStart;

  const _EmptyWeek({required this.weekStart});

  @override
  Widget build(BuildContext context) {
    // `SingleChildScrollView` : la zone disponible dépend de la hauteur de la
    // fenêtre ; avec une police système agrandie, le bloc dépassait vers le
    // bas. Ici il défile au lieu de déborder.
    return SingleChildScrollView(
      child: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_busy_outlined, size: 44, color: AppColors.textMuted),
            const SizedBox(height: 14),
            const Text(
              'Aucun créneau pour cette semaine',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Semaine du ${weekStart.day}/${weekStart.month}/${weekStart.year} — aucun '
              'créneau à afficher.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Les créneaux proviennent de la collection « academic_schedules ». '
              'Ajoutez-y des séances (jour, heure de début et de fin, salle) pour '
              'les voir apparaître ici.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.45),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _ScheduleError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ScheduleError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 44, color: AppColors.textMuted),
            const SizedBox(height: 14),
            const Text(
              'Emploi du temps indisponible',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.4),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 17),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailField extends StatelessWidget {
  final String label;
  final String value;

  const _DetailField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.3)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary, height: 1.35)),
        ],
      ),
    );
  }
}

/// Bloc coloré représentant un cours dans la grille, cliquable pour
/// afficher/masquer le panneau de détail.
class _EventBlock extends StatelessWidget {
  final ScheduleEvent event;
  final bool isSelected;
  final VoidCallback onTap;

  const _EventBlock({required this.event, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final subtitle = event.salle.isEmpty
        ? event.type.label
        : '${event.type.label} · ${event.salle}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: event.type.color,
            borderRadius: BorderRadius.circular(8),
            border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
            boxShadow: isSelected
                ? [BoxShadow(color: event.type.color.withValues(alpha: 0.5), blurRadius: 8)]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                event.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.9)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.inputBorder)),
        child: Icon(icon, size: 18, color: AppColors.textSecondary),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(border: Border.all(color: AppColors.inputBorder), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

/// Sélecteur de vue Semaine / Mois / Jour (visuel uniquement pour l'instant,
/// "Semaine" reste actif — la grille est construite pour une vue semaine).
class _ViewToggle extends StatefulWidget {
  @override
  State<_ViewToggle> createState() => _ViewToggleState();
}

class _ViewToggleState extends State<_ViewToggle> {
  int _selected = 0;
  static const _options = ['Semaine', 'Mois', 'Jour'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(10)),
      // `FittedBox` : les trois libellés et leurs marges réclament 105 px de
      // plus que la place laissée par la rangée à 420 px de large — soit 162 px
      // en texte agrandi. Le sélecteur se réduit d'un cran plutôt que de
      // pousser « Jour » hors de son cadre, ce qui reste lisible puisqu'il
      // s'agit d'un contrôle secondaire.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < _options.length; i++)
              InkWell(
                onTap: () => setState(() => _selected = i),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _selected == i ? AppColors.primaryBlue : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _options[i],
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _selected == i ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
