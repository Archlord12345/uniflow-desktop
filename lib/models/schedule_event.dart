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

  /// Jeu de données factices reproduisant la maquette de la semaine du
  /// 13 au 19 mai 2026.
  static const List<ScheduleEvent> mockWeek = [
    ScheduleEvent(
      title: 'Algorithmique',
      type: SessionType.cm,
      dayIndex: 0,
      startHour: 8,
      endHour: 9.5,
      salle: 'Salle A204',
      enseignant: 'Pr. Leroy',
      groupe: 'L2 — Groupe A',
      description: 'Cours magistral — introduction aux algorithmes de tri.',
    ),
    ScheduleEvent(
      title: 'Bases de données',
      type: SessionType.td,
      dayIndex: 0,
      startHour: 10,
      endHour: 11,
      salle: 'Salle B101',
      enseignant: 'Pr. Haddad',
      groupe: 'L2 — Groupe A',
      description: 'Travaux dirigés — modélisation entité-association.',
    ),
    ScheduleEvent(
      title: 'Algorithmique',
      type: SessionType.td,
      dayIndex: 1,
      startHour: 9,
      endHour: 10.5,
      salle: 'Salle A204',
      enseignant: 'Pr. Leroy',
      groupe: 'L2 — Groupe A',
      description: 'Travaux dirigés — exercices sur les algorithmes de tri.',
    ),
    ScheduleEvent(
      title: 'IA — Séminaire',
      type: SessionType.seminaire,
      dayIndex: 1,
      startHour: 11,
      endHour: 12,
      salle: 'Salle S202',
      enseignant: 'Pr. Karim Zerouali',
      groupe: 'L2 — Groupe A',
      description: 'Séminaire — introduction au machine learning.',
    ),
    ScheduleEvent(
      title: 'Bases de données',
      type: SessionType.td,
      dayIndex: 2,
      startHour: 11,
      endHour: 12.5,
      salle: 'Salle B101',
      enseignant: 'Pr. Haddad',
      groupe: 'L2 — Groupe A',
      description: 'Travaux dirigés — requêtes SQL avancées.',
    ),
    ScheduleEvent(
      title: 'Réseaux — TP',
      type: SessionType.tp,
      dayIndex: 3,
      startHour: 12,
      endHour: 13.5,
      salle: 'Salle Réseau C',
      enseignant: 'Pr. Amina Bouzid',
      groupe: 'L2 — Groupe A',
      description: 'Travaux pratiques — configuration réseau, apportez votre ordinateur portable.',
    ),
    ScheduleEvent(
      title: 'Économie',
      type: SessionType.cm,
      dayIndex: 4,
      startHour: 8,
      endHour: 9.5,
      salle: 'Salle EN5',
      enseignant: 'Pr. Leroy',
      groupe: 'L2 — Groupe A',
      description: 'Travaux pratiques — apportez votre ordinateur portable.',
    ),
    ScheduleEvent(
      title: 'Réseaux — TP',
      type: SessionType.tp,
      dayIndex: 4,
      startHour: 11,
      endHour: 12.5,
      salle: 'Salle Réseau C',
      enseignant: 'Pr. Amina Bouzid',
      groupe: 'L2 — Groupe A',
      description: 'Travaux pratiques — apportez votre ordinateur portable.',
    ),
    ScheduleEvent(
      title: 'Algorithmique',
      type: SessionType.cm,
      dayIndex: 4,
      startHour: 12.5,
      endHour: 13.5,
      salle: 'Salle A204',
      enseignant: 'Pr. Leroy',
      groupe: 'L2 — Groupe A',
      description: 'Cours magistral — complexité algorithmique.',
    ),
    ScheduleEvent(
      title: 'Philosophie — Séminaire',
      type: SessionType.seminaire,
      dayIndex: 5,
      startHour: 8,
      endHour: 9.5,
      salle: 'Salle P207',
      enseignant: 'Pr. Nadia Idrissi',
      groupe: 'L2 — Groupe A',
      description: 'Séminaire — éthique et technologie.',
    ),
  ];
}
