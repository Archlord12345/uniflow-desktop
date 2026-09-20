/// Modèles d'agrégats du tableau de bord.
///
/// Ce ne sont pas des documents Appwrite mais des résultats de calcul : ils
/// vivent donc à part de `appwrite_models.dart`, qui décrit le schéma des
/// collections.

/// Nombre d'inscriptions enregistrées sur un mois donné.
class MonthlyCount {
  final DateTime month;
  final int count;

  const MonthlyCount({required this.month, required this.count});

  static const List<String> _shortMonths = [
    'Jan',
    'Fév',
    'Mar',
    'Avr',
    'Mai',
    'Juin',
    'Juil',
    'Août',
    'Sep',
    'Oct',
    'Nov',
    'Déc',
  ];

  /// Libellé d'axe, ex. « Mai ».
  String get label => _shortMonths[month.month - 1];
}

/// Répartition des présences d'une période : présents, absents, retards.
///
/// Vaut `null` côté dépôt lorsque la collection de présences est absente ou
/// illisible : l'écran affiche alors l'absence de données plutôt qu'une
/// répartition inventée.
class AttendanceBreakdown {
  final int present;
  final int absent;
  final int late;

  const AttendanceBreakdown({
    required this.present,
    required this.absent,
    required this.late,
  });

  int get total => present + absent + late;

  /// Part en pourcentage, arrondie à l'unité. Renvoie 0 si le total est nul.
  double percentOf(int value) => total == 0 ? 0 : (value * 100) / total;
}

/// Nature d'une entrée du fil « Activités récentes ».
enum ActivityKind { enrollment, course, schedule }

/// Un document récemment créé, toutes collections confondues.
class ActivityEntry {
  final ActivityKind kind;

  /// Nom de l'objet concerné (personne, cours, salle).
  final String subject;
  final DateTime createdAt;

  const ActivityEntry({
    required this.kind,
    required this.subject,
    required this.createdAt,
  });
}
