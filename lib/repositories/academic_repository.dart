import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/appwrite_service.dart';
import '../models/appwrite_models.dart';
import '../models/attendance_models.dart';
import '../models/classroom.dart';
import '../models/dashboard_models.dart';
import '../models/statistics_models.dart';
import '../providers/appwrite_provider.dart';

/// Taille de page pour parcourir une collection entière.
///
/// Appwrite Cloud plafonne une page à 100 documents : `Query.limit(200)`
/// ramenait 100 UE sur 296 et 100 séances sur 527 sans erreur, d'où des
/// emplois du temps tronqués en silence. Tout parcours complet passe par
/// [AcademicRepository.listAll], qui enchaîne les pages par curseur.
const int kAppwritePageSize = 100;

class AcademicRepository {
  final AppwriteService _service;

  AcademicRepository(this._service);

  /// Parcourt toute une collection, page par page (curseur `cursorAfter`).
  Future<List<models.Document>> listAll(
    String collectionId, {
    List<String> queries = const [],
    int? max,
  }) async {
    final documents = <models.Document>[];
    String? cursor;
    while (true) {
      final page = await _service.databases.listDocuments(
        databaseId: _service.databaseId,
        collectionId: collectionId,
        queries: [
          ...queries,
          Query.limit(kAppwritePageSize),
          if (cursor != null) Query.cursorAfter(cursor),
        ],
      );
      documents.addAll(page.documents);
      if (page.documents.length < kAppwritePageSize) break;
      if (max != null && documents.length >= max) break;
      cursor = page.documents.last.$id;
    }
    return documents;
  }

  /// Nombre total de documents répondant aux filtres, sans les charger.
  Future<int> count(String collectionId, {List<String> queries = const []}) async {
    final page = await _service.databases.listDocuments(
      databaseId: _service.databaseId,
      collectionId: collectionId,
      queries: [...queries, Query.limit(1)],
    );
    return page.total;
  }

  Future<List<AcademicCourse>> getCourses() async {
    final documents = await listAll('academic_courses');
    return documents.map((doc) => AcademicCourse.fromDocument(doc)).toList();
  }

  /// UE d'une filière et d'un niveau, lues directement par filtre serveur.
  Future<List<AcademicCourse>> getCoursesFor({required String program, String? level}) async {
    final documents = await listAll('academic_courses', queries: [
      Query.equal('program', program),
      if (level != null && level.isNotEmpty) Query.equal('level', level),
    ]);
    return documents.map((doc) => AcademicCourse.fromDocument(doc)).toList();
  }

  /// Annuaire académique, enrichi des données de profil de `users`.
  ///
  /// Le pseudo et la photo de profil vivent dans `users`, l'appartenance
  /// académique dans `academic_directory` : les deux collections sont jointes
  /// ici en mémoire, ce qui évite une requête par personne.
  Future<List<AcademicDirectoryEntry>> getDirectory() async {
    final documents = await listAll('academic_directory');

    // La lecture de `users` peut être refusée selon les permissions du projet :
    // l'annuaire doit rester affichable sans les pseudos plutôt que d'échouer
    // entièrement.
    Map<String, Map<String, dynamic>> profiles = const {};
    try {
      final users = await listAll('users');
      profiles = {for (final doc in users) doc.$id: doc.data};
    } catch (_) {
      profiles = const {};
    }

    return documents.map((doc) {
      final entry = AcademicDirectoryEntry.fromDocument(doc);
      final profile = profiles[entry.userId];
      return entry.withProfile(
        email: profile?['email'],
        username: profile?['username'],
        avatarFileId: profile?['avatarFileId'],
      );
    }).toList();
  }

  /// Inscriptions actives `étudiant → cours` (`academic_enrollments`).
  ///
  /// C'est cette collection qui dit quels étudiants un enseignant encadre :
  /// le périmètre de visibilité en dépend. Elle existe désormais sur le Cloud
  /// (elle répondait 404 sur l'ancien serveur).
  Future<List<AcademicEnrollment>> getEnrollments() async {
    final documents = await listAll('academic_enrollments');
    return documents
        .map(AcademicEnrollment.fromDocument)
        .where((e) => e.isActive)
        .toList();
  }

  /// Nombre d'inscriptions par cours.
  ///
  /// Une erreur de lecture (permissions) renvoie une table vide : les UE
  /// s'affichent alors sans effectif plutôt que de faire échouer tout l'écran.
  Future<Map<String, int>> getEnrollmentCounts() async {
    try {
      final counts = <String, int>{};
      for (final enrollment in await getEnrollments()) {
        if (enrollment.courseId.isEmpty) continue;
        counts[enrollment.courseId] = (counts[enrollment.courseId] ?? 0) + 1;
      }
      return counts;
    } catch (_) {
      return const {};
    }
  }

