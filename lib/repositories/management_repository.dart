// `Databases.*Document` est marqué déprécié par le SDK Dart 26 au profit de
// `TablesDB.*Row` (Appwrite 1.8). Le schéma du projet est encore déclaré en
// collections/documents (`uniflow-we/scripts/appwrite-schema.mjs`) et la
// migration vers TablesDB se fera pour les trois clients en même temps ; on
// ignore la dépréciation ici, fichier par fichier, sans assouplir l'analyse
// globale.
// ignore_for_file: deprecated_member_use

import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/appwrite_models.dart';
import '../providers/appwrite_provider.dart';
import '../services/appwrite_service.dart';
import '../services/uniflow_api.dart';

/// Opérations d'administration et d'enseignement qui passent par la Function
/// `uniflow-api` (le serveur refait la matrice de droits) ou par des écritures
/// directes là où le schéma les autorise.
///
/// Chaque méthode renvoie un objet typé plutôt qu'une `Map` : les écrans ne
/// doivent pas connaître le nom des champs JSON de la Function.

// ---------------------------------------------------------------------------
// Annuaire administratif (`/admin-directory`)
// ---------------------------------------------------------------------------

class ManagedAccount {
  final String userId;
  final String name;
  final String email;
  final String role;
  final bool isSuperAdmin;
  final String matricule;
  final String status;
  final String university;
  final String program;
  final String level;

  const ManagedAccount({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    this.isSuperAdmin = false,
    this.matricule = '',
    this.status = 'ACTIVE',
    this.university = '',
    this.program = '',
    this.level = '',
  });

  factory ManagedAccount.fromJson(Map<String, dynamic> json) => ManagedAccount(
        userId: json['userId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        role: (json['role'] as String? ?? 'STUDENT').toUpperCase(),
        isSuperAdmin: json['isSuperAdmin'] == true,
        matricule: json['matricule'] as String? ?? '',
        status: json['status'] as String? ?? 'ACTIVE',
        university: json['university'] as String? ?? '',
        program: json['program'] as String? ?? '',
        level: json['level'] as String? ?? '',
      );
}

class AccountDraft {
  final String name;
  final String email;
  final String role;
  final String? password;
  final String university;
  final String program;
  final String level;
  final String matricule;
  final String status;

  const AccountDraft({
    required this.name,
    required this.email,
    required this.role,
    this.password,
    this.university = '',
    this.program = '',
    this.level = '',
    this.matricule = '',
    this.status = 'ACTIVE',
  });

  Map<String, dynamic> toJson() => {
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'role': role,
        if (password != null && password!.isNotEmpty) 'password': password,
        if (university.isNotEmpty) 'university': university,
        'program': program,
        'level': level,
        'matricule': matricule,
        'status': status,
      };
}

class AdminDirectoryApi {
  final UniFlowApi _api;
  const AdminDirectoryApi(this._api);

