import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/appwrite_provider.dart';
import '../services/appwrite_service.dart';
import '../models/appwrite_models.dart';

class AuthRepository {
  final AppwriteService _service;
  AuthRepository(this._service);

  Account get _account => _service.account;
  Databases get _databases => _service.databases;

  Future<void> login(String email, String password) async {
    try {
      await _account.deleteSession(sessionId: 'current');
    } catch (_) {}
    await _account.createEmailPasswordSession(
      email: email,
      password: password,
    );
  }

  Future<void> logout() async {
    await _account.deleteSession(sessionId: 'current');
  }

  Future<UniFlowUser?> getCurrentUser() async {
    try {
      final account = await _account.get();
      final doc = await _databases.getDocument(
        databaseId: _service.databaseId,
        collectionId: 'users',
        documentId: account.$id,
      );

      return UniFlowUser(
        id: account.$id,
        email: account.email,
        name: account.name,
        accountType: doc.data['accountType'] ?? 'UNIVERSITY',
        role: doc.data['role'] ?? 'STUDENT',
        university: doc.data['university'],
        program: doc.data['program'],
        level: doc.data['level'],
        country: doc.data['country'],
      );
    } catch (e) {
      return null;
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final service = ref.watch(appwriteServiceProvider);
  return AuthRepository(service);
});