  /// Salles déduites de l'emploi du temps.
  ///
  /// Il n'existe pas de collection `classrooms` : chaque salle est un libellé
  /// porté par `academic_schedules`. On regroupe ces libellés pour obtenir la
  /// liste réelle des salles utilisées et leur charge.
  Future<List<Classroom>> getClassrooms() async {
    final schedules = await getSchedules();

    final byRoom = <String, _RoomAggregate>{};
    for (final schedule in schedules) {
      final room = schedule.classroom.trim();
      if (room.isEmpty) continue;
      final aggregate = byRoom.putIfAbsent(room, () => _RoomAggregate());
      aggregate.creneaux++;
      if (schedule.courseId.isNotEmpty) aggregate.courseIds.add(schedule.courseId);
      final type = (schedule.type ?? '').trim();
      if (type.isNotEmpty) aggregate.types.add(type);
    }

    final rooms = byRoom.entries
        .map((entry) => Classroom(
              nom: entry.key,
              creneaux: entry.value.creneaux,
              cours: entry.value.courseIds.length,
              type: entry.value.types.length == 1 ? entry.value.types.first : '',
            ))
        .toList()
      ..sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
    return rooms;
  }

  Future<List<AcademicSchedule>> getSchedules() async {
    final documents = await listAll('academic_schedules');
    return documents.map((doc) => AcademicSchedule.fromDocument(doc)).toList();
  }

  /// Séances d'une filière et d'un niveau, par l'index `schedule_program_level`
  /// (schéma du 2026-09-20) : une grille se lit sans joindre les cours.
  Future<List<AcademicSchedule>> getSchedulesFor({required String program, required String level}) async {
    final documents = await listAll('academic_schedules', queries: [
      Query.equal('program', program),
      Query.equal('level', level),
    ]);
    return documents.map((doc) => AcademicSchedule.fromDocument(doc)).toList();
  }

  /// Séances de plusieurs cours, par lots : `Query.equal` accepte une liste
  /// de valeurs, on la découpe pour rester sous la limite d'une requête.
  Future<List<AcademicSchedule>> getSchedulesForCourses(Iterable<String> courseIds) async {
    final ids = courseIds.where((id) => id.isNotEmpty).toSet().toList();
    final result = <AcademicSchedule>[];
    for (var i = 0; i < ids.length; i += kAppwritePageSize) {
      final batch = ids.sublist(i, (i + kAppwritePageSize).clamp(0, ids.length));
      final documents = await listAll('academic_schedules', queries: [Query.equal('courseId', batch)]);
      result.addAll(documents.map(AcademicSchedule.fromDocument));
    }
    return result;
  }

  Future<List<AcademicGrade>> getAllGrades() async {
    final documents = await listAll('academic_grades');
    return documents.map((doc) => AcademicGrade.fromDocument(doc)).toList();
  }

  Future<List<AcademicAssignment>> getAssignments() async {
    final documents = await listAll('academic_assignments');
    return documents.map((doc) => AcademicAssignment.fromDocument(doc)).toList();
  }

  Future<Map<String, dynamic>> getGlobalStats() async {
    // Dans une version de production, on utiliserait une Appwrite Function
    // ou une agrégation. Ici on fait des listDocuments avec limit(0) pour avoir le total.
    final students = await _service.databases.listDocuments(
      databaseId: _service.databaseId,
      collectionId: 'academic_directory',
      queries: [Query.equal('role', 'STUDENT'), Query.limit(1)],
    );
    final teachers = await _service.databases.listDocuments(
      databaseId: _service.databaseId,
      collectionId: 'academic_directory',
      queries: [Query.equal('role', 'TEACHER'), Query.limit(1)],
    );
    final courses = await _service.databases.listDocuments(
      databaseId: _service.databaseId,
      collectionId: 'academic_courses',
      queries: [Query.limit(1)],
    );
    final sessions = await _service.databases.listDocuments(
      databaseId: _service.databaseId,
      collectionId: 'attendance_sessions',
      queries: [Query.limit(1)],
    );

    return {
      'studentCount': students.total,
      'teacherCount': teachers.total,
      'courseCount': courses.total,
      'sessionCount': sessions.total,
    };
  }

