import 'package:flutter/material.dart';

/// Un événement de l'historique du dossier enseignant.
class TeacherHistoryEvent {
  final String dateLabel;
  final String description;
  final Color dotColor;

  const TeacherHistoryEvent({
    required this.dateLabel,
    required this.description,
    required this.dotColor,
  });
}

/// Modèle représentant un enseignant, pour la page "Enseignants" et sa
/// page de détail. Données statiques pour l'instant (voir [Teacher.mockList]),
/// à remplacer par un appel API plus tard.
class Teacher {
  final String id;         // ex: "TCH001"
  final String fullName;   // ex: "Youssef El Khatabi" (le "Pr." est ajouté à l'affichage)
  final String email;
  final String departement;
  final String statut;     // "Actif" | "Inactif"
  final Color statutColor;
  final Color avatarColor;

  // ----- Champs supplémentaires pour la page de détail -----
  final String telephone;
  final String specialite;
  final String dateEmbauche;
  final int coursActifs;
  final List<TeacherHistoryEvent> historique;

  const Teacher({
    required this.id,
    required this.fullName,
    required this.email,
    required this.departement,
    required this.statut,
    required this.statutColor,
    required this.avatarColor,
    this.telephone = '',
    this.specialite = '',
    this.dateEmbauche = '',
    this.coursActifs = 0,
    this.historique = const [],
  });

  /// Initiales calculées à partir du nom complet (ex: "Youssef El Khatabi" -> "YE")
  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length < 2) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  /// Jeu de données factices reproduisant la maquette "Teachers Management".
  static const List<Teacher> mockList = [
    Teacher(
      id: 'TCH001',
      fullName: 'Youssef El Khatabi',
      email: 'youssef.elkhatabi@uniflow.edu',
      departement: 'Informatique',
      statut: 'Actif',
      statutColor: Color(0xFFDFF5E4),
      avatarColor: Color(0xFFDCEBFF),
      telephone: '+212 6 XX XX XX',
      specialite: 'Intelligence Artificielle',
      dateEmbauche: '03 septembre 2018',
      coursActifs: 4,
      historique: [
        TeacherHistoryEvent(
          dateLabel: '01/09/2024 09:00',
          description: 'Affecté au module "Structures de Données"',
          dotColor: Color(0xFF2F5FDB),
        ),
        TeacherHistoryEvent(
          dateLabel: '15/06/2024 14:20',
          description: 'Notes du semestre validées',
          dotColor: Color(0xFF34C77B),
        ),
      ],
    ),
    Teacher(
      id: 'TCH002',
      fullName: 'Amina Bouzid',
      email: 'amina.bouzid@uniflow.edu',
      departement: 'Génie Civil',
      statut: 'Actif',
      statutColor: Color(0xFFDFF5E4),
      avatarColor: Color(0xFFF1E4FF),
      telephone: '+212 6 XX XX XX',
      specialite: 'Structures et Matériaux',
      dateEmbauche: '12 janvier 2020',
      coursActifs: 3,
      historique: [
        TeacherHistoryEvent(
          dateLabel: '01/09/2024 09:00',
          description: 'Affectée au module "Résistance des Matériaux"',
          dotColor: Color(0xFF2F5FDB),
        ),
      ],
    ),
    Teacher(
      id: 'TCH003',
      fullName: 'Karim Zerouali',
      email: 'karim.zerouali@uniflow.edu',
      departement: 'Mathématiques',
      statut: 'Actif',
      statutColor: Color(0xFFDFF5E4),
      avatarColor: Color(0xFFFFE9CC),
      telephone: '+212 6 XX XX XX',
      specialite: 'Analyse Numérique',
      dateEmbauche: '20 septembre 2015',
      coursActifs: 5,
      historique: [
        TeacherHistoryEvent(
          dateLabel: '01/09/2024 09:00',
          description: 'Affecté au module "Mathématiques Discrètes 1"',
          dotColor: Color(0xFF2F5FDB),
        ),
      ],
    ),
    Teacher(
      id: 'TCH004',
      fullName: 'Leila Haddad',
      email: 'leila.haddad@uniflow.edu',
      departement: 'Management',
      statut: 'Inactif',
      statutColor: Color(0xFFE7E9F0),
      avatarColor: Color(0xFFFFE0E9),
      telephone: '+212 6 XX XX XX',
      specialite: 'Gestion de Projet',
      dateEmbauche: '05 mars 2019',
      coursActifs: 0,
      historique: [
        TeacherHistoryEvent(
          dateLabel: '10/07/2024 11:00',
          description: 'Compte mis en pause (congé sabbatique)',
          dotColor: Color(0xFFF5A623),
        ),
      ],
    ),
    Teacher(
      id: 'TCH005',
      fullName: 'Reda Mouline',
      email: 'reda.mouline@uniflow.edu',
      departement: 'Économie',
      statut: 'Actif',
      statutColor: Color(0xFFDFF5E4),
      avatarColor: Color(0xFFD3F5EC),
      telephone: '+212 6 XX XX XX',
      specialite: 'Macroéconomie',
      dateEmbauche: '14 octobre 2021',
      coursActifs: 2,
      historique: [
        TeacherHistoryEvent(
          dateLabel: '01/09/2024 09:00',
          description: 'Affecté au module "Principes Économiques"',
          dotColor: Color(0xFF2F5FDB),
        ),
      ],
    ),
    Teacher(
      id: 'TCH006',
      fullName: 'Sofia Amrani',
      email: 'sofia.amrani@uniflow.edu',
      departement: 'Droit',
      statut: 'Actif',
      statutColor: Color(0xFFDFF5E4),
      avatarColor: Color(0xFFDCEBFF),
      telephone: '+212 6 XX XX XX',
      specialite: 'Droit des Affaires',
      dateEmbauche: '18 février 2017',
      coursActifs: 3,
      historique: [
        TeacherHistoryEvent(
          dateLabel: '01/09/2024 09:00',
          description: 'Affectée au module "Droit des Sociétés"',
          dotColor: Color(0xFF2F5FDB),
        ),
      ],
    ),
  ];
}
