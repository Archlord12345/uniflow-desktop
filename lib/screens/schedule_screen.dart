import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/schedule_event.dart';
import '../widgets/app_breadcrumb.dart';
import '../widgets/status_badge.dart';

/// Page "Emploi du temps" : grille hebdomadaire avec les cours positionnés
/// selon leur jour/horaire, légende des types de séance, filtres, et un
/// panneau de détail qui s'ouvre au clic sur un cours.
///
/// Ce widget n'a pas de Scaffold/sidebar propre : il est affiché à
/// l'intérieur de [MainShell]. La sidebar admin reste celle utilisée
/// partout ailleurs dans l'app pour la cohérence, seul le contenu de la
/// page reprend la maquette du calendrier.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  static const List<String> _days = ['Lun 13', 'Mar 14', 'Mer 15', 'Jeu 16', 'Ven 17', 'Sam 18'];
  static const double _startHour = 8;
  static const double _endHour = 18;
  static const double _hourHeight = 64;
  static const double _hourColumnWidth = 60;

  ScheduleEvent? _selectedEvent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTopBar(),
        _buildToolbar(),
        _buildLegend(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildCalendarGrid()),
              if (_selectedEvent != null) _buildDetailPanel(_selectedEvent!),
            ],
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
      child: const AppBreadcrumb(items: ['Accueil', 'Emploi du temps']),
    );
  }

  /// Barre d'outils : navigation de semaine, filtres, boutons d'export.
  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        border: Border(bottom: BorderSide(color: AppColors.inputBorder)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RoundIconButton(icon: Icons.chevron_left, onTap: () {}),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('13 – 19 mai 2026', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ),
              _RoundIconButton(icon: Icons.chevron_right, onTap: () {}),
            ],
          ),
          const _FilterDropdown(label: 'Programme'),
          const _FilterDropdown(label: 'Niveau'),
          const _FilterDropdown(label: 'Semestre'),
          _ViewToggle(),
          const Spacer(),
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
    );
  }

  /// Légende des 4 types de séance (couleurs), au-dessus de la grille.
  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        border: Border(bottom: BorderSide(color: AppColors.inputBorder)),
      ),
      child: Row(
        children: [
          for (final type in SessionType.values) ...[
            Container(width: 10, height: 10, decoration: BoxDecoration(color: type.color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(type.label, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            const SizedBox(width: 20),
          ],
        ],
      ),
    );
  }

  /// La grille hebdomadaire : colonne des heures à gauche, 6 colonnes de
  /// jours, événements positionnés en absolu selon leur horaire.
  Widget _buildCalendarGrid() {
    final hourCount = (_endHour - _startHour).round();
    final totalHeight = hourCount * _hourHeight;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final gridWidth = constraints.maxWidth;
          final dayColumnWidth = (gridWidth - _hourColumnWidth) / _days.length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // En-tête des jours
              Row(
                children: [
                  SizedBox(width: _hourColumnWidth),
                  for (final day in _days)
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
                          for (int i = 0; i < _days.length; i++)
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
                    for (final event in ScheduleEvent.mockWeek)
                      Positioned(
                        left: _hourColumnWidth + event.dayIndex * dayColumnWidth + 3,
                        top: (event.startHour - _startHour) * _hourHeight,
                        width: dayColumnWidth - 6,
                        height: event.durationHours * _hourHeight - 4,
                        child: _EventBlock(
                          event: event,
                          isSelected: _selectedEvent == event,
                          onTap: () => setState(() {
                            _selectedEvent = _selectedEvent == event ? null : event;
                          }),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Cours sélectionné', style: AppTextStyles.h2),
              InkWell(
                onTap: () => setState(() => _selectedEvent = null),
                child: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 14),
          StatusBadge(label: event.type.label, backgroundColor: event.type.color.withOpacity(0.15), textColor: event.type.color),
          const SizedBox(height: 10),
          Text(event.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 18),
          _DetailField(label: 'Enseignant', value: event.enseignant),
          _DetailField(label: 'Salle', value: event.salle),
          _DetailField(label: 'Groupe', value: event.groupe),
          _DetailField(label: 'Type', value: event.type.label),
          _DetailField(label: 'Description', value: event.description),
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
                ? [BoxShadow(color: event.type.color.withOpacity(0.5), blurRadius: 8)]
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
                '${event.type.label} · ${event.salle}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, color: Colors.white.withOpacity(0.9)),
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
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
    );
  }
}