  Future<List<ManagedAccount>> list({String? program, String? level}) async {
    final data = await _api.call(ApiPaths.adminDirectory, {
      'action': 'list',
      if (program != null && program.isNotEmpty) 'program': program,
      if (level != null && level.isNotEmpty) 'level': level,
    });
    final entries = data['entries'];
    if (entries is! List) return const [];
    return entries
        .whereType<Map>()
        .map((e) => ManagedAccount.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Map<String, dynamic>> create(AccountDraft draft) => _api
      .call(ApiPaths.adminDirectory, {'action': 'create', ...draft.toJson()});

  Future<Map<String, dynamic>> update(String userId, AccountDraft draft) =>
      _api.call(ApiPaths.adminDirectory,
          {'action': 'update', 'userId': userId, ...draft.toJson()});

  Future<void> delete(String userId) => _api
      .call(ApiPaths.adminDirectory, {'action': 'delete', 'userId': userId});
}

// ---------------------------------------------------------------------------
// Notes (`/academic-grades`)
// ---------------------------------------------------------------------------

class RosterStudent {
  final String userId;
  final String name;
  final String matricule;
  final String role;
  const RosterStudent(
      {required this.userId,
      required this.name,
      this.matricule = '',
      this.role = 'STUDENT'});
}

class GradeRoster {
  final String courseId;
  final String courseCode;
  final String courseName;
  final List<RosterStudent> students;
  final List<AcademicGrade> grades;
  const GradeRoster({
    required this.courseId,
    required this.courseCode,
    required this.courseName,
    required this.students,
    required this.grades,
  });

  /// Intitulés d'évaluation déjà utilisés, dans l'ordre d'apparition.
  List<String> get evaluationTitles {
    final seen = <String>{};
    return [
      for (final g in grades)
        if (seen.add(g.evaluationTitle)) g.evaluationTitle
    ];
  }

  AcademicGrade? gradeOf(String studentId, String evaluationTitle) {
    for (final g in grades) {
      if (g.studentId == studentId && g.evaluationTitle == evaluationTitle) {
        return g;
      }
    }
    return null;
  }
}

class GradesApi {
  final UniFlowApi _api;
  const GradesApi(this._api);

  Future<GradeRoster> roster(String courseId) async {
    final data = await _api.call(
        ApiPaths.academicGrades, {'action': 'roster', 'courseId': courseId});
    final course = data['course'] is Map
        ? Map<String, dynamic>.from(data['course'] as Map)
        : const {};
    final students = (data['students'] as List? ?? const [])
        .whereType<Map>()
        .map((s) => RosterStudent(
              userId: s['userId'] as String? ?? '',
              name: s['name'] as String? ?? '',
              matricule: s['matricule'] as String? ?? '',
              role: s['role'] as String? ?? 'STUDENT',
            ))
        .toList();
    final grades = (data['grades'] as List? ?? const [])
        .whereType<Map>()
        .map((g) => AcademicGrade(
              id: g['id'] as String? ?? '',
              studentId: g['studentId'] as String? ?? '',
              courseId: g['courseId'] as String? ?? courseId,
              courseCode: g['courseCode'] as String? ?? '',
              evaluationTitle: g['evaluationTitle'] as String? ?? '',
              type: g['type'] as String?,
              score: (g['score'] as num? ?? 0).toDouble(),
              maxScore: (g['maxScore'] as num? ?? 20).toDouble(),
              coefficient: (g['coefficient'] as num? ?? 1).toDouble(),
            ))
        .toList();
    return GradeRoster(
      courseId: courseId,
      courseCode: course['code'] as String? ?? '',
      courseName: course['name'] as String? ?? '',
      students: students,
      grades: grades,
    );
  }

  Future<void> upsert({
    required String courseId,
    required String studentId,
    required String evaluationTitle,
    required int score,
    int maxScore = 20,
    int coefficient = 1,
    String type = 'CC',
  }) =>
      _api.call(ApiPaths.academicGrades, {
        'action': 'upsert',
        'courseId': courseId,
        'studentId': studentId,
        'evaluationTitle': evaluationTitle,
        'score': score,
        'maxScore': maxScore,
        'coefficient': coefficient,
        'type': type,
      });

  Future<void> delete(
          {required String courseId,
          required String studentId,
          required String gradeId}) =>
      _api.call(ApiPaths.academicGrades, {
        'action': 'delete',
        'courseId': courseId,
        'studentId': studentId,
        'gradeId': gradeId,
      });
}

// ---------------------------------------------------------------------------
// Présence (`/attendance-secure` + lectures directes)
// ---------------------------------------------------------------------------

class AttendanceSessionInfo {
  final String id;
  final String courseId;
  final DateTime date;
  final String createdBy;
  const AttendanceSessionInfo(
      {required this.id,
      required this.courseId,
      required this.date,
      this.createdBy = ''});
}

class AttendanceRecordInfo {
  final String id;
  final String sessionId;
  final String studentId;
  final String status;
  final String verificationMethod;
  const AttendanceRecordInfo({
    required this.id,
    required this.sessionId,
    required this.studentId,
    required this.status,
    this.verificationMethod = 'MANUAL',
  });
}

class IssuedQr {
  final String token;
  final String sessionId;
  final String courseId;
  final DateTime expiresAt;
  final int radiusMeters;
  const IssuedQr({
    required this.token,
    required this.sessionId,
    required this.courseId,
    required this.expiresAt,
    required this.radiusMeters,
  });
}

class AttendanceApi {
  final UniFlowApi _api;
  final AppwriteService _service;
  const AttendanceApi(this._api, this._service);

  Future<List<AttendanceSessionInfo>> sessionsOf(String courseId) async {
    final response = await _service.databases.listDocuments(
      databaseId: _service.databaseId,
      collectionId: 'attendance_sessions',
      queries: [
        Query.equal('courseId', courseId),
        Query.orderDesc('date'),
        Query.limit(200)
      ],
    );
    return response.documents
        .map((d) => AttendanceSessionInfo(
              id: d.$id,
              courseId: d.data['courseId'] as String? ?? courseId,
              date: DateTime.tryParse(d.data['date'] as String? ?? '') ??
                  DateTime.now(),
              createdBy: d.data['createdBy'] as String? ?? '',
            ))
        .toList();
  }

  Future<List<AttendanceRecordInfo>> recordsOf(String sessionId) async {
    final response = await _service.databases.listDocuments(
      databaseId: _service.databaseId,
      collectionId: 'attendance_records',
      queries: [Query.equal('sessionId', sessionId), Query.limit(500)],
    );
    return response.documents
        .map((d) => AttendanceRecordInfo(
              id: d.$id,
              sessionId: sessionId,
              studentId: d.data['studentId'] as String? ?? '',
              status: d.data['status'] as String? ?? 'ABSENT',
              verificationMethod:
                  d.data['verificationMethod'] as String? ?? 'MANUAL',
            ))
        .toList();
  }

  /// Appel manuel : crée la séance du jour si besoin et écrit les statuts.
  Future<String> roll({
    required String courseId,
    required DateTime date,
    required Map<String, String> statusByStudent,
  }) async {
    final data = await _api.call(ApiPaths.attendanceSecure, {
      'action': 'roll',
      'courseId': courseId,
      'date': date.toUtc().toIso8601String(),
      'rows': [
        for (final entry in statusByStudent.entries)
          {'studentId': entry.key, 'status': entry.value},
      ],
    });
    return data['sessionId'] as String? ?? '';
  }

  /// Émission d'un QR de séance. Le serveur exige la position de l'émetteur
  /// (latitude, longitude, précision ≤ 100 m) : un poste fixe n'a pas de GPS,
  /// l'écran demande donc les coordonnées de la salle.
  Future<IssuedQr> issue({
    required String sessionId,
    required String courseId,
    required double latitude,
    required double longitude,
    double accuracyMeters = 30,
    int radiusMeters = 80,
  }) async {
    final data = await _api.call(ApiPaths.attendanceSecure, {
      'action': 'issue',
      'sessionId': sessionId,
      'courseId': courseId,
      'origin': {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracyMeters
      },
      'radiusMeters': radiusMeters,
    });
    return IssuedQr(
      token: data['token'] as String? ?? '',
      sessionId: sessionId,
      courseId: courseId,
      expiresAt: DateTime.tryParse(data['expiresAt'] as String? ?? '') ??
          DateTime.now().add(const Duration(minutes: 15)),
      radiusMeters: (data['radiusMeters'] as num? ?? radiusMeters).toInt(),
    );
  }

  Future<void> revoke(String token) => _api
      .call(ApiPaths.attendanceSecure, {'action': 'revoke', 'token': token});
}

// ---------------------------------------------------------------------------
// Devoirs (écritures directes : la collection accorde `create("users")`)
// ---------------------------------------------------------------------------

class AssignmentDraft {
  final String courseId;
  final String courseCode;
  final String title;
  final String description;
  final DateTime dueDate;
  final String type;
  final double maxScore;
  final bool allowLate;
  final bool published;

  const AssignmentDraft({
    required this.courseId,
    required this.courseCode,
    required this.title,
    this.description = '',
    required this.dueDate,
    this.type = 'DEVOIR',
    this.maxScore = 20,
    this.allowLate = false,
    this.published = true,
  });

  Map<String, dynamic> toData(
          {required String teacherId, required String teacherName}) =>
      {
        'courseId': courseId,
        'courseCode': courseCode,
        'title': title.trim(),
        'description': description.trim(),
        'dueDate': dueDate.toUtc().toIso8601String(),
        'status': 'À rendre',
        'teacherId': teacherId,
        'teacherName': teacherName,
        'type': type,
        'maxScore': maxScore,
        'allowLate': allowLate,
        'publishedAt':
            published ? DateTime.now().toUtc().toIso8601String() : '',
      };
}

class SubmissionInfo {
  final String id;
  final String assignmentId;
  final String studentId;
  final String studentName;
  final DateTime? submittedAt;
  final double? score;
  final String feedback;
  final String status;
  final String fileId;
  final String fileName;

  const SubmissionInfo({
    required this.id,
    required this.assignmentId,
    required this.studentId,
    required this.studentName,
    this.submittedAt,
    this.score,
    this.feedback = '',
    this.status = 'SUBMITTED',
    this.fileId = '',
    this.fileName = '',
  });
}

class AssignmentsApi {
  final AppwriteService _service;
  const AssignmentsApi(this._service);

  Future<AcademicAssignment> create(
    AssignmentDraft draft, {
    required String teacherId,
    required String teacherName,
  }) async {
    final doc = await _service.databases.createDocument(
      databaseId: _service.databaseId,
      collectionId: 'academic_assignments',
      documentId: ID.unique(),
      data: draft.toData(teacherId: teacherId, teacherName: teacherName),
      // Lisible par tous les connectés (les étudiants doivent voir le sujet),
      // modifiable par son auteur seulement.
      permissions: [
        Permission.read(Role.users()),
        Permission.update(Role.user(teacherId)),
        Permission.delete(Role.user(teacherId)),
      ],
    );
    return AcademicAssignment.fromDocument(doc);
  }

  Future<void> update(String id, Map<String, dynamic> data) =>
      _service.databases.updateDocument(
        databaseId: _service.databaseId,
        collectionId: 'academic_assignments',
        documentId: id,
        data: data,
      );

  Future<void> delete(String id) => _service.databases.deleteDocument(
        databaseId: _service.databaseId,
        collectionId: 'academic_assignments',
        documentId: id,
      );

  Future<List<SubmissionInfo>> submissionsOf(String assignmentId) async {
    final response = await _service.databases.listDocuments(
      databaseId: _service.databaseId,
      collectionId: 'academic_submissions',
      queries: [
        Query.equal('assignmentId', assignmentId),
        Query.orderDesc('submittedAt'),
        Query.limit(500)
      ],
    );
    return response.documents.map((d) {
      final data = d.data;
      return SubmissionInfo(
        id: d.$id,
        assignmentId: assignmentId,
        studentId: data['studentId'] as String? ?? '',
        studentName: data['studentName'] as String? ?? '',
        submittedAt: DateTime.tryParse(data['submittedAt'] as String? ?? ''),
        score: (data['score'] as num?)?.toDouble(),
        feedback: data['feedback'] as String? ?? '',
        status: data['status'] as String? ?? 'SUBMITTED',
        fileId: data['fileId'] as String? ?? '',
        fileName: data['fileName'] as String? ?? '',
      );
    }).toList();
  }

  Future<void> gradeSubmission(String submissionId,
          {required double score, String feedback = ''}) =>
      _service.databases.updateDocument(
        databaseId: _service.databaseId,
        collectionId: 'academic_submissions',
        documentId: submissionId,
        data: {
          'score': score,
          'feedback': feedback,
          'status': 'GRADED',
          'gradedAt': DateTime.now().toUtc().toIso8601String(),
        },
      );
}

// ---------------------------------------------------------------------------
// Notifications (lecture et marquage, documents du propriétaire)
// ---------------------------------------------------------------------------

class AppNotification {
  final String id;
  final String type;
  final String title;
  final String message;
  final bool isRead;
  final DateTime? createdAt;
  final String link;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    this.createdAt,
    this.link = '',
  });
}

class NotificationsApi {
  final AppwriteService _service;
  const NotificationsApi(this._service);

