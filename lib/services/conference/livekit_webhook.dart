/// Réception des webhooks de `livekit-server`.
///
/// Le serveur média est le seul à savoir précisément qui est connecté à la
/// salle et depuis quand : il le dit par des requêtes HTTP `POST` vers l'URL
/// déclarée dans sa configuration (`webhook.urls`). Ce fichier vérifie que
/// ces requêtes viennent bien de lui et en extrait ce qui intéresse la feuille
/// de présence — sans SDK serveur LiveKit, qui n'existe pas en Dart : la
/// signature n'est qu'un JWT HS256 dont une revendication porte l'empreinte
/// SHA-256 du corps, `package:crypto` suffit, comme pour les jetons d'accès.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Nature d'un événement de webhook.
enum LiveKitWebhookEventType {
  roomStarted('room_started'),
  roomFinished('room_finished'),
  participantJoined('participant_joined'),
  participantLeft('participant_left'),

  /// Tout ce qui ne concerne pas la présence (pistes publiées, egress…).
  other('');

  final String wireName;
  const LiveKitWebhookEventType(this.wireName);

  static LiveKitWebhookEventType parse(String? raw) {
    for (final type in values) {
      if (type != other && type.wireName == raw) return type;
    }
    return other;
  }
}

/// Un événement de webhook, réduit à ce que la feuille de présence consomme.
class LiveKitWebhookEvent {
  final LiveKitWebhookEventType type;

  /// Nom d'événement tel que reçu, pour le journal quand [type] est `other`.
  final String rawType;

  /// Nom de la salle LiveKit — l'identifiant de réunion d'UniFlow.
  final String? roomName;

  /// Identité du participant (le `sub` de son jeton), pour les événements
  /// `participant_*`.
  final String? participantIdentity;

  /// Nom affiché du participant (le `name` de son jeton), parfois vide.
  final String participantName;

  /// Horodatage de l'événement d'après le serveur média ; à défaut, l'instant
  /// de réception fourni par l'appelant.
  final DateTime createdAt;

  const LiveKitWebhookEvent({
    required this.type,
    required this.rawType,
    required this.roomName,
    required this.participantIdentity,
    required this.participantName,
    required this.createdAt,
  });

  bool get concernsParticipant =>
      (type == LiveKitWebhookEventType.participantJoined ||
          type == LiveKitWebhookEventType.participantLeft) &&
      (participantIdentity?.isNotEmpty ?? false);

  /// Lit un `WebhookEvent` encodé par `protojson`.
  ///
  /// `protojson` écrit les entiers 64 bits (`createdAt`, `joinedAt`) sous
  /// forme de **chaînes** : `"createdAt": "1758441600"`. Un lecteur qui
  /// n'attendrait qu'un nombre daterait tous les événements de l'instant de
  /// réception. Renvoie `null` si le corps n'est pas un événement.
  static LiveKitWebhookEvent? fromJson(Object? raw, {required DateTime now}) {
    if (raw is! Map) return null;
    final eventName = raw['event'];
    if (eventName is! String || eventName.isEmpty) return null;
    final room = raw['room'];
    final participant = raw['participant'];
    return LiveKitWebhookEvent(
      type: LiveKitWebhookEventType.parse(eventName),
      rawType: eventName,
      roomName: room is Map ? _string(room['name']) : null,
      participantIdentity:
          participant is Map ? _string(participant['identity']) : null,
      participantName:
          participant is Map ? (_string(participant['name']) ?? '') : '',
      createdAt: _epochSeconds(raw['createdAt']) ?? now,
    );
  }

  static String? _string(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static DateTime? _epochSeconds(Object? value) {
    final num? seconds = switch (value) {
      num n => n,
      String s => num.tryParse(s),
      _ => null,
    };
    if (seconds == null || seconds <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch((seconds * 1000).round())
        .toLocal();
  }
}

/// Vérifie l'en-tête `Authorization` d'un webhook LiveKit.
///
/// Le serveur média signe chaque envoi avec la clé d'API déclarée dans sa
/// configuration : un JWT HS256 dont `iss` est la clé et `sha256` l'empreinte
/// (base64 standard) du corps exact de la requête. Sans cette vérification,
/// n'importe quelle machine du réseau local pourrait « faire arriver » ou
/// « faire partir » un participant sur la feuille de présence — l'API de
/// jonction écoute sur toutes les interfaces.
class LiveKitWebhookVerifier {
  const LiveKitWebhookVerifier();

  /// Marge sur `exp` et `nbf` : le serveur média tourne sur la même machine,
  /// mais un jeton peut être livré après plusieurs tentatives.
  static const Duration clockTolerance = Duration(minutes: 5);

  /// Renvoie `null` si la requête est authentique, sinon la raison du refus
  /// (à journaliser, jamais à renvoyer en détail à l'émetteur).
  String? verify({
    required List<int> body,
    required String? authorization,
    required String apiKey,
    required String apiSecret,
    DateTime? now,
  }) {
    var token = (authorization ?? '').trim();
    if (token.isEmpty) return 'en-tête Authorization absent';
    // LiveKit envoie le jeton nu ; un mandataire peut le préfixer.
    if (token.toLowerCase().startsWith('bearer ')) token = token.substring(7);

    final parts = token.split('.');
    if (parts.length != 3) return 'jeton mal formé';

    final Map<String, dynamic> header;
    final Map<String, dynamic> claims;
    final List<int> signature;
    try {
      header = _decodeJson(parts[0]);
      claims = _decodeJson(parts[1]);
      signature = _decodeBase64Url(parts[2]);
    } on FormatException {
      return 'jeton illisible';
    }

    if (header['alg'] != 'HS256') return 'algorithme inattendu';

    final expected = Hmac(sha256, utf8.encode(apiSecret))
        .convert(utf8.encode('${parts[0]}.${parts[1]}'))
        .bytes;
    if (!_constantTimeEquals(expected, signature)) return 'signature invalide';

    if (claims['iss'] != apiKey) return 'clé d\'API inconnue';

    final digest = base64.encode(sha256.convert(body).bytes);
    if (claims['sha256'] != digest) return 'empreinte du corps différente';

    final instant = (now ?? DateTime.now()).toUtc();
    final exp = _epoch(claims['exp']);
    if (exp != null && instant.isAfter(exp.add(clockTolerance))) {
      return 'jeton expiré';
    }
    final nbf = _epoch(claims['nbf']);
    if (nbf != null && instant.isBefore(nbf.subtract(clockTolerance))) {
      return 'jeton pas encore valide';
    }
    return null;
  }

  static Map<String, dynamic> _decodeJson(String segment) {
    final decoded = jsonDecode(utf8.decode(_decodeBase64Url(segment)));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('segment JWT non objet');
    }
    return decoded;
  }

  /// Les segments JWT sont en base64url sans remplissage ; `base64Url.decode`
  /// exige le remplissage.
  static List<int> _decodeBase64Url(String segment) {
    final padding = (4 - segment.length % 4) % 4;
    return base64Url.decode(segment + '=' * padding);
  }

  static DateTime? _epoch(Object? value) {
    if (value is! num) return null;
    return DateTime.fromMillisecondsSinceEpoch((value * 1000).round(),
        isUtc: true);
  }

  /// Comparaison en temps constant : une comparaison qui s'arrête au premier
  /// octet différent laisse mesurer, octet par octet, la signature attendue.
  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
