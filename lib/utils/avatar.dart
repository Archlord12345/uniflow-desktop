import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Convention d'URL des photos de profil, partagée par les trois applications
/// UniFlow (web, mobile, desktop).
///
/// Elle est écrite ici plutôt qu'importée du service Appwrite afin que les
/// widgets de présentation puissent l'utiliser sans dépendre du client Appwrite
/// ni de `flutter_dotenv` déjà chargé.
/// Identifiant du bucket des photos de profil.
///
/// C'est bien l'**identifiant** et non le nom : le bucket s'appelle
/// « uniflow_avatars » mais a été créé sous `6aa81b840031e6a34dc3`, et
/// Appwrite résout les URL par identifiant. Utiliser le nom renvoyait un 404
/// à chaque lecture de photo.
const String avatarBucketId = '6aa81b840031e6a34dc3';

/// Bucket des photos de profil. Surchargeable par `.env` pour ne pas figer un
/// identifiant dans le code si le bucket est recréé côté serveur.
String get _avatarBucket =>
    dotenv.maybeGet('APPWRITE_AVATAR_BUCKET_ID') ?? avatarBucketId;

/// URL publique d'une photo de profil, ou `null` s'il n'y en a pas.
///
/// Renvoie `null` — et non une chaîne vide — pour que les appelants testent
/// directement `if (url == null)` et retombent sur les initiales.
String? avatarUrl(String? fileId) {
  if (fileId == null || fileId.isEmpty) return null;
  final endpoint = dotenv.maybeGet('APPWRITE_ENDPOINT');
  final projectId = dotenv.maybeGet('APPWRITE_PROJECT_ID');
  if (endpoint == null || projectId == null) return null;
  return '${endpoint.replaceAll(RegExp(r'/+$'), '')}/storage/buckets/$_avatarBucket/files/$fileId/view?project=$projectId';
}

/// Extensions et type acceptés par le bucket `uniflow_avatars`.
const List<String> avatarAllowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];

/// Taille maximale acceptée par le bucket, en octets.
const int avatarMaxBytes = 5 * 1024 * 1024;

/// Message d'erreur si le fichier ne convient pas, `null` s'il convient.
String? validateAvatarPath(String path) {
  final extension = path.split('.').last.toLowerCase();
  if (!avatarAllowedExtensions.contains(extension)) {
    return 'Choisissez une image JPEG, PNG ou WebP.';
  }
  return null;
}

/// Initiales à afficher quand il n'y a pas de photo.
String initialsOf(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return 'U';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}
