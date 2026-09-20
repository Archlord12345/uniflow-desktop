import 'package:appwrite/appwrite.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../appwrite_service.dart';
import 'conference_models.dart';

/// Annuaire des réunions, publié dans Appwrite.
///
/// Sans serveur central, un participant distant n'a aucun moyen de connaître
/// l'adresse de la machine qui héberge la réunion. Cette collection
/// `conference_rooms` joue ce rôle : l'hôte y publie l'adresse de son API de
/// jonction et le code de la salle, le participant l'y retrouve.
///
/// Rien de secret n'y transite : ni le secret de signature, ni le jeton
/// d'administration. Le code publié ne suffit pas non plus à entrer, la
/// jonction exigeant de présenter ce code à l'hôte lui-même.
///
/// Toutes les opérations sont tolérantes à l'échec : si la collection n'existe
/// pas encore ou si les permissions la refusent, l'hébergement local continue
/// de fonctionner et l'écran le signale.
class ConferenceRegistry {
  final AppwriteService _service;

  ConferenceRegistry(this._service);

  /// Collection de l'annuaire, surchargeable depuis `.env` pour ne pas
  /// dépendre d'un nom figé.
  static String get collectionId =>
      dotenv.maybeGet('APPWRITE_CONFERENCE_COLLECTION_ID') ??
      'conference_rooms';

  /// Publie une réunion. Renvoie l'identifiant du document créé, ou `null` si
  /// la publication a échoué.
  Future<String?> publish(HostedConference conference) async {
    try {
      final document = await _service.databases.createDocument(
        databaseId: _service.databaseId,
        collectionId: collectionId,
        documentId: ID.unique(),
        data: conference.toRegistryPayload(),
      );
      return document.$id;
    } catch (_) {
      return null;
    }
  }

  /// Marque une réunion comme terminée dans l'annuaire.
  Future<bool> markEnded(String documentId) async {
    try {
      await _service.databases.updateDocument(
        databaseId: _service.databaseId,
        collectionId: collectionId,
        documentId: documentId,
        data: {
          'status': 'ENDED',
          'endedAt': DateTime.now().toIso8601String(),
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Réunions en cours, les plus récentes d'abord.
  ///
  /// Une erreur de lecture renvoie une liste vide : l'écran affiche alors
  /// « aucune réunion trouvée » plutôt que d'échouer.
  Future<List<DiscoveredConference>> listActive({int limit = 50}) async {
    try {
      final response = await _service.databases.listDocuments(
        databaseId: _service.databaseId,
        collectionId: collectionId,
        queries: [
          Query.equal('status', 'ACTIVE'),
          Query.orderDesc(r'$createdAt'),
          Query.limit(limit),
        ],
      );
      return [
        for (final document in response.documents)
          DiscoveredConference.fromData(document.$id, document.data),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Vrai si l'annuaire est utilisable (collection présente et lisible).
  Future<bool> isAvailable() async {
    try {
      await _service.databases.listDocuments(
        databaseId: _service.databaseId,
        collectionId: collectionId,
        queries: [Query.limit(1)],
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
