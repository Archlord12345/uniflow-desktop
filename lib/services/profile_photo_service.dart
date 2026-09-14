import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/appwrite_models.dart';
import '../providers/appwrite_provider.dart';
import '../providers/auth_provider.dart';
import '../repositories/auth_repository.dart';
import '../services/appwrite_service.dart';
import '../utils/avatar.dart';

/// Téléversement et retrait de la photo de profil dans le bucket Appwrite
/// `uniflow_avatars`, puis enregistrement de l'identifiant du fichier sur le
/// document `users` du compte.
///
/// Le bucket est distinct de `uniflow_assets` : il est lisible publiquement,
/// car un avatar doit s'afficher dans les listes et les conversations sans
/// exiger de session.
class ProfilePhotoService {
  final AppwriteService _service;
  ProfilePhotoService(this._service);

  Storage get _storage => _service.storage;
  Databases get _databases => _service.databases;
  String get _bucket => _service.avatarBucketId;

  /// Téléverse le fichier situé à [path] et l'enregistre sur le profil.
  /// Renvoie le nouvel identifiant de fichier.
  ///
  /// L'ancienne photo est supprimée après la mise à jour du profil, jamais
  /// avant : sinon un échec d'enregistrement laisserait le compte sans photo
  /// alors que la nouvelle image serait déjà perdue.
  Future<String> upload({
    required String userId,
    required String path,
    String? previousFileId,
  }) async {
    final invalid = validateAvatarPath(path);
    if (invalid != null) throw ProfilePhotoException(invalid);

    final models.File created;
    try {
      created = await _storage.createFile(
        bucketId: _bucket,
        fileId: ID.unique(),
        file: InputFile.fromPath(
          path: path,
          // Le nom est normalisé pour que l'extension vue par Appwrite soit
          // toujours l'une des extensions autorisées par le bucket.
          filename: 'avatar.${path.split('.').last.toLowerCase()}',
        ),
        // Lecture publique : l'avatar doit s'afficher partout, y compris pour
        // un visiteur non connecté. Le bucket a `fileSecurity` activé, donc ce
        // sont les permissions du fichier qui décident, pas celles du bucket.
        permissions: [Permission.read(Role.any())],
      );
    } on AppwriteException catch (error) {
      if (error.code == 404) {
        throw ProfilePhotoException(
          'Le bucket « $_bucket » est introuvable sur Appwrite. '
          'Lancez scripts/provision-appwrite-selfhosted.mjs pour le créer.',
        );
      }
      throw ProfilePhotoException(_readable(error, 'le téléversement'));
    }

    try {
      await _databases.updateDocument(
        databaseId: _service.databaseId,
        collectionId: 'users',
        documentId: userId,
        data: {'avatarFileId': created.$id},
      );
    } catch (error) {
      // Sans cet enregistrement l'image resterait orpheline : on la retire.
      try {
        await _storage.deleteFile(bucketId: _bucket, fileId: created.$id);
      } catch (_) {}
      if (error is AppwriteException &&
          (error.message ?? '').contains('avatarFileId')) {
        throw ProfilePhotoException(
          'L\'attribut « avatarFileId » manque sur la collection users. '
          'Lancez scripts/provision-appwrite-selfhosted.mjs.',
        );
      }
      throw ProfilePhotoException(
        error is AppwriteException
            ? _readable(error, 'l\'enregistrement de la photo')
            : 'L\'enregistrement de la photo a échoué.',
      );
    }

    // Au mieux : un échec ici ne signifie pas que le téléversement a échoué.
    if (previousFileId != null &&
        previousFileId.isNotEmpty &&
        previousFileId != created.$id) {
      try {
        await _storage.deleteFile(bucketId: _bucket, fileId: previousFileId);
      } catch (_) {}
    }
    return created.$id;
  }

  /// Retire la photo de profil et supprime le fichier correspondant.
  Future<void> remove({required String userId, String? fileId}) async {
    await _databases.updateDocument(
      databaseId: _service.databaseId,
      collectionId: 'users',
      documentId: userId,
      data: {'avatarFileId': ''},
    );
    if (fileId != null && fileId.isNotEmpty) {
      try {
        await _storage.deleteFile(bucketId: _bucket, fileId: fileId);
      } catch (_) {}
    }
  }

  String _readable(AppwriteException error, String operation) {
    switch (error.code) {
      case 401:
        return 'Session expirée pendant $operation. Reconnectez-vous.';
      case 403:
        return 'Ce compte n\'est pas autorisé à modifier sa photo de profil.';
      case 413:
        return 'L\'image est trop volumineuse pour le bucket Appwrite.';
      default:
        return 'Appwrite a refusé $operation (code ${error.code}).';
    }
  }
}

class ProfilePhotoException implements Exception {
  final String message;
  ProfilePhotoException(this.message);
  @override
  String toString() => message;
}

final profilePhotoServiceProvider = Provider<ProfilePhotoService>((ref) {
  return ProfilePhotoService(ref.watch(appwriteServiceProvider));
});

/// Raccourcis pour les écrans : téléverser puis rafraîchir l'état global, sans
/// que chaque appelant ait à connaître les deux fournisseurs concernés.
extension ProfilePhotoActions on WidgetRef {
  /// Téléverse l'image choisie et met à jour le profil en mémoire, afin que la
  /// sidebar et l'en-tête se rafraîchissent sans redémarrer l'application.
  Future<String> uploadAvatar(String path, UniFlowUser user) async {
    final fileId = await read(profilePhotoServiceProvider).upload(
      userId: user.id,
      path: path,
      previousFileId: user.avatarFileId,
    );
    read(currentUserProvider.notifier).state =
        user.copyWith(avatarFileId: fileId);
    return fileId;
  }

  /// Retire la photo de profil et remet l'affichage sur les initiales.
  Future<void> removeAvatar(UniFlowUser user) async {
    await read(profilePhotoServiceProvider)
        .remove(userId: user.id, fileId: user.avatarFileId);
    read(currentUserProvider.notifier).state = user.copyWith(avatarFileId: '');
  }

  /// Relit le profil depuis Appwrite et remplace l'état en mémoire.
  Future<void> refreshProfile() async {
    final refreshed = await read(authRepositoryProvider).refreshProfile();
    if (refreshed != null) {
      read(currentUserProvider.notifier).state = refreshed;
    }
  }
}
