import 'user_role.dart';

/// Périmètre de visibilité d'un utilisateur connecté.
///
/// Masquer une entrée de menu ne suffit pas : la demande du propriétaire est
/// que « chaque utilisateur ne voie que ceux qui le concernent et rien
/// d'autre ». Un délégué qui ouvre la messagerie ne doit pas pouvoir écrire à
/// l'établissement entier, et un enseignant ne doit pas parcourir la liste des
/// étudiants qu'il n'encadre pas.
///
/// Tout est calculé ici, en fonctions pures : la règle est ainsi vérifiable
/// sans serveur, et les providers ne font que l'appliquer.
class VisibilityScope {
  /// Rôle de l'utilisateur connecté.
  final UserRole role;

  /// Identifiant Appwrite du compte.
  final String userId;

  /// Filière et niveau de l'utilisateur (`academic_directory`). Servent au
  /// délégué, dont le périmètre est sa promotion.
  final String? program;
  final String? level;

  /// Cours que l'utilisateur **encadre** (enseignant) ou **suit**
  /// (étudiant, délégué). Les deux cas ne se mélangent jamais : un enseignant
  /// n'est jamais inscrit à ses propres cours.
  final Set<String> myCourseIds;

  /// Cours suivis par chaque étudiant, index `studentId -> courseIds`.
  ///
  /// Déduit de `academic_grades` : la collection `academic_enrollments`, qui
  /// porterait cette information en propre, répond 404 sur le serveur (vérifié
  /// le 2026-09-15). Tant qu'elle manque, une note est la seule trace
  /// d'appartenance d'un étudiant à un cours.
  final Map<String, Set<String>> courseIdsByStudent;

  /// Enseignant de chaque cours, index `courseId -> teacherId`.
  final Map<String, String> teacherIdByCourse;

  const VisibilityScope({
    required this.role,
    required this.userId,
    this.program,
    this.level,
    this.myCourseIds = const {},
    this.courseIdsByStudent = const {},
    this.teacherIdByCourse = const {},
  });

  /// L'administrateur est le seul à voir l'établissement entier.
  bool get seesEveryone => role.isAdmin;

  /// Ce que l'utilisateur peut atteindre, en une phrase — affiché sur l'écran
  /// de restriction pour que la limite soit expliquée, pas seulement subie.
  String get summary {
    switch (role) {
      case UserRole.admin:
        return 'Vous voyez tous les comptes de l\'établissement.';
      case UserRole.teacher:
        return 'Vous voyez les étudiants de vos cours et votre propre profil.';
      case UserRole.delegate:
        return 'Vous voyez les étudiants de votre promotion '
            '(${_promotionLabel()}) et vos enseignants.';
      case UserRole.student:
        return 'Vous voyez vos enseignants et les étudiants de votre '
            'promotion (${_promotionLabel()}).';
    }
  }

  String _promotionLabel() {
    final parts = [level, program].where((p) => p != null && p.isNotEmpty);
    return parts.isEmpty ? 'non renseignée' : parts.join(' · ');
  }

  /// Un étudiant donné est-il dans le périmètre ?
  ///
  /// [studentProgram] et [studentLevel] sont fournis par l'appelant, qui les
  /// tient de l'annuaire : les porter ici obligerait à dupliquer toute la fiche
  /// dans la portée.
  bool seesStudent(
    String studentId, {
    String? studentProgram,
    String? studentLevel,
  }) {
    if (seesEveryone) return true;
    // Personne ne se voit lui-même dans une liste d'étudiants : un étudiant ou
    // un délégué n'a pas accès à cette liste de toute façon, mais la règle
    // reste explicite pour que l'ajout d'un rôle ne l'ouvre pas par accident.
    if (studentId == userId) return false;

    switch (role) {
      case UserRole.teacher:
        final theirs = courseIdsByStudent[studentId];
        if (theirs == null) return false;
        // Intersection non vide = l'enseignant a cet étudiant dans un de ses
        // cours. C'est la définition de « ses étudiants ».
        return theirs.any(myCourseIds.contains);
      case UserRole.delegate:
      case UserRole.student:
        // La promotion : même filière **et** même niveau. Comparer la seule
        // filière ferait voir les L3 à un L1.
        if (program == null || level == null) return false;
        return studentProgram == program && studentLevel == level;
      case UserRole.admin:
        return true;
    }
  }

  /// Un enseignant donné est-il dans le périmètre ?
  bool seesTeacher(String teacherId) {
    if (seesEveryone) return true;
    // Un enseignant ne consulte que sa propre fiche : l'annuaire du corps
    // enseignant est une vue d'administration.
    if (role == UserRole.teacher) return teacherId == userId;
    if (teacherId == userId) return true;
    // Étudiant ou délégué : uniquement les enseignants qui encadrent un cours
    // de sa promotion.
    return myCourseIds
        .map((courseId) => teacherIdByCourse[courseId])
        .whereType<String>()
        .contains(teacherId);
  }

  /// Filtre une liste d'enseignants.
  List<T> filterTeachers<T>(
    List<T> teachers,
    String Function(T) idOf,
  ) =>
      teachers.where((teacher) => seesTeacher(idOf(teacher))).toList();

  /// Filtre une liste d'étudiants.
  List<T> filterStudents<T>(
    List<T> students,
    String Function(T) idOf, {
    String? Function(T)? programOf,
    String? Function(T)? levelOf,
  }) =>
      students
          .where((student) => seesStudent(
                idOf(student),
                studentProgram: programOf?.call(student),
                studentLevel: levelOf?.call(student),
              ))
          .toList();
}