  Future<List<AppNotification>> listFor(String ownerId) async {
    final response = await _service.databases.listDocuments(
      databaseId: _service.databaseId,
      collectionId: 'notifications',
      queries: [
        Query.equal('ownerId', ownerId),
        Query.orderDesc('\$createdAt'),
        Query.limit(100)
      ],
    );
    return response.documents.map((d) {
      final data = d.data;
      return AppNotification(
        id: d.$id,
        type: data['type'] as String? ?? '',
        title: data['title'] as String? ?? '',
        message: data['message'] as String? ?? '',
        isRead: data['isRead'] == true,
        createdAt:
            DateTime.tryParse(data['createdAt'] as String? ?? d.$createdAt),
        link: data['link'] as String? ?? '',
      );
    }).toList();
  }

  Future<void> markRead(String id, {bool read = true}) =>
      _service.databases.updateDocument(
        databaseId: _service.databaseId,
        collectionId: 'notifications',
        documentId: id,
        data: {'isRead': read},
      );

  Future<void> delete(String id) => _service.databases.deleteDocument(
        databaseId: _service.databaseId,
        collectionId: 'notifications',
        documentId: id,
      );
}

// ---------------------------------------------------------------------------
// Équipe (`/team-roster`)
// ---------------------------------------------------------------------------

class TeamRosterApi {
  final UniFlowApi _api;
  const TeamRosterApi(this._api);

