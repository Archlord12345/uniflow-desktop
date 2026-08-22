import 'package:flutter/material.dart';

/// Un événement de l'historique du dossier étudiant (ex: inscription
/// validée, dossier soumis...), affiché dans la carte "Historique" de la
/// page de détail.
class StudentHistoryEvent {
  final String dateLabel; // ex: "12/09/2023 14:32"
  final String description; // ex: "Inscription validée par Administrateur"
  final Color dotColor;

  const StudentHistoryEvent({
    required this.dateLabel,
    required this.description,
    required this.dotColor,
  });
}

/// Modèle représentant un étudiant : à la fois pour la ligne du tableau
/// de la page "Étudiants" et pour la page de détail complète.
/// Données statiques pour l'instant (voir [Student.mockList]), à
/// remplacer par un appel API plus tard.
class Student {
  // ----- Champs affichés dans le tableau "Étudiants" -----
  final String id;          // identifiant interne, ex: "ST-1021"
  final String matricule;   // "N° Étudiant" affiché, ex: "20230001"
  final String fullName;
  final String email;
  final String programme;   // ex: "Informatique" (colonne "Programme" du tableau)
  final String niveau;      // ex: "Licence 2"
  final String statut;      // "Actif" | "Inactif" | "En échange"
  final Color statutColor;
  final String inscritLe;   // ex: "12/09/2023"
  final Color avatarColor;

  // ----- Champs supplémentaires pour la page de détail -----
  final String dateNaissance;
  final String telephone;
  final String adresse;
  final String genre;
  final String nationalite;
  final String filiere;         // nom complet du programme, ex: "Licence Informatique"
  final String semestre;
  final String specialite;
  final String groupe;
  final String dateInscriptionLongue; // ex: "12 septembre 2023"
  final List<StudentHistoryEvent> historique;

  const Student({
    required this.id,
    required this.matricule,
    required this.fullName,
    required this.email,
    required this.programme,
    required this.niveau,
    required this.statut,
    required this.statutColor,
    required this.inscritLe,
    required this.avatarColor,
    this.dateNaissance = '',
    this.telephone = '',
    this.adresse = '',
    this.genre = '',
    this.nationalite = '',
    this.filiere = '',
    this.semestre = '',
    this.specialite = '',
    this.groupe = '',
    this.dateInscriptionLongue = '',
    this.historique = const [],
  });

