import 'package:appwrite/appwrite.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Valeurs de repli quand la `.env` embarquée est antérieure à une variable.
///
/// Elles correspondent au projet Appwrite Cloud actuel : un seul bucket
/// `uniflow_assets` (offre gratuite) et une seule Function `uniflow-api`. Les
/// anciens identifiants du serveur auto-hébergé (`6aa81b84…`, `uniflow_avatars`,
/// `uniflow_chat_files`) ne doivent plus apparaître nulle part : ils renvoyaient
/// un 404 sur le Cloud à chaque lecture de photo ou de pièce jointe.
const String kDefaultBucketId = 'uniflow_assets';
const String kDefaultApiFunctionId = 'uniflow-api';
const String kDefaultWebAppUrl = 'https://uniflow.kernelforge.codes';

class AppwriteService {
  late Client client;
  late Account account;
  late Databases databases;
  late Storage storage;
  late Functions functions;
  late String endpoint;
  late String projectId;
  late String databaseId;
  late String storageBucketId;

  /// Bucket des photos de profil. Sur le Cloud c'est le même bucket que
  /// [storageBucketId] ; la distinction est conservée pour que l'application
  /// suive la `.env` si un jour les deux redeviennent distincts.
  late String avatarBucketId;

  /// Bucket des pièces jointes de la messagerie (même remarque).
  late String chatFilesBucketId;

  /// Identifiant de la Function HTTP unique qui aiguille les services
  /// (`/messaging`, `/attendance-secure`, …) sur le chemin appelé.
  late String apiFunctionId;

  /// Adresse publique du client web, pour les liens « s'inscrire sur le web »
  /// et la page de réinitialisation de mot de passe.
  late String webAppUrl;

  AppwriteService() {
    endpoint = dotenv.get('APPWRITE_ENDPOINT');
    projectId = dotenv.get('APPWRITE_PROJECT_ID');
    client = Client()
        .setEndpoint(endpoint)
        .setProject(projectId)
        .setSelfSigned(status: true);

    account = Account(client);
    databases = Databases(client);
    storage = Storage(client);
    functions = Functions(client);
    databaseId = dotenv.get('APPWRITE_DATABASE_ID');
    storageBucketId =
        dotenv.maybeGet('APPWRITE_STORAGE_BUCKET_ID') ?? kDefaultBucketId;
    avatarBucketId =
        dotenv.maybeGet('APPWRITE_AVATAR_BUCKET_ID') ?? storageBucketId;
    chatFilesBucketId =
        dotenv.maybeGet('APPWRITE_CHAT_FILES_BUCKET_ID') ?? storageBucketId;
    apiFunctionId =
        dotenv.maybeGet('APPWRITE_API_FUNCTION_ID') ?? kDefaultApiFunctionId;
    webAppUrl = (dotenv.maybeGet('APP_WEB_URL') ?? kDefaultWebAppUrl)
        .replaceAll(RegExp(r'/+$'), '');
  }

  /// URL publique d'un fichier du bucket unique (photos d'équipe, énoncés).
  String fileViewUrl(String fileId, {String? bucketId}) {
    final base = endpoint.replaceAll(RegExp(r'/+$'), '');
    return '$base/storage/buckets/${bucketId ?? storageBucketId}/files/$fileId/view?project=$projectId';
  }
}
