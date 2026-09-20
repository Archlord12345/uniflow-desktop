/// Agrégats calculés à partir des notes de `academic_grades`.
///
/// Ces valeurs ne sont pas stockées : elles sont recalculées à chaque
/// affichage pour rester cohérentes avec les notes saisies.
library;

/// Une UE et sa moyenne sur 20.
class CourseAverage {
  final String courseCode;
  final double averageOn20;
  final int gradeCount;

  const CourseAverage({
    required this.courseCode,
    required this.averageOn20,
    required this.gradeCount,
  });

  String get label =>
      '${averageOn20.toStringAsFixed(1).replaceAll('.', ',')}/20';
}

/// Une tranche de notes et son effectif, pour l'histogramme.
class GradeBand {
  final String label;
  final int count;

  const GradeBand({required this.label, required this.count});
}

/// Synthèse des résultats académiques.
class GradeStats {
  final int gradeCount;

  /// Moyenne générale sur 20, pondérée par les coefficients.
  final double averageOn20;

  /// Part des notes au-dessus de la moyenne (0..1).
  final double successRate;

  /// Meilleures UE par moyenne, les plus hautes d'abord.
  final List<CourseAverage> topCourses;

  /// Répartition des notes en tranches, dans l'ordre croissant.
  final List<GradeBand> bands;

  const GradeStats({
    required this.gradeCount,
    required this.averageOn20,
    required this.successRate,
    required this.topCourses,
    required this.bands,
  });

  String get averageLabel =>
      '${averageOn20.toStringAsFixed(1).replaceAll('.', ',')}/20';

  String get successRateLabel =>
      '${(successRate * 100).toStringAsFixed(1).replaceAll('.', ',')}%';
}
