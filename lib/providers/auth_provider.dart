import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/appwrite_models.dart';
import '../models/user_role.dart';
import '../models/visibility_scope.dart';
import '../repositories/academic_repository.dart';
import '../repositories/auth_repository.dart';

final currentUserProvider = StateProvider<UniFlowUser?>((ref) => null);

final sessionCheckProvider = FutureProvider<void>((ref) async {
  final authRepo = ref.read(authRepositoryProvider);
  // Préférence « Rester connecté » désactivée : la session persistée par le
  // SDK est fermée au lancement, l'utilisateur repasse par l'écran de
  // connexion — c'est ce que l'interrupteur promet.
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('prefs.keepSession') == false) {
      try {
        await authRepo.logout();
      } catch (_) {}
      ref.read(currentUserProvider.notifier).state = null;
      return;
    }
  } catch (_) {}
  final user = await authRepo.getCurrentUser();
  ref.read(currentUserProvider.notifier).state = user;
});

/// Rôle de la session courante. `STUDENT` quand personne n'est connecté :
/// c'est le rôle le moins permissif, aucun écran d'administration ne peut donc
/// s'ouvrir par accident pendant le chargement.
final currentRoleProvider = Provider<UserRole>((ref) {
  return ref.watch(currentUserProvider)?.userRole ?? UserRole.student;
});

final currentAccountTypeProvider = Provider<AccountType>((ref) {
  return ref.watch(currentUserProvider)?.accountKind ?? AccountType.university;
});

/// L'utilisateur connecté porte-t-il le label `superadmin` ?
final isSuperAdminProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider)?.isSuperAdmin ?? false;
});

/// Périmètre de visibilité, construit depuis les cours et les inscriptions.
///
/// Pour un administrateur, aucune requête : il voit tout. Pour les autres,
/// les cours (enseignant → ses cours ; apprenant → ceux de sa promotion) et
/// les inscriptions (`academic_enrollments`, qui existe désormais) fixent
/// « ses étudiants » et « ses enseignants ».
final visibilityScopeProvider = FutureProvider<VisibilityScope>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return const VisibilityScope(role: UserRole.student, userId: '');
  }
  final role = user.userRole;
  if (role.isAdmin) {
    return VisibilityScope(role: role, userId: user.id);
  }

  final repository = ref.watch(academicRepositoryProvider);
  final courses = await repository.getCourses();
  final teacherIdByCourse = <String, String>{
    for (final course in courses)
      if ((course.teacherId ?? '').isNotEmpty) course.id: course.teacherId!,
  };

  final myCourseIds = <String>{};
  if (role.isTeaching) {
    myCourseIds.addAll(
      courses.where((c) => c.teacherId == user.id).map((c) => c.id),
    );
  } else {
    // Apprenant : les cours de sa promotion (même filière et même niveau).
    myCourseIds.addAll(
      courses
          .where((c) =>
              (user.program == null || c.program == user.program) &&
              (user.level == null || c.level == user.level))
          .map((c) => c.id),
    );
  }

  final courseIdsByStudent = <String, Set<String>>{};
  if (role.isTeaching) {
    try {
      final enrollments = await repository.getEnrollments();
      for (final enrollment in enrollments) {
        courseIdsByStudent
            .putIfAbsent(enrollment.studentId, () => {})
            .add(enrollment.courseId);
      }
    } catch (_) {
      // Sans inscriptions lisibles, l'enseignant ne voit aucun étudiant plutôt
      // que tous : la restriction doit fermer, jamais ouvrir.
    }
  }

  return VisibilityScope(
    role: role,
    userId: user.id,
    program: user.program,
    level: user.level,
    myCourseIds: myCourseIds,
    courseIdsByStudent: courseIdsByStudent,
    teacherIdByCourse: teacherIdByCourse,
  );
});
