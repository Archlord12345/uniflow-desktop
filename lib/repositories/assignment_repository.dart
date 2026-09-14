import 'package:appwrite/appwrite.dart';
// Les modèles de réponse (`DocumentList`, `File`) ne sont pas ré-exportés par
// `appwrite.dart` : ils vivent dans `models.dart`.
import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/appwrite_service.dart';
import '../models/assignment_models.dart';
import '../providers/appwrite_provider.dart';

/// Erreur lisible remontée à l'interface.
class AssignmentException implements Exception {
  final String message;

  const AssignmentException(this.message);

  @override
  String toString() => message;
}

/// Accès aux devoirs et aux rendus.
///
/// Deux collections distinctes : `academic_assignments` porte l'énoncé, écrit
/// une fois par l'enseignant, et `academic_submissions` les rendus, un par
/// élève. Cette séparation est ce qui permet de savoir qui a rendu — l'ancien
/// modèle dupliquait l'énoncé par élève et perdait cette information.
class AssignmentRepository {
  final AppwriteService _service;

  AssignmentRepository(this._service);

  static const String assignmentsCollection = 'academic_assignments';
  static const String submissionsCollection = 'academic_submissions';

  /// Devoirs visibles par un élève.
  ///
  /// Le filtrage par audience se fait côté application : Appwrite ne sait pas
  /// interroger un champ JSON glissé dans une chaîne, et une requête par
  /// filière multiplierait les allers-retours. Le volume reste faible
  /// (quelques dizaines de devoirs par semestre).
  Future<List<Assignment>> listForStudent({
    String? filiere,
    String? niveau,
    int limit = 100,
  }) async {
    final response = await _guard(
      () => _service.databases.listDocuments(
        databaseId: _service.databaseId,
        collectionId: assignmentsCollection,
        queries: [
          // Les brouillons ne regardent pas les élèves.
          Query.notEqual('status', AssignmentStatus.draft.value),
          Query.orderDesc('dueDate'),
          Query.limit(limit),
        ],
      ),
    );

    return response.documents
        .map((doc) => Assignment.fromDocument(doc))
        .where((a) => a.targets(filiere: filiere, niveau: niveau))
        .toList();
  }

  /// Devoirs créés par un enseignant, brouillons compris.
  Future<List<Assignment>> listForTeacher(String teacherId, {int limit = 100}) async {
    final response = await _guard(
      () => _service.databases.listDocuments(
        databaseId: _service.databaseId,
        collectionId: assignmentsCollection,
        queries: [
          Query.equal('teacherId', teacherId),
          Query.orderDesc('dueDate'),
          Query.limit(limit),
        ],
      ),
    );
    return response.documents.map((doc) => Assignment.fromDocument(doc)).toList();
  }

  Future<Assignment> getAssignment(String id) async {
    final doc = await _guard(
      () => _service.databases.getDocument(
        databaseId: _service.databaseId,
        collectionId: assignmentsCollection,
        documentId: id,
      ),
    );
    return Assignment.fromDocument(doc);
  }

  /// Publie un devoir.
  ///
  /// Les permissions du document sont posées à la création : tout compte
  /// connecté peut lire l'énoncé, seul son auteur peut le modifier ou le
  /// supprimer. Sans cela, n'importe quel élève pourrait réécrire un barème.
  Future<Assignment> createAssignment(Assignment assignment) async {
    final doc = await _guard(
      () => _service.databases.createDocument(
        databaseId: _service.databaseId,
        collectionId: assignmentsCollection,
        documentId: ID.unique(),
        data: assignment.toPayload(),
        permissions: [
          Permission.read(Role.users()),
          Permission.update(Role.user(assignment.teacherId)),
          Permission.delete(Role.user(assignment.teacherId)),
        ],
      ),
    );
    return Assignment.fromDocument(doc);
  }

  Future<Assignment> updateAssignment(String id, Map<String, dynamic> changes) async {
    final doc = await _guard(
      () => _service.databases.updateDocument(
        databaseId: _service.databaseId,
        collectionId: assignmentsCollection,
        documentId: id,
        data: changes,
      ),
    );
    return Assignment.fromDocument(doc);
  }

  Future<void> deleteAssignment(String id) async {
    await _guard(
      () => _service.databases.deleteDocument(
        databaseId: _service.databaseId,
        collectionId: assignmentsCollection,
        documentId: id,
      ),
    );
  }

  /// Rendus d'un devoir — vue enseignant.
  Future<List<Submission>> listSubmissions(String assignmentId) async {
    final response = await _guard(
      () => _service.databases.listDocuments(
        databaseId: _service.databaseId,
        collectionId: submissionsCollection,
        queries: [
          Query.equal('assignmentId', assignmentId),
          Query.orderDesc('submittedAt'),
          Query.limit(500),
        ],
      ),
    );
    return response.documents.map((doc) => Submission.fromDocument(doc)).toList();
  }

