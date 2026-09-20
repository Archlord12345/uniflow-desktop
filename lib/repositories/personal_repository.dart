import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/appwrite_service.dart';
import '../models/appwrite_models.dart';
import '../providers/appwrite_provider.dart';
import 'auth_repository.dart';

/// Matières de l'espace personnel (`personal_subjects`), réservées aux
/// comptes `PERSONAL`. Chaque document porte les permissions de son
/// propriétaire : la collection n'ouvre que `create("users")`.
class PersonalRepository {
  final AppwriteService _service;

  PersonalRepository(this._service);

  Future<List<PersonalSubject>> getSubjects(String ownerId) async {
    final response = await _service.databases.listDocuments(
      databaseId: _service.databaseId,
      collectionId: 'personal_subjects',
      queries: [
        Query.equal('ownerId', ownerId),
        Query.orderDesc('\$createdAt'),
      ],
    );
    return response.documents
        .map((doc) => PersonalSubject.fromDocument(doc))
        .toList();
  }

  Future<PersonalSubject> createSubject({
    required String ownerId,
    required String name,
    String code = '',
    String instructor = '',
    int credits = 0,
    String colorHex = '#0d9488',
    String classroom = '',
    String description = '',
  }) async {
    final doc = await _service.databases.createDocument(
      databaseId: _service.databaseId,
      collectionId: 'personal_subjects',
      documentId: ID.unique(),
      data: {
        'ownerId': ownerId,
        'name': name.trim(),
        'title': name.trim(),
        'code': code.trim(),
        'instructor': instructor.trim(),
        'credits': credits,
        'colorHex': colorHex,
        'classroom': classroom.trim(),
        'description': description.trim(),
      },
      permissions: [
        Permission.read(Role.user(ownerId)),
        Permission.update(Role.user(ownerId)),
        Permission.delete(Role.user(ownerId)),
      ],
    );
    return PersonalSubject.fromDocument(doc);
  }

  Future<void> deleteSubject(String id) => _service.databases.deleteDocument(
        databaseId: _service.databaseId,
        collectionId: 'personal_subjects',
        documentId: id,
      );
}

final personalRepositoryProvider = Provider<PersonalRepository>((ref) {
  final service = ref.watch(appwriteServiceProvider);
  return PersonalRepository(service);
});

/// Matières du compte connecté.
final personalSubjectsProvider =
    FutureProvider<List<PersonalSubject>>((ref) async {
  final user = await ref.watch(authRepositoryProvider).getCurrentUser();
  if (user == null) return const [];
  return ref.watch(personalRepositoryProvider).getSubjects(user.id);
});
