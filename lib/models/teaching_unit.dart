import 'package:flutter/material.dart';

/// Modèle représentant une Unité d'Enseignement (UE), pour la page
/// "Gestion des UE". Données statiques pour l'instant (voir
/// [TeachingUnit.mockList]), à remplacer par un appel API plus tard.
class TeachingUnit {
  final String code;         // ex: "INF301"
  final String intitule;     // ex: "Intelligence Artificielle"
  final String semestre;     // ex: "S5"
  final String departement;  // ex: "Informatique"
  final String niveau;       // ex: "L3"
  final String type;         // "Cours Magistral" | "Travaux Pratiques"
  final Color typeColor;
  final String enseignant;
  final int credits;
  final int heures;
  final int inscrits;
  final int placesTotal;
  final String statut;       // "Active" | "Planifiée" | "Archivée"
  final Color statutColor;

  const TeachingUnit({
    required this.code,
    required this.intitule,
    required this.semestre,
    required this.departement,
    required this.niveau,
    required this.type,
    required this.typeColor,
    required this.enseignant,
    required this.credits,
    required this.heures,
    required this.inscrits,
    required this.placesTotal,
    required this.statut,
    required this.statutColor,
  });

  /// Taux de remplissage en pourcentage (ex: 85/100 -> 85)
  int get tauxRemplissage => placesTotal == 0 ? 0 : ((inscrits / placesTotal) * 100).round();

  /// Jeu de données factices reproduisant la maquette "Gestion des UE".
  static const List<TeachingUnit> mockList = [
    TeachingUnit(
      code: 'INF301',
      intitule: 'Intelligence Artificielle',
      semestre: 'S5',
      departement: 'Informatique',
      niveau: 'L3',
      type: 'Cours Magistral',
      typeColor: Color(0xFFE4DEFF),
      enseignant: 'Pr. Martin Dupont',
      credits: 6,
      heures: 48,
      inscrits: 85,
      placesTotal: 100,
      statut: 'Active',
      statutColor: Color(0xFFDFF5E4),
    ),
    TeachingUnit(
      code: 'INF302',
      intitule: 'Bases de Données Avancées',
      semestre: 'S5',
      departement: 'Informatique',
      niveau: 'L3',
      type: 'Cours Magistral',
      typeColor: Color(0xFFE4DEFF),
      enseignant: 'Dr. Sophie Kamga',
      credits: 5,
      heures: 42,
      inscrits: 78,
      placesTotal: 80,
      statut: 'Active',
      statutColor: Color(0xFFDFF5E4),
    ),
    TeachingUnit(
      code: 'INF201',
      intitule: 'Structures de Données',
      semestre: 'S3',
      departement: 'Informatique',
      niveau: 'L2',
      type: 'Cours Magistral',
      typeColor: Color(0xFFE4DEFF),
      enseignant: 'Dr. Marie Ngo Bisse',
      credits: 6,
      heures: 48,
      inscrits: 120,
      placesTotal: 120,
      statut: 'Active',
      statutColor: Color(0xFFDFF5E4),
    ),
    TeachingUnit(
      code: 'MAT401',
      intitule: 'Analyse Numérique',
      semestre: 'S7',
      departement: 'Mathématiques',
      niveau: 'M1',
      type: 'Cours Magistral',
      typeColor: Color(0xFFE4DEFF),
      enseignant: 'Pr. Jean Mbida',
      credits: 7,
      heures: 54,
      inscrits: 42,
      placesTotal: 50,
      statut: 'Active',
      statutColor: Color(0xFFDFF5E4),
    ),
    TeachingUnit(
      code: 'INF101',
      intitule: 'Introduction à la Programmation',
      semestre: 'S1',
      departement: 'Informatique',
      niveau: 'L1',
      type: 'Cours Magistral',
      typeColor: Color(0xFFE4DEFF),
      enseignant: 'Dr. Alice Fouda',
      credits: 6,
      heures: 60,
      inscrits: 0,
      placesTotal: 150,
      statut: 'Planifiée',
      statutColor: Color(0xFFFFE9CC),
    ),
    TeachingUnit(
      code: 'INF205',
      intitule: 'Réseaux Informatiques',
      semestre: 'S4',
      departement: 'Informatique',
      niveau: 'L2',
      type: 'Travaux Pratiques',
      typeColor: Color(0xFFF1E4FF),
      enseignant: 'Dr. Marie Ngo Bisse',
      credits: 5,
      heures: 45,
      inscrits: 95,
      placesTotal: 100,
      statut: 'Active',
      statutColor: Color(0xFFDFF5E4),
    ),
    TeachingUnit(
      code: 'ECO301',
      intitule: 'Économétrie Avancée',
      semestre: 'S6',
      departement: 'Économie',
      niveau: 'L3',
      type: 'Cours Magistral',
      typeColor: Color(0xFFE4DEFF),
      enseignant: 'Pr. Paul Essomba',
      credits: 6,
      heures: 48,
      inscrits: 68,
      placesTotal: 80,
      statut: 'Archivée',
      statutColor: Color(0xFFE7E9F0),
    ),
  ];
}
