import 'appwrite_models.dart';
import 'attendance_models.dart';
import 'user_role.dart';

/// Chiffres du tableau de bord d'un apprenant, d'un délégué ou d'un
/// enseignant, calqués sur `DashboardPage.tsx` du web pour que les deux
/// clients racontent la même chose au même utilisateur.
///
/// Tout est calculé ici, sans widget, pour être testable : le web affichait
/// des « 0 » codés en dur là où la donnée manquait ; ici une valeur absente
/// est `null` et l'écran affiche « — ».
class DashboardOverview {
  /// Cours dans le périmètre : inscrits (apprenant) ou donnés (enseignant).
  final int courseCount;

  /// Devoirs à rendre (apprenant) ou devoirs créés (enseignant).
  final int assignmentCount;

  /// Notes reçues (apprenant) ou saisies (enseignant).
  final int gradeCount;

  /// Moyenne pondérée sur 20 ; `null` sans aucune note.
  final double? averageOn20;

  /// Taux de présence (0..1) ; `null` sans aucun enregistrement.
  final double? attendanceRate;

  /// Étudiants suivis (enseignant, délégué).
  final int studentCount;

  const DashboardOverview({
    required this.courseCount,
    required this.assignmentCount,
    required this.gradeCount,
    required this.averageOn20,
    required this.attendanceRate,
    required this.studentCount,
  });

  static const empty = DashboardOverview(
    courseCount: 0,
    assignmentCount: 0,
    gradeCount: 0,
    averageOn20: null,
    attendanceRate: null,
    studentCount: 0,
  );

  /// Statuts après lesquels un devoir n'est plus « à rendre ».
  static const Set<String> _closedStatuses = {'SUBMITTED', 'GRADED'};

  static DashboardOverview compute({
    required UserRole role,
    required String userId,
    required List<AcademicCourse> courses,
    required List<AcademicAssignment> assignments,
    required List<AcademicGrade> grades,
    required List<StudentAttendance> attendance,
    required int studentCount,
  }) {
    final courseIds = courses.map((c) => c.id).toSet();
    final inScope =
        assignments.where((a) => courseIds.contains(a.courseId)).toList();

    final Iterable<AcademicAssignment> counted;
    final Iterable<AcademicGrade> myGrades;
    if (role.isLearning) {
      // Un devoir adressé à toute la promotion n'a pas de `studentId`.
      counted = inScope.where((a) =>
          (a.studentId.isEmpty || a.studentId == userId) &&
          a.submittedAt == null &&
          !_closedStatuses.contains((a.status ?? '').toUpperCase()));
      myGrades = grades.where((g) => g.studentId == userId);
    } else {
      counted = inScope;
      myGrades = grades.where((g) => courseIds.contains(g.courseId));
    }

    return DashboardOverview(
      courseCount: courses.length,
      assignmentCount: counted.length,
      gradeCount: myGrades.length,
      averageOn20: _weightedAverage(myGrades),
      attendanceRate: role.isLearning
          ? _ownRate(attendance, userId)
          : _meanRate(attendance),
      studentCount: studentCount,
    );
  }

  /// Moyenne sur 20 pondérée par les coefficients ; les notes sur autre chose
  /// que 20 sont ramenées à 20 avant d'être pondérées.
  static double? _weightedAverage(Iterable<AcademicGrade> grades) {
    var weighted = 0.0;
    var weights = 0.0;
    for (final g in grades) {
      if (g.maxScore <= 0) continue;
      final coefficient = g.coefficient <= 0 ? 1.0 : g.coefficient;
      weighted += (g.score / g.maxScore) * 20 * coefficient;
      weights += coefficient;
    }
    if (weights == 0) return null;
    return weighted / weights;
  }

  static double? _ownRate(List<StudentAttendance> attendance, String userId) {
    for (final entry in attendance) {
      if (entry.studentId == userId) {
        return entry.total == 0 ? null : entry.rate;
      }
    }
    return null;
  }

  static double? _meanRate(List<StudentAttendance> attendance) {
    final withRecords = attendance.where((e) => e.total > 0).toList();
    if (withRecords.isEmpty) return null;
    final sum = withRecords.fold<double>(0, (acc, e) => acc + e.rate);
    return sum / withRecords.length;
  }

  /// « 14,5/20 » ou « — ».
  String get averageLabel => averageOn20 == null
      ? '—'
      : '${averageOn20!.toStringAsFixed(1).replaceAll('.', ',')}/20';

  /// « 92 % » ou « — ».
  String get attendanceLabel =>
      attendanceRate == null ? '—' : '${(attendanceRate! * 100).round()} %';
}
