import 'package:flutter/material.dart';

/// Type de séance, avec sa couleur associée (utilisée pour le bloc dans
/// la grille et pour la légende en haut de la page).
enum SessionType {
  cm('CM', Color(0xFF1E3A8A)),
  td('TD', Color(0xFF0FBFA0)),
  tp('TP', Color(0xFFE8963B)),
  seminaire('Séminaire', Color(0xFF34C77B));

  final String label;
  final Color color;
  const SessionType(this.label, this.color);
}

/// Un cours positionné dans la grille de l'emploi du temps.
class ScheduleEvent {
  final String title;
  final SessionType type;
  final int dayIndex;      // 0 = Lundi ... 5 = Samedi
  final double startHour;  // ex: 8.0 pour 08h00, 12.5 pour 12h30
  final double endHour;
  final String salle;
  final String enseignant;
  final String groupe;
  final String description;

  const ScheduleEvent({
    required this.title,
    required this.type,
    required this.dayIndex,
    required this.startHour,
    required this.endHour,
    required this.salle,
    required this.enseignant,
    required this.groupe,
    required this.description,
  });

  double get durationHours => endHour - startHour;
}

/// L'emploi du temps d'une semaine donnée : les créneaux plaçables dans la
/// grille, la date du lundi de la semaine affichée, et le nombre de créneaux
/// lus en base mais impossibles à positionner.
///
/// [unplacedCount] n'est pas décoratif : `academic_schedules.dayOfWeek` et les
/// horaires sont stockés sous forme de chaînes dont le format n'est pas
/// contraint par la base. Un créneau dont le jour ou l'heure n'est pas
/// reconnu est écarté de la grille et compté ici, pour que l'interface le
/// signale au lieu de le placer à une position inventée.
class ScheduleWeek {
  final DateTime weekStart;
  final List<ScheduleEvent> events;
  final int unplacedCount;

  const ScheduleWeek({
    required this.weekStart,
    required this.events,
    this.unplacedCount = 0,
  });

  static const List<String> _dayNames = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];

  /// Nombre de colonnes de la grille (lundi → samedi).
  static const int dayCount = 6;

  static const List<String> _monthNames = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];

  /// Libellés des colonnes (« Lun 13 », « Mar 14 »…) pour la semaine affichée.
  List<String> get dayLabels => [
        for (int i = 0; i < _dayNames.length; i++)
          '${_dayNames[i]} ${weekStart.add(Duration(days: i)).day}',
      ];

  /// Plage affichée dans la barre d'outils, ex. « 13 – 19 mai 2026 ».
  String get rangeLabel {
    final start = weekStart;
    // `_dayNames.length` n'est pas évaluable à la compilation : `const Duration`
    // était refusé ici (« Constant evaluation error »).
    final end = weekStart.add(Duration(days: _dayNames.length - 1));
    if (start.month == end.month) {
      return '${start.day} – ${end.day} ${_monthNames[start.month - 1]} ${end.year}';
    }
    return '${start.day} ${_monthNames[start.month - 1]} – '
        '${end.day} ${_monthNames[end.month - 1]} ${end.year}';
  }
}
