/// Modèles du service de visioconférence embarqué.
///
/// Ces objets ne viennent pas d'Appwrite : ils décrivent l'état local du
/// serveur de réunion que l'application desktop héberge elle-même. Le registre
/// Appwrite (collection `conference_rooms`) n'est qu'un annuaire facultatif,
/// utilisé pour qu'un participant distant retrouve l'hôte.
library;

/// Origine réseau d'une réunion.
enum ConferenceMode {
  /// Les participants sont sur le même réseau local que l'hôte.
  lan('LAN'),

  /// L'hôte expose en plus une adresse publique (tunnel, redirection de port).
  internet('INTERNET');

  final String label;
  const ConferenceMode(this.label);
}

/// Cycle de vie d'une réunion.
enum ConferenceStatus {
  active('En cours'),
  ended('Terminée');

  final String label;
  const ConferenceStatus(this.label);
}

/// État du processus serveur sur la machine hôte.
enum HostState {
  /// Rien n'est démarré.
  stopped('Arrêté'),

  /// Le binaire est en cours de lancement, la réunion n'accepte pas encore
  /// de participants.
  starting('Démarrage…'),

  /// Le serveur écoute et l'API de jonction répond.
  running('En écoute'),

  /// Le binaire est introuvable sur la machine.
  unavailable('Binaire absent'),

  /// Le lancement ou l'exécution a échoué.
  failed('Échec');

  final String label;
  const HostState(this.label);
}

/// Couple de clés LiveKit d'une réunion.
///
/// Généré localement par l'hôte : il n'y a plus de serveur central pour les
/// distribuer. Le secret ne quitte jamais la machine hôte — il signe les
/// jetons d'accès et n'est ni publié dans le registre, ni transmis aux
/// participants.
class ConferenceCredentials {
  final String apiKey;
  final String apiSecret;

  const ConferenceCredentials({required this.apiKey, required this.apiSecret});
}

/// Une réunion hébergée par cette machine.
class HostedConference {
  /// Identifiant technique, également utilisé comme nom de salle LiveKit.
  final String id;

  /// Titre affiché (« Cours de Réseaux — L3 »).
  final String name;

  /// Code court à communiquer aux participants. Il est exigé par l'API de
  /// jonction : connaître l'adresse de l'hôte ne suffit pas à entrer.
  final String code;

  /// Identifiant du compte Appwrite de l'hôte.
  final String hostId;
  final String hostName;

  /// Adresse WebSocket du serveur média, vue depuis le réseau local.
  final String serverUrl;

  /// Racine de l'API de jonction embarquée, vue depuis le réseau local.
  final String apiUrl;

  /// Adresse publique du serveur média, si l'hôte en expose une.
  final String? publicUrl;

  final ConferenceMode mode;
  final ConferenceStatus status;
  final int maxParticipants;
  final DateTime createdAt;
  final DateTime? endedAt;

  /// Jeton d'administration local, exigé pour terminer la réunion. Il reste
  /// sur la machine hôte et n'est pas publié dans le registre.
  final String hostToken;

  const HostedConference({
    required this.id,
    required this.name,
    required this.code,
    required this.hostId,
    required this.hostName,
    required this.serverUrl,
    required this.apiUrl,
    required this.hostToken,
    this.publicUrl,
    this.mode = ConferenceMode.lan,
    this.status = ConferenceStatus.active,
    this.maxParticipants = 50,
    required this.createdAt,
    this.endedAt,
  });

  /// Adresse que les participants doivent réellement utiliser : l'adresse
  /// publique si elle existe, l'adresse locale sinon.
  String get effectiveServerUrl =>
      (mode == ConferenceMode.internet && (publicUrl?.isNotEmpty ?? false))
          ? publicUrl!
          : serverUrl;

  /// Ce qu'un participant doit saisir pour rejoindre : le code de la réunion.
  /// L'adresse de l'API est publiée dans le registre, pas recopiée à la main.
  String get joinHint => 'Code : $code';

  /// Lien à diffuser aux participants sans application : la page de
  /// participation servie par ce poste, sur son adresse du réseau local, le
  /// code déjà dans l'adresse pour qu'un QR suffise.
  String get participantLink => participantLinkFor(apiUrl, code);

  /// Construit le lien de participation à partir de la racine de l'API.
  static String participantLinkFor(String apiUrl, String code) {
    final base =
        apiUrl.endsWith('/') ? apiUrl.substring(0, apiUrl.length - 1) : apiUrl;
    return '$base/join/${code.toUpperCase()}';
  }

  HostedConference copyWith({
    ConferenceStatus? status,
    ConferenceMode? mode,
    String? publicUrl,
    DateTime? endedAt,
  }) {
    return HostedConference(
      id: id,
      name: name,
      code: code,
      hostId: hostId,
      hostName: hostName,
      serverUrl: serverUrl,
      apiUrl: apiUrl,
      hostToken: hostToken,
      publicUrl: publicUrl ?? this.publicUrl,
      mode: mode ?? this.mode,
      status: status ?? this.status,
      maxParticipants: maxParticipants,
      createdAt: createdAt,
      endedAt: endedAt ?? this.endedAt,
    );
  }

