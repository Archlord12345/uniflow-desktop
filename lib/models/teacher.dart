import 'package:flutter/material.dart';
import 'appwrite_models.dart';

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
/// page de détail. Construit depuis l'annuaire académique Appwrite
/// (voir [Teacher.fromDirectory]).
class Teacher {
  final String id; // ex: "TCH001"
  final String
      fullName; // ex: "Youssef El Khatabi" (le "Pr." est ajouté à l'affichage)
  final String email;
  final String departement;
  final String statut; // "Actif" | "Inactif"
  final Color statutColor;
  final Color avatarColor;

  // ----- Champs supplémentaires pour la page de détail -----
  final String telephone;
  final String specialite;
  final String dateEmbauche;
  final int coursActifs;
  final List<TeacherHistoryEvent> historique;

  // ----- Identité Appwrite -----
  /// Identifiant du compte Appwrite, utilisé par la messagerie et les
  /// collections académiques ; [id] reste l'identifiant interne d'affichage.
  final String userId;

  /// Pseudo unique, référent de la messagerie.
  final String? username;

  /// Fichier de la photo de profil dans le bucket `uniflow_assets`.
  final String? avatarFileId;

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
    this.userId = '',
    this.username,
    this.avatarFileId,
  });

  /// Construit un enseignant à partir d'une entrée de l'annuaire Appwrite.
  ///
  /// Les champs absents de la base (téléphone, date d'embauche, historique…)
  /// restent vides : l'interface affiche un tiret plutôt qu'une donnée
  /// inventée.
  factory Teacher.fromDirectory(AcademicDirectoryEntry entry) {
    return Teacher(
      id: entry.userId,
      userId: entry.userId,
      fullName: entry.name,
      email: entry.email ?? '',
      departement: entry.program,
      specialite: entry.program,
      statut: directoryStatusLabel(entry.status),
      statutColor: directoryStatusColor(entry.status),
      avatarColor: const Color(0xFFDCEBFF),
      username: entry.username,
      avatarFileId: entry.avatarFileId,
    );
  }

  /// Initiales calculées à partir du nom complet (ex: "Youssef El Khatabi" -> "YE")
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
