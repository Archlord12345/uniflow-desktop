import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'conference_models.dart';
import 'livekit_token_service.dart';
import 'livekit_webhook.dart';

/// Appelé quand l'API délivre un ticket de jonction.
typedef TicketIssuedCallback = void Function(IssuedTicket ticket);

/// Appelé pour chaque webhook authentique du serveur média.
typedef WebhookEventCallback = void Function(LiveKitWebhookEvent event);

/// API de jonction embarquée dans l'application desktop.
///
/// C'est elle qui remplace le contrôleur NestJS `POST /conferences/:id/join` :
/// au lieu d'interroger un serveur central, le participant s'adresse
/// directement à la machine de l'hôte, qui vérifie le code de la réunion et
/// lui signe un jeton d'accès. Le secret de signature ne quitte donc jamais
/// le poste de l'hôte.
///
/// Elle reçoit aussi les webhooks de `livekit-server` (arrivées et départs),
/// qui alimentent la feuille de présence : c'est le seul canal par lequel
/// l'hôte apprend qui est réellement connecté sans être lui-même dans la
/// salle.
///
/// Le serveur n'écoute que sur le réseau local de l'hôte ; c'est
/// [ConferenceHostService] qui décide de l'exposer plus largement.
class ConferenceHostServer {
  /// Chemin sur lequel le serveur média doit poster ses webhooks.
  static const String webhookPath = '/livekit/webhook';

  HttpServer? _server;

  /// Salles ouvertes, indexées par identifiant de réunion.
  final Map<String, _OpenRoom> _rooms = {};

  /// Échecs de code par adresse IP, pour freiner les tentatives répétées.
  final Map<String, List<DateTime>> _failedAttempts = {};

  /// Au-delà de ce nombre d'échecs sur une minute, l'adresse est ignorée.
  static const int _maxAttemptsPerMinute = 10;

  /// Taille maximale d'un webhook accepté. Un événement fait quelques
  /// centaines d'octets ; au-delà, c'est une machine du réseau qui teste le
  /// service, pas le serveur média.
  static const int _maxWebhookBytes = 64 * 1024;

  final LiveKitTokenService _tokens;
  final LiveKitWebhookVerifier _webhooks;

  TicketIssuedCallback? onTicketIssued;
  WebhookEventCallback? onWebhookEvent;

  ConferenceHostServer({
    LiveKitTokenService? tokenService,
    LiveKitWebhookVerifier? webhookVerifier,
    this.onTicketIssued,
    this.onWebhookEvent,
  })  : _tokens = tokenService ?? const LiveKitTokenService(),
        _webhooks = webhookVerifier ?? const LiveKitWebhookVerifier();

  bool get isRunning => _server != null;

  /// Port réellement écouté (`null` tant que le serveur n'est pas démarré).
  int? get port => _server?.port;

  /// Démarre l'écoute sur [port], toutes interfaces confondues.
  Future<void> start({required int port}) async {
    if (_server != null) return;
    final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    server.autoCompress = true;
    _server = server;
    unawaited(_serve(server));
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _rooms.clear();
    _failedAttempts.clear();
  }

  /// Ouvre une salle : l'API acceptera les demandes de jonction qui
  /// présentent le bon code.
  ///
  /// [publicBaseUrl] remplace l'adresse annoncée aux participants quand l'hôte
  /// expose une adresse publique ; sinon c'est l'adresse locale qui est
  /// renvoyée.
  void openRoom({
    required HostedConference conference,
    required ConferenceCredentials credentials,
  }) {
    _rooms[conference.id] = _OpenRoom(
      conference: conference,
      credentials: credentials,
    );
  }

  /// Ferme une salle : les jetons déjà délivrés restent valides jusqu'à leur
  /// expiration, mais plus aucun nouveau participant ne peut en obtenir.
  void closeRoom(String roomId) => _rooms.remove(roomId);

  /// Salles actuellement ouvertes.
  List<HostedConference> get openRooms =>
      [for (final room in _rooms.values) room.conference];