  /// Représentation publiée dans le registre Appwrite : ni le secret, ni le
  /// jeton d'administration n'y figurent.
  Map<String, dynamic> toRegistryPayload() => {
        'roomId': id,
        'name': name,
        'code': code,
        'hostId': hostId,
        'hostName': hostName,
        'apiUrl': apiUrl,
        'serverUrl': effectiveServerUrl,
        'mode': mode.name.toUpperCase(),
        'status': status.name.toUpperCase(),
        'maxParticipants': maxParticipants,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// Une réunion trouvée dans le registre, telle qu'un participant la voit.
class DiscoveredConference {
  final String documentId;
  final String roomId;
  final String name;
  final String hostName;
  final String apiUrl;
  final String serverUrl;
  final ConferenceMode mode;
  final ConferenceStatus status;
  final int maxParticipants;
  final DateTime? createdAt;

  const DiscoveredConference({
    required this.documentId,
    required this.roomId,
    required this.name,
    required this.hostName,
    required this.apiUrl,
    required this.serverUrl,
    required this.mode,
    required this.status,
    required this.maxParticipants,
    this.createdAt,
  });

  static ConferenceMode _mode(String? raw) =>
      (raw ?? '').toUpperCase() == 'INTERNET'
          ? ConferenceMode.internet
          : ConferenceMode.lan;

  static ConferenceStatus _status(String? raw) =>
      (raw ?? '').toUpperCase() == 'ENDED'
          ? ConferenceStatus.ended
          : ConferenceStatus.active;

  /// Construit depuis un document Appwrite. Tolérant : le registre peut avoir
  /// été écrit par une version antérieure du schéma.
  factory DiscoveredConference.fromData(
    String documentId,
    Map<String, dynamic> data,
  ) {
    return DiscoveredConference(
      documentId: documentId,
      roomId: (data['roomId'] ?? documentId).toString(),
      name: (data['name'] ?? 'Réunion').toString(),
      hostName: (data['hostName'] ?? '').toString(),
      apiUrl: (data['apiUrl'] ?? '').toString(),
      serverUrl: (data['serverUrl'] ?? '').toString(),
      mode: _mode(data['mode']?.toString()),
      status: _status(data['status']?.toString()),
      maxParticipants: (data['maxParticipants'] as num?)?.toInt() ?? 50,
      createdAt: DateTime.tryParse((data['createdAt'] ?? '').toString()),
    );
  }
}

/// Ce qu'un participant recopie pour rejoindre : la racine de l'API de
/// l'hôte et le code de la réunion.
///
/// Accepte le lien de participation entier (`http://192.168.1.20:8090/join/AB12CD`),
/// une racine nue (`http://192.168.1.20:8090`, avec le code à part) ou même
/// `192.168.1.20:8090` sans schéma — c'est ce qu'on dicte à l'oral.
class ConferenceInviteLink {
  final String apiUrl;
  final String? code;

  const ConferenceInviteLink({required this.apiUrl, this.code});

  static ConferenceInviteLink? parse(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return null;
    if (!text.contains('://')) text = 'http://$text';
    final uri = Uri.tryParse(text);
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;

    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    String? code;
    if (segments.length >= 2 && segments[segments.length - 2] == 'join') {
      code = segments.last.toUpperCase();
    } else if (uri.queryParameters['code'] != null) {
      code = uri.queryParameters['code']!.trim().toUpperCase();
    }
    final port = uri.hasPort ? ':${uri.port}' : '';
    return ConferenceInviteLink(
      apiUrl: '${uri.scheme}://${uri.host}$port',
      code: (code == null || code.isEmpty) ? null : code,
    );
  }
}

/// Réponse de l'API de jonction de l'hôte.
class JoinTicket {
  final String token;
  final String serverUrl;
  final String roomName;
  final String roomId;

  const JoinTicket({
    required this.token,
    required this.serverUrl,
    required this.roomName,
    required this.roomId,
  });

  factory JoinTicket.fromJson(Map<String, dynamic> json) => JoinTicket(
        token: (json['token'] ?? '').toString(),
        serverUrl: (json['serverUrl'] ?? '').toString(),
        roomName: (json['roomName'] ?? '').toString(),
        roomId: (json['roomId'] ?? '').toString(),
      );
}

/// Un ticket de jonction que l'API de l'hôte vient de délivrer.
///
/// C'est la première trace d'un participant sur la feuille de présence : s'il
/// ne se connecte jamais au serveur média ensuite, il y restera comme invité
/// absent. [userId] est l'identifiant Appwrite que le client a déclaré ; il
/// n'est pas vérifié par l'hôte (aucun serveur central ne le pourrait hors
/// ligne), il sert à rapprocher la feuille des comptes de la plateforme.
class IssuedTicket {
  final String roomId;
  final String identity;
  final String displayName;
  final String? userId;
  final DateTime issuedAt;

  const IssuedTicket({
    required this.roomId,
    required this.identity,
    this.displayName = '',
    this.userId,
    required this.issuedAt,
  });
}

/// Erreur métier du service de visioconférence, porteuse d'un message
/// directement affichable.
class ConferenceException implements Exception {
  final String message;

  const ConferenceException(this.message);

  @override
  String toString() => message;
}
