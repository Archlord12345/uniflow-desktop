import 'package:flutter/material.dart';
import 'appwrite_models.dart';

/// Modèle représentant une Unité d'Enseignement (UE), pour la page
/// "Gestion des UE".
///
/// Les UE proviennent de la collection `academic_courses` d'Appwrite et leurs
/// effectifs de `academic_enrollments`. Les champs que la base ne stocke pas
/// — semestre, capacité d'accueil, statut — restent vides : l'interface
/// affiche un tiret au lieu d'une valeur inventée.
class TeachingUnit {
  /// Identifiant du document `academic_courses`.
  final String id;

  final String code; // ex: "INF301"
  final String intitule; // ex: "Intelligence Artificielle"
  final String semestre; // absent de la base -> ''
  final String departement; // `program` du cours
  final String niveau; // ex: "L3"
  final String type; // ex: "Cours Magistral" -> '' si non renseigné
  final String enseignant; // `teacherName` du cours
  final int credits;
  final int heures;
  final int inscrits; // nombre d'entrées `academic_enrollments`
  final int placesTotal; // absent de la base -> 0, donc taux inconnu
  final String statut; // absent de la base -> ''

  const TeachingUnit({
    required this.id,
    required this.code,
    required this.intitule,
    required this.semestre,
    required this.departement,
    required this.niveau,
    required this.type,
    required this.enseignant,
    required this.credits,
    required this.heures,
    required this.inscrits,
    required this.placesTotal,
    required this.statut,
  });

  /// Construit une UE depuis un document `academic_courses`.
  ///
  /// [inscrits] est compté séparément dans `academic_enrollments` : la
  /// collection ne porte pas de total d'inscrits.
  factory TeachingUnit.fromCourse(AcademicCourse course, {int inscrits = 0}) {
    final type = (course.type ?? '').trim();
    return TeachingUnit(
      id: course.id,
      code: course.code,
      intitule: course.name,
      semestre: '',
      departement: course.program,
      niveau: directoryLevelLabel(course.level),
      type: type,
      enseignant: (course.teacherName ?? '').trim(),
      credits: course.credits ?? 0,
      heures: course.hours ?? 0,
      inscrits: inscrits,
      placesTotal: 0,
      statut: '',
    );
  }

  /// Couleur du badge de type, dérivée du libellé stocké en base.
  Color get typeColor {
    switch (type.toLowerCase()) {
      case 'cours magistral':
        return const Color(0xFFE4DEFF);
      case 'travaux pratiques':
      case 'tp':
        return const Color(0xFFF1E4FF);
      case 'travaux dirigés':
      case 'td':
        return const Color(0xFFDCEBFF);
      default:
        return const Color(0xFFE7E9F0);
    }
  }

  /// Taux de remplissage en pourcentage (ex: 85/100 -> 85).
  ///
  /// Renvoie `null` quand la capacité d'accueil n'est pas stockée : mieux vaut
  /// ne rien afficher qu'un « 0 % » qui laisserait croire à une UE vide.
  int? get tauxRemplissage =>
      placesTotal <= 0 ? null : ((inscrits / placesTotal) * 100).round();
}
