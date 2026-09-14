import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Forge les jetons d'accès LiveKit (JWT HS256) directement dans
/// l'application.
///
/// C'est la pièce qui remplace le serveur central : le backend NestJS
/// utilisait `livekit-server-sdk` pour signer ces jetons avec la clé de la
/// réunion. Ici la clé est générée et conservée par la machine hôte, et la
/// signature se fait en Dart — un JWT HS256 n'est qu'un HMAC-SHA256 sur
/// l'en-tête et la charge utile, `package:crypto` suffit.
///
/// Le format des revendications est celui qu'attend `livekit-server` :
/// `video.room` désigne la salle, `video.roomJoin` autorise l'entrée, et
/// `video.roomAdmin` donne les droits d'administration à l'hôte.
class LiveKitTokenService {
  const LiveKitTokenService();

  /// Durée de validité par défaut d'un jeton (4 h), alignée sur ce que
  /// faisait le backend.
  static const Duration defaultTtl = Duration(hours: 4);

  /// Signe un jeton d'accès pour [roomName].
  ///
  /// [identity] doit être unique par participant : LiveKit refuse deux
  /// connexions simultanées portant la même identité.
  String mint({
    required String apiKey,
    required String apiSecret,
    required String roomName,
    required String identity,
    String? displayName,
    bool isHost = false,
    bool canPublish = true,
    bool canSubscribe = true,
    Duration ttl = defaultTtl,
  }) {
    final now = DateTime.now().toUtc();
    final expiresAt = now.add(ttl);

    final header = <String, dynamic>{'alg': 'HS256', 'typ': 'JWT'};
    final payload = <String, dynamic>{
      'iss': apiKey,
      'sub': identity,
      'jti': identity,
      'nbf': now.millisecondsSinceEpoch ~/ 1000,
      'exp': expiresAt.millisecondsSinceEpoch ~/ 1000,
      if (displayName != null && displayName.trim().isNotEmpty)
        'name': displayName.trim(),
      'video': <String, dynamic>{
        'room': roomName,
        'roomJoin': true,
        'canPublish': canPublish,
        'canSubscribe': canSubscribe,
        'canPublishData': true,
        'roomAdmin': isHost,
      },
    };

    final signingInput = '${_segment(header)}.${_segment(payload)}';
    final signature = Hmac(sha256, utf8.encode(apiSecret))
        .convert(utf8.encode(signingInput));

    return '$signingInput.${_base64Url(signature.bytes)}';
  }

  /// Encode un objet JSON en segment JWT : base64url, sans remplissage.
  static String _segment(Map<String, dynamic> value) =>
      _base64Url(utf8.encode(jsonEncode(value)));

  static String _base64Url(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');
}

/// Génère les identifiants d'une réunion et les codes courts qui vont avec.
///
/// Utilise [Random.secure] : ces valeurs protègent l'accès à la salle, un
/// générateur prévisible permettrait de deviner la clé d'une réunion.
class ConferenceSecretGenerator {
  const ConferenceSecretGenerator();

  static final Random _random = Random.secure();

  /// Alphabet sans caractères ambigus (ni O/0, ni I/1/l) : un code de réunion
  /// se recopie à la main ou se dicte à l'oral.
  static const String _codeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  /// Alphabet des clés LiveKit.
  static const String _keyAlphabet =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  /// Clé d'API LiveKit, préfixée `API` comme le fait `livekit-server`.
  String apiKey() => 'API${_string(20, _keyAlphabet)}';

  /// Secret de signature, 32 caractères alphanumériques.
  String apiSecret() => _string(32, _keyAlphabet);

  /// Code de réunion à 6 caractères, ex. « K7M2QP ».
  String roomCode() => _string(6, _codeAlphabet);

  /// Jeton d'administration local (protège l'arrêt de la réunion auprès de
  /// l'API embarquée).
  String hostToken() => _string(40, _keyAlphabet);

  /// Identifiant de salle, ex. « kf-3f9a2c81 ». Le préfixe évite qu'une salle
  /// créée ici entre en collision avec une salle d'une autre origine.
  String roomId() => 'kf-${_string(8, '0123456789abcdef')}';

  String _string(int length, String alphabet) {
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(alphabet[_random.nextInt(alphabet.length)]);
    }
    return buffer.toString();
  }
}
