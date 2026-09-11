import 'package:appwrite/appwrite.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppwriteService {
  late Client client;
  late Account account;
  late Databases databases;
  late Storage storage;
  late Functions functions;
  late String databaseId;
  late String storageBucketId;
  late String apiToken;

  AppwriteService() {
    client = Client()
        .setEndpoint(dotenv.get('APPWRITE_ENDPOINT'))
        .setProject(dotenv.get('APPWRITE_PROJECT_ID'))
        .setSelfSigned(status: true);

    account = Account(client);
    databases = Databases(client);
    storage = Storage(client);
    functions = Functions(client);
    databaseId = dotenv.get('APPWRITE_DATABASE_ID');
    storageBucketId = dotenv.get('APPWRITE_STORAGE_BUCKET_ID');
    apiToken = dotenv.get('UNIFLOW_API_TOKEN', fallback: '');
  }
}
