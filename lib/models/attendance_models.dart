/// Assiduité d'un étudiant, agrégée depuis les enregistrements de présence.
///
/// Le statut n'est pas un champ de la base : il est dérivé du nombre
/// d'absences, pour qu'une même règle s'applique partout dans l'application.
class StudentAttendance {
  final String studentId;
  final String name;
  final String matricule;
  final int present;
  final int absent;
  final int late;

  const StudentAttendance({
    required this.studentId,
    required this.name,
    required this.matricule,
    required this.present,
    required this.absent,
    required this.late,
  });

  /// Nombre d'absences à partir duquel un étudiant est signalé.
  static const int watchThreshold = 3;
  static const int alertThreshold = 5;

  int get total => present + absent + late;

  /// Taux de présence (0..1) ; vaut 0 sans aucun enregistrement.
  double get rate => total == 0 ? 0 : present / total;

  /// Taux formaté à la française, ex. « 92,3% ».
  String get rateLabel =>
      '${(rate * 100).toStringAsFixed(1).replaceAll('.', ',')}%';

  AttendanceStatus get status {
    if (absent >= alertThreshold) return AttendanceStatus.alert;
    if (absent >= watchThreshold) return AttendanceStatus.watch;
    return AttendanceStatus.regular;
  }
}

enum AttendanceStatus {
  regular('Régulier'),
  watch('À surveiller'),
  alert('Alerte');

  final String label;
  const AttendanceStatus(this.label);
}