  /// Initiales calculées à partir du nom complet (ex: "Ahmed Ben Ahmad" -> "AA")
  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length < 2) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  /// Jeu de données factices reproduisant la maquette "UniFlow Desktop
  /// Partie 1", en attendant le branchement à une vraie source de données.
  static const List<Student> mockList = [
    Student(
      id: 'ST-1021',
      matricule: '20230001',
      fullName: 'Ahmed Ben Ahmad',
      email: 'ahmed@uniflow.edu',
      programme: 'Informatique',
      niveau: 'Licence 2',
      statut: 'Actif',
      statutColor: Color(0xFFDFF5E4),
      inscritLe: '12/09/2023',
      avatarColor: Color(0xFFDCEBFF),
      dateNaissance: '15 jan. 2003',
      telephone: '+237 6 XX XX XX',
      adresse: 'Yaoundé, Cameroun',
      genre: 'Masculin',
      nationalite: 'Camerounaise',
      filiere: 'Licence Informatique',
      semestre: 'Semestre 4',
      specialite: 'Systèmes et Réseaux',
      groupe: 'G2-Info',
      dateInscriptionLongue: '12 septembre 2023',
      historique: [
        StudentHistoryEvent(
          dateLabel: '12/09/2023 14:32',
          description: 'Inscription validée par Administrateur',
          dotColor: Color(0xFF2F5FDB),
        ),
        StudentHistoryEvent(
          dateLabel: '12/09/2023 14:15',
          description: "Dossier soumis par l'étudiant",
          dotColor: Color(0xFF34C77B),
        ),
        StudentHistoryEvent(
          dateLabel: '10/09/2023 10:05',
          description: 'Préinscription effectuée',
          dotColor: Color(0xFF34C77B),
        ),
      ],
    ),
    Student(
      id: 'ST-1022',
      matricule: '20230002',
      fullName: 'Nora El Amine',
      email: 'nora@uniflow.edu',
      programme: 'Informatique',
      niveau: 'Licence 2',
      statut: 'Actif',
      statutColor: Color(0xFFDFF5E4),
      inscritLe: '12/09/2023',
      avatarColor: Color(0xFFF1E4FF),
      dateNaissance: '22 mars 2003',
      telephone: '+237 6 XX XX XX',
      adresse: 'Douala, Cameroun',
      genre: 'Féminin',
      nationalite: 'Camerounaise',
      filiere: 'Licence Informatique',
      semestre: 'Semestre 4',
      specialite: 'Génie Logiciel',
      groupe: 'G1-Info',
      dateInscriptionLongue: '12 septembre 2023',
      historique: [
        StudentHistoryEvent(
          dateLabel: '12/09/2023 09:10',
          description: 'Inscription validée par Administrateur',
          dotColor: Color(0xFF2F5FDB),
        ),
      ],
    ),
    Student(
      id: 'ST-1023',
      matricule: '20230003',
      fullName: 'Julien Bernard',
      email: 'julien@uniflow.edu',
      programme: 'Mathématiques',
      niveau: 'Licence 3',
      statut: 'En échange',
      statutColor: Color(0xFFFFE9CC),
      inscritLe: '15/09/2023',
      avatarColor: Color(0xFFFFE9CC),
      dateNaissance: '02 juil. 2002',
      telephone: '+33 6 XX XX XX',
      adresse: 'Lyon, France',
      genre: 'Masculin',
      nationalite: 'Française',
      filiere: 'Licence Mathématiques',
      semestre: 'Semestre 6',
      specialite: 'Mathématiques Appliquées',
      groupe: 'Échange-L3',
      dateInscriptionLongue: '15 septembre 2023',
      historique: [
        StudentHistoryEvent(
          dateLabel: '15/09/2023 08:40',
          description: "Statut d'échange activé",
          dotColor: Color(0xFFF5A623),
        ),
      ],
    ),
    Student(
      id: 'ST-1024',
      matricule: '20230004',
      fullName: 'Amina Fofana',
      email: 'amina@uniflow.edu',
      programme: 'Économie',
      niveau: 'Master 1',
      statut: 'Actif',
      statutColor: Color(0xFFDFF5E4),
      inscritLe: '10/09/2023',
      avatarColor: Color(0xFFFFE0E9),
      dateNaissance: '11 nov. 2000',
      telephone: '+237 6 XX XX XX',
      adresse: 'Yaoundé, Cameroun',
      genre: 'Féminin',
      nationalite: 'Camerounaise',
      filiere: "Master Économie et Gestion",
      semestre: 'Semestre 1',
      specialite: 'Finance',
      groupe: 'M1-Eco',
      dateInscriptionLongue: '10 septembre 2023',
      historique: [
        StudentHistoryEvent(
          dateLabel: '10/09/2023 11:00',
          description: 'Inscription validée par Administrateur',
          dotColor: Color(0xFF2F5FDB),
        ),
      ],
    ),
    Student(
      id: 'ST-1025',
      matricule: '20230005',
      fullName: 'Yassine Zohra',
      email: 'yassine@uniflow.edu',
      programme: 'Informatique',
      niveau: 'Licence 1',
      statut: 'Inactif',
      statutColor: Color(0xFFE7E9F0),
      inscritLe: '20/09/2023',
      avatarColor: Color(0xFFD3F5EC),
      dateNaissance: '05 mai 2005',
      telephone: '+237 6 XX XX XX',
      adresse: 'Bafoussam, Cameroun',
      genre: 'Masculin',
      nationalite: 'Camerounaise',
      filiere: 'Licence Informatique',
      semestre: 'Semestre 1',
      specialite: 'Non spécifiée',
      groupe: 'G3-Info',
      dateInscriptionLongue: '20 septembre 2023',
      historique: [
        StudentHistoryEvent(
          dateLabel: '20/09/2023 15:20',
          description: 'Compte désactivé (absences répétées)',
          dotColor: Color(0xFFE85C5C),
        ),
      ],
    ),
    Student(
      id: 'ST-1026',
      matricule: '20230006',
      fullName: 'Mélanie Assouad',
      email: 'melanie@uniflow.edu',
      programme: 'Droit',
      niveau: 'Licence 2',
      statut: 'Actif',
      statutColor: Color(0xFFDFF5E4),
      inscritLe: '12/09/2023',
      avatarColor: Color(0xFFDCEBFF),
      dateNaissance: '18 sept. 2003',
      telephone: '+237 6 XX XX XX',
      adresse: 'Yaoundé, Cameroun',
      genre: 'Féminin',
      nationalite: 'Camerounaise',
      filiere: 'Licence Droit',
      semestre: 'Semestre 4',
      specialite: 'Droit des Affaires',
      groupe: 'G1-Droit',
      dateInscriptionLongue: '12 septembre 2023',
      historique: [
        StudentHistoryEvent(
          dateLabel: '12/09/2023 13:05',
          description: 'Inscription validée par Administrateur',
          dotColor: Color(0xFF2F5FDB),
        ),
      ],
    ),
  ];
}