  static const teams = ['Leadership', 'Frontend', 'Backend'];
  static const accents = [
    'blue',
    'purple',
    'emerald',
    'amber',
    'rose',
    'cyan',
    'indigo'
  ];

  Future<Map<String, dynamic>> create(Map<String, dynamic> member) =>
      _api.call(ApiPaths.teamRoster, {'action': 'create', ...member});

  Future<Map<String, dynamic>> update(
          String memberId, Map<String, dynamic> member) =>
      _api.call(ApiPaths.teamRoster,
          {'action': 'update', 'memberId': memberId, ...member});

  Future<void> delete(String memberId) => _api
      .call(ApiPaths.teamRoster, {'action': 'delete', 'memberId': memberId});
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final adminDirectoryApiProvider = Provider<AdminDirectoryApi>(
  (ref) => AdminDirectoryApi(ref.watch(uniflowApiProvider)),
);
final gradesApiProvider = Provider<GradesApi>(
  (ref) => GradesApi(ref.watch(uniflowApiProvider)),
);
final attendanceApiProvider = Provider<AttendanceApi>(
  (ref) => AttendanceApi(
      ref.watch(uniflowApiProvider), ref.watch(appwriteServiceProvider)),
);
final assignmentsApiProvider = Provider<AssignmentsApi>(
  (ref) => AssignmentsApi(ref.watch(appwriteServiceProvider)),
);
final notificationsApiProvider = Provider<NotificationsApi>(
  (ref) => NotificationsApi(ref.watch(appwriteServiceProvider)),
);
final teamRosterApiProvider = Provider<TeamRosterApi>(
  (ref) => TeamRosterApi(ref.watch(uniflowApiProvider)),
);

/// Comptes gérés par l'administration, filtrés par filière/niveau.
final managedAccountsProvider = FutureProvider.family<List<ManagedAccount>,
    ({String? program, String? level})>((ref, filter) {
  return ref
      .watch(adminDirectoryApiProvider)
      .list(program: filter.program, level: filter.level);
});
