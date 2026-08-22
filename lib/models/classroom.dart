import 'package:flutter/material.dart';

/// Modèle représentant une salle, pour la page "Salles" (Gestion des Salles).
/// Données statiques pour l'instant (voir [Classroom.mockList]), à
/// remplacer par un appel API plus tard.
class Classroom {
  final String code;       // ex: "S101"
  final String nom;        // ex: "Amphi 101"
  final int capacite;
  final String type;       // ex: "Amphithéâtre", "Salle de cours"...
  final String batiment;   // ex: "Bâtiment A"
  final String statut;     // "Disponible" | "Occupée" | "Maintenance"
  final Color statutColor;

  const Classroom({
    required this.code,
    required this.nom,
    required this.capacite,
    required this.type,
    required this.batiment,
    required this.statut,
    required this.statutColor,
  });

  /// Jeu de données factices reproduisant la maquette "Classroom Management".
  static const List<Classroom> mockList = [
    Classroom(
      code: 'S101',
      nom: 'Amphi 101',
      capacite: 120,
      type: 'Amphithéâtre',
      batiment: 'Bâtiment A',
      statut: 'Disponible',
      statutColor: Color(0xFFDFF5E4),
    ),
    Classroom(
      code: 'S102',
      nom: 'Salle 102',
      capacite: 40,
      type: 'Salle de cours',
      batiment: 'Bâtiment A',
      statut: 'Disponible',
      statutColor: Color(0xFFDFF5E4),
    ),
    Classroom(
      code: 'S201',
      nom: 'Salle Info 1',
      capacite: 30,
      type: 'Salle Informatique',
      batiment: 'Bâtiment B',
      statut: 'Occupée',
      statutColor: Color(0xFFFFE9CC),
    ),
    Classroom(
      code: 'S202',
      nom: 'Salle Info 2',
      capacite: 30,
      type: 'Salle Informatique',
      batiment: 'Bâtiment B',
      statut: 'Disponible',
      statutColor: Color(0xFFDFF5E4),
    ),
    Classroom(
      code: 'S301',
      nom: 'Laboratoire Chimie',
      capacite: 25,
      type: 'Laboratoire',
      batiment: 'Bâtiment C',
      statut: 'Maintenance',
      statutColor: Color(0xFFFFE0E9),
    ),
  ];
}