  /// Inscriptions par mois sur les [months] derniers mois, pour la courbe du
  /// tableau de bord.
  ///
  /// `$createdAt` est la seule date garantie sur chaque document : c'est elle
  /// qui date l'inscription, `academic_enrollments` n'ayant pas de champ de
  /// date propre. Une erreur de lecture renvoie une liste vide — la courbe
  /// s'affiche alors sans point plutôt que de faire échouer la page.
  Future<List<MonthlyCount>> getEnrollmentsByMonth({int months = 6}) async {
    final now = DateTime.now();
    final firstMonth = DateTime(now.year, now.month - (months - 1));

    final counts = <String, int>{};
    try {
      final response = await _service.databases.listDocuments(
        databaseId: _service.databaseId,
        collectionId: 'academic_enrollments',
        queries: [
          Query.greaterThanEqual(r'$createdAt', firstMonth.toIso8601String()),
          Query.limit(5000),
        ],
      );
      for (final doc in response.documents) {
        final created = DateTime.tryParse(doc.$createdAt);
        if (created == null) continue;
        final key = '${created.year}-${created.month}';
        counts[key] = (counts[key] ?? 0) + 1;
      }
    } catch (_) {
      return const [];
    }

    final result = <MonthlyCount>[];
    for (int i = 0; i < months; i++) {
      final month = DateTime(firstMonth.year, firstMonth.month + i);
      result.add(MonthlyCount(
        month: month,
        count: counts['${month.year}-${month.month}'] ?? 0,
      ));
    }
    return result;
  }

  /// Répartition présent / absent / retard, lue dans les enregistrements de
  /// présence.
  ///
  /// Renvoie `null` — et non une répartition à zéro — si la collection est
  /// absente ou refuse la lecture : le tableau de bord doit pouvoir distinguer
  /// « aucune donnée » d'un taux réellement nul.
  Future<AttendanceBreakdown?> getAttendanceBreakdown({int limit = 5000}) async {
    try {
      final response = await _service.databases.listDocuments(
        databaseId: _service.databaseId,
        collectionId: 'attendance_records',
        queries: [Query.limit(limit)],
      );

      var present = 0;
      var absent = 0;
      var late = 0;
      for (final doc in response.documents) {
        switch ((doc.data['status'] ?? '').toString().trim().toUpperCase()) {
          case 'PRESENT':
          case 'PRÉSENT':
          case 'P':
            present++;
          case 'ABSENT':
          case 'A':
            absent++;
          case 'LATE':
          case 'RETARD':
          case 'R':
            late++;
        }
      }

      if (present + absent + late == 0) return null;
      return AttendanceBreakdown(present: present, absent: absent, late: late);
    } catch (_) {
      return null;
    }
  }

  /// Derniers documents créés, lus dans les collections qui alimentent le fil
  /// « Activités récentes », puis fusionnés et triés par date de création.
  ///
  /// Une collection illisible est ignorée sans priver le fil des autres.
  Future<List<ActivityEntry>> getRecentActivity({int limit = 6}) async {
    final entries = <ActivityEntry>[];

    Future<void> collect(
      String collectionId,
      ActivityKind kind,
      String Function(Map<String, dynamic> data) subjectOf,
    ) async {
      try {
        final response = await _service.databases.listDocuments(
          databaseId: _service.databaseId,
          collectionId: collectionId,
          queries: [Query.orderDesc(r'$createdAt'), Query.limit(limit)],
        );
        for (final doc in response.documents) {
          final created = DateTime.tryParse(doc.$createdAt);
          final subject = subjectOf(doc.data).trim();
          if (created == null || subject.isEmpty) continue;
          entries.add(ActivityEntry(kind: kind, subject: subject, createdAt: created));
        }
      } catch (_) {
        // Ignoré volontairement : voir le contrat de la méthode.
      }
    }

    await collect('academic_directory', ActivityKind.enrollment,
        (data) => (data['name'] ?? '').toString());
    await collect('academic_courses', ActivityKind.course,
        (data) => (data['name'] ?? data['code'] ?? '').toString());
    await collect('academic_schedules', ActivityKind.schedule,
        (data) => (data['classroom'] ?? '').toString());

    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries.take(limit).toList();
  }