  /// Rendus d'un élève, tous devoirs confondus — vue élève.
  Future<List<Submission>> listStudentSubmissions(String studentId) async {
    final response = await _guard(
      () => _service.databases.listDocuments(
        databaseId: _service.databaseId,
        collectionId: submissionsCollection,
        queries: [
          Query.equal('studentId', studentId),
          Query.limit(200),
        ],
      ),
    );
    return response.documents.map((doc) => Submission.fromDocument(doc)).toList();
  }

  /// Rend un devoir.
  ///
  /// Un second rendu remplace le premier : la contrainte d'unicité
  /// `(assignmentId, studentId)` posée sur la collection l'interdit, on met
  /// donc à jour la ligne existante plutôt que d'en créer une deuxième.
  Future<Submission> submit(Submission submission) async {
    final existing = await _existingSubmission(
      submission.assignmentId,
      submission.studentId,
    );

    if (existing == null) {
      final doc = await _guard(
        () => _service.databases.createDocument(
          databaseId: _service.databaseId,
          collectionId: submissionsCollection,
          documentId: ID.unique(),
          data: submission.toPayload(),
          permissions: _submissionPermissions(
            studentId: submission.studentId,
            teacherId: null,
          ),
        ),
      );
      return Submission.fromDocument(doc);
    }

    final doc = await _guard(
      () => _service.databases.updateDocument(
        databaseId: _service.databaseId,
        collectionId: submissionsCollection,
        documentId: existing.id,
        data: submission.toPayload(),
      ),
    );
    return Submission.fromDocument(doc);
  }

  /// Note et commente un rendu — vue enseignant.
  Future<Submission> grade({
    required String submissionId,
    required double score,
    String? feedback,
    String? teacherId,
  }) async {
    final doc = await _guard(
      () => _service.databases.updateDocument(
        databaseId: _service.databaseId,
        collectionId: submissionsCollection,
        documentId: submissionId,
        data: {
          'score': score,
          'feedback': feedback,
          'status': SubmissionStatus.graded.value,
          'gradedAt': DateTime.now().toUtc().toIso8601String(),
        },
      ),
    );
    return Submission.fromDocument(doc);
  }

  /// Téléverse un énoncé (PDF/TD) et renvoie l'identifiant du fichier.
  Future<models.File> uploadFile({
    required String name,
    required List<int> bytes,
  }) async {
    return _guard(
      () => _service.storage.createFile(
        bucketId: _service.storageBucketId,
        fileId: ID.unique(),
        file: InputFile.fromBytes(bytes: bytes, filename: name),
        permissions: [Permission.read(Role.users())],
      ),
    );
  }

  /// URL de téléchargement d'un fichier du bucket `uniflow_assets`.
  ///
  /// Elle est construite plutôt que demandée à l'API : `getFileDownload`
  /// consomme une requête réseau pour une valeur déterministe, et l'aperçu
  /// d'un PDF doit pouvoir s'ouvrir instantanément.
  String? fileUrl(String? fileId) {
    if (fileId == null || fileId.isEmpty) return null;
    return '${_service.client.endPoint}/storage/buckets/'
        '${_service.storageBucketId}/files/$fileId/view'
        '?project=${_service.client.config['project']}';
  }

  Future<Submission?> _existingSubmission(String assignmentId, String studentId) async {
    final response = await _guard(
      () => _service.databases.listDocuments(
        databaseId: _service.databaseId,
        collectionId: submissionsCollection,
        queries: [
          Query.equal('assignmentId', assignmentId),
          Query.equal('studentId', studentId),
          Query.limit(1),
        ],
      ),
    );
    if (response.documents.isEmpty) return null;
    return Submission.fromDocument(response.documents.first);
  }

  /// L'élève peut lire et modifier son rendu ; l'enseignant peut le lire.
  List<String> _submissionPermissions({
    required String studentId,
    required String? teacherId,
  }) {
    return [
      Permission.read(Role.user(studentId)),
      Permission.update(Role.user(studentId)),
      Permission.delete(Role.user(studentId)),
      if (teacherId != null && teacherId.isNotEmpty) Permission.read(Role.user(teacherId)),
    ];
  }

  /// Traduit une erreur Appwrite en message compréhensible.
  ///
  /// Le message brut (« Collection with the requested ID could not be found »)
  /// n'aide pas un utilisateur ; il est conservé pour les cas non prévus.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AppwriteException catch (e) {
      throw AssignmentException(_readable(e));
    }
  }

  String _readable(AppwriteException e) {
    // `AppwriteException.message` est nullable : une exception sans message
    // ne doit pas produire « null » à l'écran.
    final raw = e.message ?? 'Erreur Appwrite (code ${e.code ?? 'inconnu'}).';
    switch (e.code) {
      case 401:
        return 'Votre session a expiré. Reconnectez-vous.';
      case 403:
        return 'Action non autorisée pour ce compte.';
      case 404:
        return 'Devoir introuvable.';
      case 409:
        return 'Ce rendu existe déjà.';
      default:
        if (e.type == 'general_argument_invalid') {
          return 'Données invalides : $raw';
        }
        return raw;
    }
  }
}

final assignmentRepositoryProvider = Provider<AssignmentRepository>((ref) {
  return AssignmentRepository(ref.watch(appwriteServiceProvider));
});
