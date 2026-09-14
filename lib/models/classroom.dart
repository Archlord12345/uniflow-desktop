/// Modèle représentant une salle, pour la page "Salles" (Gestion des Salles).
///
/// Appwrite ne possède pas de collection `classrooms` : le nom de la salle est
/// un simple champ texte sur `academic_schedules` et `academic_courses`. Les
/// salles listées ici sont donc les valeurs distinctes réellement planifiées,
/// agrégées avec leur nombre de créneaux — et non un catalogue de salles
/// (capacité, bâtiment, statut) que la base ne contient pas.
class Classroom {
  /// Libellé de la salle tel qu'il est stocké dans l'emploi du temps.
  final String nom;

  /// Nombre de créneaux d'emploi du temps qui s'y tiennent.
  final int creneaux;

  /// Nombre d'UE distinctes qui y sont planifiées.
  final int cours;

  /// Type de créneau, quand tous ceux de la salle partagent le même.
  final String type;

  const Classroom({
    required this.nom,
    required this.creneaux,
    required this.cours,
    this.type = '',
  });
}