  /// Assiduité par étudiant, agrégée depuis les enregistrements de présence et
  /// jointe aux noms de `academic_directory`.
  ///
  /// Une collection de présences absente ou illisible renvoie une liste vide :
  /// l'écran affiche alors l'absence de données plutôt qu'un tableau inventé.
  Future<List<StudentAttendance>> getStudentAttendance({int limit = 5000}) async {
    final tallies = <String, _AttendanceTally>{};
    try {
      final response = await _service.databases.listDocuments(
        databaseId: _service.databaseId,
        collectionId: 'attendance_records',
        queries: [Query.limit(limit)],
      );
      for (final doc in response.documents) {
        final studentId =
            (doc.data['studentId'] ?? doc.data['userId'] ?? '').toString();
        if (studentId.isEmpty) continue;
        final tally = tallies.putIfAbsent(studentId, () => _AttendanceTally());
        switch ((doc.data['status'] ?? '').toString().trim().toUpperCase()) {
          case 'PRESENT':
          case 'PRÉSENT':
          case 'P':
            tally.present++;
          case 'ABSENT':
          case 'A':
            tally.absent++;
          case 'LATE':
          case 'RETARD':
          case 'R':
            tally.late++;
        }
      }
    } catch (_) {
      return const [];
    }

    if (tallies.isEmpty) return const [];

    // Les enregistrements référencent l'étudiant par identifiant : le nom est
    // résolu via l'annuaire, indexé à la fois par id de document et par userId,
    // les deux conventions existant selon la source d'écriture.
    final directory = await getDirectory();
    final byKey = <String, AcademicDirectoryEntry>{};
    for (final entry in directory) {
      byKey[entry.id] = entry;
      if (entry.userId.isNotEmpty) byKey[entry.userId] = entry;
    }

    final result = <StudentAttendance>[];
    for (final entry in tallies.entries) {
      final profile = byKey[entry.key];
      result.add(StudentAttendance(
        studentId: entry.key,
        name: profile?.name ?? entry.key,
        matricule: profile?.matricule ?? '—',
        present: entry.value.present,
        absent: entry.value.absent,
        late: entry.value.late,
      ));
    }
    result.sort((a, b) => b.rate.compareTo(a.rate));
    return result;
  }

  /// Synthèse des résultats, calculée depuis `academic_grades`.
  ///
  /// Renvoie `null` si la collection est illisible ou vide : l'écran de
  /// statistiques distingue « aucune note saisie » d'une moyenne nulle.
  Future<GradeStats?> getGradeStats() async {
    final List<AcademicGrade> grades;
    try {
      grades = await getAllGrades();
    } catch (_) {
      return null;
    }
    if (grades.isEmpty) return null;

    var weightedSum = 0.0;
    var weightTotal = 0.0;
    var passed = 0;
    final byCourse = <String, _GradeTally>{};
    final bandCounts = <String, int>{};

    for (final grade in grades) {
      final double maxScore = grade.maxScore > 0 ? grade.maxScore : 20.0;
      final on20 = (grade.score / maxScore) * 20;
      // `: 1` (int) ferait déduire `num` au ternaire, refusé par `add(double, double)`.
      final double coefficient = grade.coefficient > 0 ? grade.coefficient : 1.0;

      weightedSum += on20 * coefficient;
      weightTotal += coefficient;
      if (on20 >= 10) passed++;

      final code = grade.courseCode.isEmpty ? '—' : grade.courseCode;
      byCourse.putIfAbsent(code, () => _GradeTally()).add(on20, coefficient);

      final band = _bandOf(on20);
      bandCounts[band] = (bandCounts[band] ?? 0) + 1;
    }

    final averages = byCourse.entries
        .map((entry) => CourseAverage(
              courseCode: entry.key,
              averageOn20: entry.value.average,
              gradeCount: entry.value.count,
            ))
        .toList()
      ..sort((a, b) => b.averageOn20.compareTo(a.averageOn20));

    return GradeStats(
      gradeCount: grades.length,
      averageOn20: weightTotal == 0 ? 0 : weightedSum / weightTotal,
      successRate: passed / grades.length,
      topCourses: averages.take(5).toList(),
      bands: [
        for (final label in _bandLabels)
          GradeBand(label: label, count: bandCounts[label] ?? 0),
      ],
    );
  }

  /// Tranches de l'histogramme des notes, dans l'ordre d'affichage.
  static const List<String> _bandLabels = [
    '< 10',
    '10 – 12',
    '12 – 14',
    '14 – 16',
    '16 – 20',
  ];

  static String _bandOf(double on20) {
    if (on20 < 10) return _bandLabels[0];
    if (on20 < 12) return _bandLabels[1];
    if (on20 < 14) return _bandLabels[2];
    if (on20 < 16) return _bandLabels[3];
    return _bandLabels[4];
  }
}

/// Accumulateur interne : présences d'un étudiant.
class _AttendanceTally {
  int present = 0;
  int absent = 0;
  int late = 0;
}

/// Accumulateur interne : notes d'une UE.
class _GradeTally {
  double weightedSum = 0;
  double weightTotal = 0;
  int count = 0;

  void add(double on20, double coefficient) {
    weightedSum += on20 * coefficient;
    weightTotal += coefficient;
    count++;
  }

  double get average => weightTotal == 0 ? 0 : weightedSum / weightTotal;
}

final academicRepositoryProvider = Provider<AcademicRepository>((ref) {
  final service = ref.watch(appwriteServiceProvider);
  return AcademicRepository(service);
});

/// Accumulateur interne utilisé par [AcademicRepository.getClassrooms] pour
/// regrouper les créneaux d'une même salle.
class _RoomAggregate {
  int creneaux = 0;
  final Set<String> courseIds = {};
  final Set<String> types = {};
}
