import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/attendance_models.dart';
import '../models/statistics_models.dart';
import '../repositories/academic_repository.dart';

/// Assiduité par étudiant, agrégée depuis les enregistrements de présence.
final studentAttendanceProvider = FutureProvider<List<StudentAttendance>>((ref) {
  return ref.watch(academicRepositoryProvider).getStudentAttendance();
});

/// Synthèse des résultats académiques, calculée depuis les notes saisies.
///
/// `null` signifie « aucune note exploitable » : l'écran affiche alors un état
/// vide plutôt que des pourcentages inventés.
final gradeStatsProvider = FutureProvider<GradeStats?>((ref) {
  return ref.watch(academicRepositoryProvider).getGradeStats();
});
