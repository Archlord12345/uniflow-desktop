import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/reference_models.dart';
import '../providers/appwrite_provider.dart';
import '../services/appwrite_service.dart';

/// Accès aux quatre collections du référentiel académique.
///
/// Elles sont lisibles sans session (`read("any")`) : l'écran d'inscription,
/// qui s'affiche avant toute connexion, peut donc proposer la liste réelle
/// des universités et filières.
class ReferenceRepository {
  final AppwriteService _service;
  ReferenceRepository(this._service);

  Future<List<T>> _list<T>(
    String collectionId,
    T Function(dynamic doc) build, {
    List<String>? queries,
  }) async {
    final response = await _service.databases.listDocuments(
      databaseId: _service.databaseId,
      collectionId: collectionId,
      queries: queries ?? [Query.limit(500)],
    );
    return response.documents.map(build).toList();
  }

  /// Une collection absente (schéma pas encore provisionné) renvoie une liste
  /// vide : le formulaire propose alors une saisie libre au lieu de planter.
  Future<List<T>> _tolerant<T>(Future<List<T>> Function() load) async {
    try {
      return await load();
    } on AppwriteException catch (error) {
      if (error.code == 404) return const [];
      rethrow;
    }
  }

  Future<List<University>> getUniversities() => _tolerant(() => _list(
        'universities',
        (doc) => University.fromDocument(doc),
        queries: [Query.orderAsc('name'), Query.limit(200)],
      ));

  Future<List<Faculty>> getFaculties() => _tolerant(() => _list(
        'faculties',
        (doc) => Faculty.fromDocument(doc),
        queries: [Query.orderAsc('name'), Query.limit(500)],
      ));

  Future<List<AcademicProgram>> getPrograms() => _tolerant(() => _list(
        'academic_programs',
        (doc) => AcademicProgram.fromDocument(doc),
        queries: [Query.orderAsc('name'), Query.limit(500)],
      ));

  Future<List<ClassroomRef>> getClassrooms() => _tolerant(() => _list(
        'classrooms',
        (doc) => ClassroomRef.fromDocument(doc),
        queries: [Query.orderAsc('code'), Query.limit(1000)],
      ));

  Future<AcademicReference> getAll() async {
    final results = await Future.wait([
      getUniversities(),
      getFaculties(),
      getPrograms(),
      getClassrooms(),
    ]);
    return AcademicReference(
      universities: results[0] as List<University>,
      faculties: results[1] as List<Faculty>,
      programs: results[2] as List<AcademicProgram>,
      classrooms: results[3] as List<ClassroomRef>,
    );
  }

  /// Écritures sur `classrooms`. La collection n'ouvre que la lecture au
  /// niveau collection ; ces appels aboutissent uniquement si le schéma
  /// accorde `create("users")` avec sécurité par document, ou si un service
  /// de la Function les relaie — signalé au propriétaire.
  Future<ClassroomRef> createClassroom(ClassroomRef room) async {
    final doc = await _service.databases.createDocument(
      databaseId: _service.databaseId,
      collectionId: 'classrooms',
      documentId: ID.unique(),
      data: room.toPayload(),
      permissions: [Permission.read(Role.any()), Permission.update(Role.users()), Permission.delete(Role.users())],
    );
    return ClassroomRef.fromDocument(doc);
  }

  Future<ClassroomRef> updateClassroom(ClassroomRef room) async {
    final doc = await _service.databases.updateDocument(
      databaseId: _service.databaseId,
      collectionId: 'classrooms',
      documentId: room.id,
      data: room.toPayload(),
    );
    return ClassroomRef.fromDocument(doc);
  }

  Future<void> deleteClassroom(String id) => _service.databases.deleteDocument(
        databaseId: _service.databaseId,
        collectionId: 'classrooms',
        documentId: id,
      );
}

final referenceRepositoryProvider = Provider<ReferenceRepository>((ref) {
  return ReferenceRepository(ref.watch(appwriteServiceProvider));
});

/// Référentiel complet, partagé par l'inscription et l'administration.
final academicReferenceProvider = FutureProvider<AcademicReference>((ref) {
  return ref.watch(referenceRepositoryProvider).getAll();
});
