import 'package:flutter/material.dart';
import 'appwrite_models.dart';

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
/// Construit depuis l'annuaire académique Appwrite
/// (voir [Student.fromDirectory]).
class Student {
  // ----- Champs affichés dans le tableau "Étudiants" -----
  final String id; // identifiant interne, ex: "ST-1021"
  final String matricule; // "N° Étudiant" affiché, ex: "20230001"
  final String fullName;
  final String email;
  final String programme; // ex: "Informatique" (colonne "Programme" du tableau)
  final String niveau; // ex: "Licence 2"
  final String statut; // "Actif" | "Inactif" | "En échange"
  final Color statutColor;
  final String inscritLe; // ex: "12/09/2023"
  final Color avatarColor;

  // ----- Champs supplémentaires pour la page de détail -----
  final String dateNaissance;
  final String telephone;
  final String adresse;
  final String genre;
  final String nationalite;
  final String filiere; // nom complet du programme, ex: "Licence Informatique"
  final String semestre;
  final String specialite;
  final String groupe;
  final String dateInscriptionLongue; // ex: "12 septembre 2023"
  final List<StudentHistoryEvent> historique;

  // ----- Identité Appwrite -----
  /// Identifiant du compte Appwrite. C'est lui qui référence l'étudiant dans
  /// les collections académiques et dans la messagerie ; [id] reste
  /// l'identifiant interne d'affichage.
  final String userId;

  /// Pseudo unique, référent de la messagerie.
  final String? username;

  /// Fichier de la photo de profil dans le bucket `uniflow_assets`.
  final String? avatarFileId;

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
    this.userId = '',
    this.username,
    this.avatarFileId,
  });

  /// Construit un étudiant à partir d'une entrée de l'annuaire Appwrite.
  ///
  /// Les champs que la base ne contient pas (adresse, téléphone, date de
  /// naissance, historique…) restent à leur valeur par défaut : l'interface
  /// affiche alors un tiret plutôt qu'une donnée inventée.
  factory Student.fromDirectory(AcademicDirectoryEntry entry) {
    return Student(
      id: entry.userId,
      userId: entry.userId,
      matricule: entry.matricule ?? '',
      fullName: entry.name,
      email: entry.email ?? '',
      programme: entry.program,
      niveau: directoryLevelLabel(entry.level),
      statut: directoryStatusLabel(entry.status),
      statutColor: directoryStatusColor(entry.status),
      inscritLe: '',
      avatarColor: const Color(0xFFDCEBFF),
      filiere: entry.program,
      username: entry.username,
      avatarFileId: entry.avatarFileId,
    );
  }

  /// Initiales calculées à partir du nom complet (ex: "Ahmed Ben Ahmad" -> "AA")
  String get initials {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}