  Future<void> _serve(HttpServer server) async {
    await for (final request in server) {
      try {
        await _handle(request);
      } on Object catch (error) {
        await _json(request, HttpStatus.internalServerError, {
          'error': 'Erreur interne du service de réunion : $error',
        });
      }
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final segments = request.uri.pathSegments;

    if (request.method == 'GET' &&
        segments.length == 1 &&
        segments[0] == 'health') {
      return _json(request, HttpStatus.ok, {
        'status': 'ok',
        'rooms': _rooms.length,
      });
    }

    // GET /rooms/<id>/join
    if (request.method == 'GET' &&
        segments.length == 3 &&
        segments[0] == 'rooms' &&
        segments[2] == 'join') {
      return _join(request, segments[1]);
    }

    // POST /rooms/<id>/end
    if (request.method == 'POST' &&
        segments.length == 3 &&
        segments[0] == 'rooms' &&
        segments[2] == 'end') {
      return _end(request, segments[1]);
    }

    // POST /livekit/webhook
    if (request.method == 'POST' && request.uri.path == webhookPath) {
      return _webhook(request);
    }

    return _json(request, HttpStatus.notFound, {'error': 'Route inconnue.'});
  }

  /// Reçoit un événement du serveur média.
  ///
  /// Le corps est lu en octets bruts avant tout décodage : l'empreinte signée
  /// porte sur ces octets exacts, et un JSON ré-encodé ne donnerait pas la
  /// même empreinte. La salle est lue dans le corps pour retrouver la clé qui
  /// a signé ; un événement pour une salle inconnue (fermée entre-temps, ou
  /// inventé) est accepté et ignoré : répondre une erreur ferait réessayer le
  /// serveur média plusieurs fois pour rien.
  Future<void> _webhook(HttpRequest request) async {
    final body = <int>[];
    await for (final chunk in request) {
      body.addAll(chunk);
      if (body.length > _maxWebhookBytes) {
        return _json(request, HttpStatus.requestEntityTooLarge,
            {'error': 'Événement trop volumineux.'});
      }
    }

    final now = DateTime.now();
    LiveKitWebhookEvent? event;
    try {
      event = LiveKitWebhookEvent.fromJson(jsonDecode(utf8.decode(body)),
          now: now);
    } on FormatException {
      event = null;
    }
    if (event == null) {
      return _json(
          request, HttpStatus.badRequest, {'error': 'Événement illisible.'});
    }

    final room = event.roomName == null ? null : _rooms[event.roomName];
    if (room == null) {
      return _json(request, HttpStatus.ok, {'status': 'ignored'});
    }

    final refusal = _webhooks.verify(
      body: body,
      authorization: request.headers.value(HttpHeaders.authorizationHeader),
      apiKey: room.credentials.apiKey,
      apiSecret: room.credentials.apiSecret,
      now: now,
    );
    if (refusal != null) {
      debugPrint('Webhook LiveKit refusé (${event.rawType}) : $refusal');
      return _json(
          request, HttpStatus.unauthorized, {'error': 'Signature refusée.'});
    }

    onWebhookEvent?.call(event);
    return _json(request, HttpStatus.ok, {'status': 'ok'});
  }

  /// Délivre un jeton d'accès à un participant qui présente le bon code.
  Future<void> _join(HttpRequest request, String roomId) async {
    final room = _rooms[roomId];
    if (room == null || room.conference.status == ConferenceStatus.ended) {
      return _json(request, HttpStatus.notFound,
          {'error': 'Cette réunion n\'existe pas ou est terminée.'});
    }

    final remote = request.connectionInfo?.remoteAddress.address ?? 'inconnue';
    if (_isThrottled(remote)) {
      return _json(request, HttpStatus.tooManyRequests, {
        'error': 'Trop de tentatives. Réessayez dans une minute.',
      });
    }

    final query = request.uri.queryParameters;
    final code = (query['code'] ?? '').trim().toUpperCase();
    if (code.isEmpty || code != room.conference.code.toUpperCase()) {
      _recordFailure(remote);
      return _json(request, HttpStatus.forbidden, {
        'error': 'Code de réunion incorrect.',
      });
    }

    final identity = (query['identity'] ?? '').trim();
    if (identity.isEmpty) {
      return _json(request, HttpStatus.badRequest, {
        'error': 'Identifiant de participant manquant.',
      });
    }

    final displayName = (query['name'] ?? '').trim();
    final token = _tokens.mint(
      apiKey: room.credentials.apiKey,
      apiSecret: room.credentials.apiSecret,
      roomName: room.conference.id,
      identity: identity,
      displayName: displayName.isEmpty ? null : displayName,
    );

    // Le ticket est signalé avant la réponse : la feuille de présence doit
    // porter l'invité même si le client referme la connexion sans lire le
    // jeton.
    final userId = (query['userId'] ?? '').trim();
    onTicketIssued?.call(IssuedTicket(
      roomId: room.conference.id,
      identity: identity,
      displayName: displayName,
      userId: userId.isEmpty ? null : userId,
      issuedAt: DateTime.now(),
    ));

    return _json(request, HttpStatus.ok, {
      'token': token,
      'serverUrl': room.conference.effectiveServerUrl,
      'roomId': room.conference.id,
      'roomName': room.conference.name,
    });
  }

  /// Termine la réunion. Réservé à l'hôte : le jeton d'administration local
  /// est exigé, sinon n'importe qui sur le réseau pourrait couper la séance.
  Future<void> _end(HttpRequest request, String roomId) async {
    final room = _rooms[roomId];
    if (room == null) {
      return _json(
          request, HttpStatus.notFound, {'error': 'Réunion inconnue.'});
    }

    final provided = request.headers.value('x-host-token') ?? '';
    if (provided != room.conference.hostToken) {
      return _json(request, HttpStatus.forbidden, {
        'error': 'Seul l\'hôte peut terminer cette réunion.',
      });
    }

    _rooms.remove(roomId);
    return _json(request, HttpStatus.ok, {'status': 'ended', 'roomId': roomId});
  }

  bool _isThrottled(String address) {
    final attempts = _failedAttempts[address];
    if (attempts == null) return false;
    final cutoff = DateTime.now().subtract(const Duration(minutes: 1));
    attempts.removeWhere((attempt) => attempt.isBefore(cutoff));
    if (attempts.isEmpty) {
      _failedAttempts.remove(address);
      return false;
    }
    return attempts.length >= _maxAttemptsPerMinute;
  }

  void _recordFailure(String address) {
    _failedAttempts.putIfAbsent(address, () => []).add(DateTime.now());
  }

  /// Répond en JSON.
  ///
  /// L'en-tête CORS est nécessaire pour que le client web puisse interroger
  /// l'hôte directement depuis un navigateur. Il n'ouvre pas la réunion pour
  /// autant : le code reste exigé, et les échecs sont limités par adresse.
  Future<void> _json(
    HttpRequest request,
    int statusCode,
    Map<String, dynamic> body,
  ) async {
    request.response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json
      ..headers.set('Access-Control-Allow-Origin', '*')
      ..headers
          .set('Access-Control-Allow-Headers', 'Content-Type, X-Host-Token')
      ..headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.write(jsonEncode(body));
    await request.response.close();
  }
}

/// Une salle ouverte et les identifiants qui permettent d'en signer les jetons.
class _OpenRoom {
  final HostedConference conference;
  final ConferenceCredentials credentials;

  const _OpenRoom({required this.conference, required this.credentials});
}
