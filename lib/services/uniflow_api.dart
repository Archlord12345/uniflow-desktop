import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/appwrite_provider.dart';
import 'appwrite_service.dart';

/// Chemins des services servis par la Function unique `uniflow-api`.
///
/// Ils reproduisent le routeur `functions/uniflow-api/src/main.js` du web : le
/// serveur aiguille sur `req.path`, un chemin inconnu renvoie 404. Les garder
/// ici évite qu'un écran appelle « /grades » quand le serveur attend
/// « /academic-grades ».
abstract final class ApiPaths {
  static const messaging = '/messaging';
  static const attendanceSecure = '/attendance-secure';
  static const academicGrades = '/academic-grades';
  static const academicRegistration = '/academic-registration';
  static const adminDirectory = '/admin-directory';
  static const forumReactions = '/forum-reactions';
  static const contactMessages = '/contact-messages';
  static const subscriptionPayments = '/subscription-payments';
  static const teamRoster = '/team-roster';
}

/// Erreur portant le message rédigé par la Function.
///
/// Les services distinguent déjà « pseudo introuvable », « périmètre refusé »,
/// « session expirée » : ces textes sont destinés à l'utilisateur et ne doivent
/// pas être remplacés par un libellé générique.
class ApiException implements Exception {
  final String message;
  final String code;
  final int? status;

  const ApiException(this.message, {this.code = '', this.status});

  bool get isAuthError => status == 401 || code == 'AUTH_REQUIRED';

  @override
  String toString() => message;
}

/// Décode la réponse d'une exécution et applique le contrat `{ok, …}`.
///
/// Fonction pure, testable sans réseau. Le corps est analysé même lorsque le
/// statut d'exécution n'est pas `completed` : Appwrite marque l'exécution en
/// échec dès que la Function répond en 4xx, alors que le corps contient
/// justement le message explicite à montrer.
Map<String, dynamic> decodeApiResponse(
  String body, {
  String status = 'completed',
  int? httpStatus,
  String path = '',
}) {
  Map<String, dynamic>? data;
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map) data = Map<String, dynamic>.from(decoded);
  } catch (_) {
    data = null;
  }

  if (data == null) {
    // Un 404 sans JSON est la signature d'un chemin que le routeur ne connaît
    // pas (ou d'une Function non déployée) : le dire évite de chercher un bug
    // côté écran.
    if (httpStatus == 404) {
      throw ApiException(
        'Le service « $path » n\'est pas exposé par la Function uniflow-api.',
        code: 'NOT_FOUND',
        status: 404,
      );
    }
    throw ApiException(
      'Le serveur a répondu de façon inattendue ($status'
      '${httpStatus == null ? '' : ', HTTP $httpStatus'}).',
      code: 'BAD_RESPONSE',
      status: httpStatus,
    );
  }

  if (data['ok'] != true) {
    throw ApiException(
      (data['message'] ?? data['error'] ?? 'L\'opération a échoué.').toString(),
      code: (data['code'] ?? '').toString(),
      status: httpStatus,
    );
  }
  return data;
}

/// Passerelle vers la Function HTTP unique.
///
/// Un seul point d'appel pour les neuf services : c'est ici, et seulement ici,
/// que l'identifiant de la Function est lu (`APPWRITE_API_FUNCTION_ID`), que la
/// méthode et le chemin sont posés, et que la réponse est décodée. Avant la
/// migration, chaque dépôt portait son propre `functionId` figé
/// (« messaging »), mort depuis la fusion des Functions.
class UniFlowApi {
  final AppwriteService _service;

  UniFlowApi(this._service);

  String get functionId => _service.apiFunctionId;

  /// Appelle `path` avec `payload` en POST et renvoie la charge utile.
  Future<Map<String, dynamic>> call(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final models.Execution execution;
    try {
      execution = await _service.functions.createExecution(
        functionId: functionId,
        body: jsonEncode(payload),
        xasync: false,
        path: path,
        method: ExecutionMethod.pOST,
      );
    } on AppwriteException catch (error) {
      throw ApiException(
        error.code == 404
            ? 'La Function « $functionId » n\'est pas déployée sur Appwrite.'
            : (error.message ?? 'Appwrite a refusé l\'appel (code ${error.code}).'),
        code: 'EXECUTION_FAILED',
        status: error.code,
      );
    }

    return decodeApiResponse(
      execution.responseBody,
      status: execution.status.value,
      httpStatus: execution.responseStatusCode,
      path: path,
    );
  }
}

final uniflowApiProvider = Provider<UniFlowApi>((ref) {
  return UniFlowApi(ref.watch(appwriteServiceProvider));
});
