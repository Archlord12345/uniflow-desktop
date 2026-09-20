/// Modèle d'une salle pour la page « Salles ».
///
/// Deux sources se rejoignent ici : le référentiel `classrooms` (catalogue
/// déclaré par l'administration : code, nature, capacité, bâtiment — ajouté
/// au schéma le 2026-09-20) et l'emploi du temps, dont le champ texte
/// `classroom` donne l'occupation réelle. Une salle planifiée mais absente du
/// catalogue reste visible, sans capacité ni bâtiment.
class Classroom {
  /// Libellé affiché (code, ou « code · nom » quand la salle est au catalogue).
  final String nom;

  /// Nombre de créneaux d'emploi du temps qui s'y tiennent.
  final int creneaux;

  /// Nombre d'UE distinctes qui y sont planifiées.
  final int cours;

  /// Nature (« AMPHI », « SALLE », « LABO »…) ou type de créneau dominant.
  final String type;

  /// Capacité déclarée au catalogue, 0 si inconnue.
  final int capacite;

  /// Bâtiment déclaré au catalogue.
  final String batiment;

  /// Identifiant du document `classrooms`, vide si la salle n'y est pas.
  final String referenceId;

  const Classroom({
    required this.nom,
    required this.creneaux,
    required this.cours,
    this.type = '',
    this.capacite = 0,
    this.batiment = '',
    this.referenceId = '',
  });

  bool get isCatalogued => referenceId.isNotEmpty;
}
