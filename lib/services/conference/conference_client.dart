import 'dart:convert';
import 'dart:io';

import 'conference_models.dart';

/// Ticket d'entrée dans une salle : ce que rend `GET /rooms/<id>/join` de
/// l'API de jonction de l'hôte, et ce que l'hôte se forge à lui-même.
class ConferenceTicket {
  final String token;

  /// Adresse WebSocket du serveur média (`ws://192.168.1.10:7880`).
  final String serverUrl;
  final String roomId;
  final String roomName;

  const ConferenceTicket({
    required this.token,
    required this.serverUrl,
    required this.roomId,
    required this.roomName,
  });

  /// Lit la réponse de l'API. `null` si un champ indispensable manque : un
  /// ticket sans jeton ou sans adresse ne mènerait qu'à une erreur de
  /// connexion incompréhensible plus loin.
  static ConferenceTicket? fromJson(Object? json) {
    if (json is! Map) return null;
    final token = (json['token'] ?? '').toString();
    final serverUrl = (json['serverUrl'] ?? '').toString();
    if (token.isEmpty || serverUrl.isEmpty) return null;
    return ConferenceTicket(
      token: token,
      serverUrl: serverUrl,
      roomId: (json['roomId'] ?? '').toString(),
      roomName: (json['roomName'] ?? '').toString(),
    );
  }
}

/// Réunion retrouvée à partir de son code (`GET /rooms/by-code/<CODE>`).
class ConferenceLookup {
  final String roomId;
  final String roomName;
  final String hostName;
  final String serverUrl;

  const ConferenceLookup({
    required this.roomId,
    required this.roomName,
    required this.hostName,
    required this.serverUrl,
  });

  static ConferenceLookup? fromJson(Object? json) {
    if (json is! Map) return null;
    final roomId = (json['roomId'] ?? '').toString();
    if (roomId.isEmpty) return null;
    return ConferenceLookup(
      roomId: roomId,
      roomName: (json['roomName'] ?? '').toString(),
      hostName: (json['hostName'] ?? '').toString(),
      serverUrl: (json['serverUrl'] ?? '').toString(),
    );
  }
}

/// Client de l'API de jonction d'un hôte : c'est ce que fait la page
/// navigateur, mais depuis l'application de bureau d'un participant.
///
/// Deux appels : retrouver la salle à partir du code, puis demander un jeton.
/// Les deux se font en HTTP simple vers la machine de l'hôte, sur le réseau
/// local ; aucun serveur central n'intervient.
class ConferenceClient {
  final Duration timeout;

  const ConferenceClient({this.timeout = const Duration(seconds: 8)});

  /// Retrouve la réunion [code] hébergée à [apiUrl].
  Future<ConferenceLookup> lookup({
    required String apiUrl,
    required String code,
  }) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) {
      throw const ConferenceException('Saisissez le code de la réunion.');
    }
    final json = await _get(
      _uri(apiUrl, '/rooms/by-code/${Uri.encodeComponent(normalized)}'),
      notFound: 'Aucune réunion en cours ne porte ce code chez cet hôte.',
    );
    final lookup = ConferenceLookup.fromJson(json);
    if (lookup == null) {
      throw const ConferenceException(
          'L\'hôte a répondu dans un format inattendu.');
    }
    return lookup;
  }

  /// Obtient un jeton d'entrée pour la réunion [code] hébergée à [apiUrl].
  ///
  /// [identity] doit être stable pour un même participant (identifiant de
  /// compte) : c'est elle qui rapproche l'arrivée et le départ dans la feuille
  /// de présence. [userId] est transmis pour la même raison.
  Future<ConferenceTicket> join({
    required String apiUrl,
    required String code,
    required String identity,
    required String displayName,
    String? userId,
  }) async {
    final found = await lookup(apiUrl: apiUrl, code: code);
    final query = <String, String>{
      'code': code.trim().toUpperCase(),
      'identity': identity,
      'name': displayName,
      if (userId != null && userId.isNotEmpty) 'userId': userId,
    };
    final uri = _uri(apiUrl, '/rooms/${Uri.encodeComponent(found.roomId)}/join')
        .replace(queryParameters: query);
    final json = await _get(uri,
        notFound: 'Cette réunion n\'existe plus ou est terminée.');
    final ticket = ConferenceTicket.fromJson(json);
    if (ticket == null) {
      throw const ConferenceException(
          'L\'hôte a délivré un ticket incomplet : réessayez.');
    }
    return ticket;
  }

  static Uri _uri(String apiUrl, String path) {
    final base = apiUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.tryParse('$base$path');
    if (uri == null || uri.host.isEmpty) {
      throw ConferenceException('Adresse d\'hôte invalide : « $apiUrl ».');
    }
    return uri;
  }

  Future<Object?> _get(Uri uri, {required String notFound}) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(uri).timeout(timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(timeout);
      final body = await response.transform(utf8.decoder).join();
      Object? json;
      try {
        json = jsonDecode(body);
      } on FormatException {
        json = null;
      }
      if (response.statusCode == HttpStatus.ok) return json;
      final message = json is Map ? json['error']?.toString() : null;
      throw ConferenceException(switch (response.statusCode) {
        HttpStatus.notFound => message ?? notFound,
        HttpStatus.forbidden => message ?? 'Code de réunion incorrect.',
        HttpStatus.tooManyRequests =>
          message ?? 'Trop de tentatives : patientez une minute.',
        _ => message ??
            'L\'hôte a répondu ${response.statusCode} à la demande de jonction.',
      });
    } on ConferenceException {
      rethrow;
    } on SocketException catch (error) {
      throw ConferenceException(
          'Impossible de joindre l\'hôte à ${uri.host}:${uri.port} : '
          '${error.osError?.message ?? error.message}. Vérifiez que vous êtes '
          'sur le même réseau et que la réunion est ouverte.');
    } on HttpException catch (error) {
      throw ConferenceException('Réponse HTTP invalide de l\'hôte : ${error.message}');
    } on Object catch (error) {
      throw ConferenceException('La demande de jonction a échoué : $error');
    } finally {
      client.close(force: true);
    }
  }
}
