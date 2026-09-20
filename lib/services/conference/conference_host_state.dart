import 'conference_models.dart';

/// Instantané de l'état du service de réunion hébergé par cette machine.
///
/// Immuable : l'interface se reconstruit à partir d'une nouvelle instance,
/// ce qui évite qu'un écran affiche un mélange de deux états (par exemple un
/// statut « en écoute » avec l'adresse de la réunion précédente).
class ConferenceHostState {
  final HostState status;

  /// Réunion en cours, `null` tant qu'aucune n'a été ouverte.
  final HostedConference? conference;

  /// Adresse locale détectée pour cette machine.
  final String? localIp;

  /// Port d'écoute de l'API de jonction.
  final int? apiPort;

  /// Port de signalisation LiveKit.
  final int? mediaPort;

  /// Message d'erreur affichable, `null` en l'absence de problème.
  final String? error;

  /// Vrai si la réunion a été publiée dans l'annuaire Appwrite.
  final bool published;

  /// Explication à montrer quand le binaire du serveur média est absent.
  final String? binaryHint;

  const ConferenceHostState({
    this.status = HostState.stopped,
    this.conference,
    this.localIp,
    this.apiPort,
    this.mediaPort,
    this.error,
    this.published = false,
    this.binaryHint,
  });

  /// Vrai quand le service accepte des participants.
  bool get isRunning => status == HostState.running && conference != null;

  /// Vrai pendant une transition (démarrage ou arrêt).
  bool get isBusy => status == HostState.starting;

  /// Adresse complète de l'API de jonction, affichable et copiable.
  String? get apiAddress {
    final ip = localIp;
    final port = apiPort;
    if (ip == null || port == null) return null;
    return 'http://$ip:$port';
  }

  /// Adresse du serveur média, telle qu'un participant du réseau local doit
  /// la saisir.
  String? get mediaAddress {
    final ip = localIp;
    final port = mediaPort;
    if (ip == null || port == null) return null;
    return 'ws://$ip:$port';
  }

  ConferenceHostState copyWith({
    HostState? status,
    HostedConference? conference,
    String? localIp,
    int? apiPort,
    int? mediaPort,
    String? error,
    bool? published,
    String? binaryHint,
    bool clearError = false,
    bool clearConference = false,
  }) {
    return ConferenceHostState(
      status: status ?? this.status,
      conference: clearConference ? null : (conference ?? this.conference),
      localIp: localIp ?? this.localIp,
      apiPort: apiPort ?? this.apiPort,
      mediaPort: mediaPort ?? this.mediaPort,
      error: clearError ? null : (error ?? this.error),
      published: published ?? this.published,
      binaryHint: binaryHint ?? this.binaryHint,
    );
  }

  /// Message indiquant à l'utilisateur comment installer le serveur média.
  static const String installHint =
      'Le serveur média « livekit-server » est introuvable sur cette machine.\n\n'
      'Ubuntu / Debian :\n'
      'curl -sSL https://get.livekit.io | bash\n\n'
      'Puis indiquez son chemin dans .env :\n'
      'LIVEKIT_SERVER_PATH=/usr/local/bin/livekit-server\n\n'
      'Sans ce binaire, l\'application ne peut pas servir les flux audio et '
      'vidéo ; tout le reste de la plateforme continue de fonctionner.';
}
