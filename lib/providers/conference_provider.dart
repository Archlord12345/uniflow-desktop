import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/appwrite_service.dart';
import '../services/conference/conference_client.dart';
import '../services/conference/conference_host_server.dart';
import '../services/conference/conference_host_state.dart';
import '../services/conference/conference_models.dart';
import '../services/conference/conference_network.dart';
import '../services/conference/conference_paths.dart';
import '../services/conference/conference_registry.dart';
import '../services/conference/livekit_server_process.dart';
import '../services/conference/livekit_token_service.dart';
import 'appwrite_provider.dart';
import 'attendance_provider.dart';

/// Annuaire des réunions publiées dans Appwrite.
final conferenceRegistryProvider = Provider<ConferenceRegistry>((ref) {
  final AppwriteService service = ref.watch(appwriteServiceProvider);
  return ConferenceRegistry(service);
});

/// Réunions en cours, telles qu'un participant peut les découvrir.
final activeConferencesProvider =
    FutureProvider<List<DiscoveredConference>>((ref) {
  return ref.watch(conferenceRegistryProvider).listActive();
});

/// Service de réunion hébergé par cette machine.
///
/// C'est le remplacement du backend : le poste qui crée la réunion lance son
/// propre serveur média et sa propre API de jonction, au lieu de dépendre
/// d'une machine centrale.
final conferenceHostProvider =
    NotifierProvider<ConferenceHostController, ConferenceHostState>(
  ConferenceHostController.new,
);

/// Pilote le cycle de vie du serveur de réunion embarqué.
///
/// Tient l'état affiché par l'écran « Conférences » et orchestre les quatre
/// pièces du service : le processus média, l'API de jonction, le forgeage des
/// jetons et l'annuaire Appwrite.
class ConferenceHostController extends Notifier<ConferenceHostState> {
  /// Ports par défaut. Ceux de LiveKit sont ceux de sa configuration
  /// habituelle ; celui de l'API de jonction est propre à UniFlow.
  static const int defaultMediaPort = 7880;
  static const int defaultRtcTcpPort = 7881;
  static const int defaultRtcUdpPort = 7882;
  static const int defaultJoinApiPort = 8090;

  LiveKitServerProcess? _process;
  ConferenceHostServer? _server;
  ConferenceCredentials? _credentials;
  String? _registryDocumentId;

  @override
  ConferenceHostState build() {
    // Le provider n'est pas `autoDispose` : changer de page ne doit pas couper
    // la réunion en cours — l'hôte reste l'hôte tant qu'il ne l'arrête pas.
    // L'arrêt n'a donc lieu qu'à la destruction du conteneur (fermeture de
    // l'application) : c'est le dernier moment où l'on peut encore tuer le
    // processus média plutôt que de le laisser orphelin.
    ref.onDispose(() {
      _server?.stop();
      _process?.stop();
    });
    return const ConferenceHostState();
  }

  /// Démarre le serveur média et ouvre une salle.
  ///
  /// Chaque étape peut échouer pour une raison distincte (binaire absent, pas
  /// de réseau, port occupé) : l'erreur remontée dit laquelle, pour que
  /// l'utilisateur sache quoi corriger.
  Future<bool> start({
    required String name,
    required String hostId,
    required String hostName,
    int maxParticipants = 50,
  }) async {
    if (state.isRunning || state.isBusy) return false;

    // Repartir d'un état vierge plutôt que de copier le précédent : après un
    // échec (binaire absent par exemple), les champs de la tentative
    // précédente — dont l'explication d'installation — ne doivent pas
    // survivre à une nouvelle tentative, sinon l'écran continuerait de les
    // afficher alors que la réunion tourne.
    state = const ConferenceHostState(status: HostState.starting);

    try {
      // 1. Le serveur média doit exister sur la machine.
      final executable = await LiveKitServerProcess.locateBinary();
      if (executable == null) {
        state = state.copyWith(
          status: HostState.unavailable,
          binaryHint: ConferenceHostState.installHint,
        );
        return false;
      }

      // 2. Une réunion se tient sur un réseau : sans adresse locale, aucun
      //    participant ne pourrait nous joindre.
      final localIp = await ConferenceNetwork.localIpAddress();
      if (localIp == null) {
        throw const ConferenceException(
          'Aucune adresse réseau locale n\'a pu être déterminée. Vérifiez que '
          'cette machine est connectée à un réseau.',
        );
      }

      // 3. Ports libres : l'API de jonction peut cohabiter avec un autre
      //    logiciel, on cherche le premier port disponible.
      final mediaPort = await ConferenceNetwork.findFreePort(defaultMediaPort);
      final rtcTcpPort =
          await ConferenceNetwork.findFreePort(defaultRtcTcpPort);
      final rtcUdpPort =
          await ConferenceNetwork.findFreePort(defaultRtcUdpPort);
      final joinPort = await ConferenceNetwork.findFreePort(defaultJoinApiPort);

      // 4. Identifiants et identité de la salle, générés localement.
      const generator = ConferenceSecretGenerator();
      final credentials = ConferenceCredentials(
        apiKey: generator.apiKey(),
        apiSecret: generator.apiSecret(),
      );
      final roomId = generator.roomId();

      // 5. Lancement du serveur média. Il postera ses événements (arrivées,
      //    départs) à l'API de jonction, sur la boucle locale : c'est la
      //    source de la feuille de présence.
      final process = LiveKitServerProcess();
      await process.start(
        executable: executable,
        credentials: credentials,
        apiPort: mediaPort,
        rtcTcpPort: rtcTcpPort,
        rtcUdpPort: rtcUdpPort,
        workingDirectory: conferenceHomeDirectory(),
        webhookUrl:
            'http://127.0.0.1:$joinPort${ConferenceHostServer.webhookPath}',
      );
      _process = process;

      // 6. Ouverture de l'API de jonction, qui signe les jetons et relaie à
      //    la feuille de présence les tickets délivrés et les webhooks.
      final attendance = ref.read(liveAttendanceProvider.notifier);
      final server = ConferenceHostServer(
        tokenService: const LiveKitTokenService(),
        onTicketIssued: attendance.recordTicket,
        onWebhookEvent: attendance.recordWebhook,
      );
      await server.start(port: joinPort);
      _server = server;

      final conference = HostedConference(
        id: roomId,
        name: name.trim().isEmpty ? 'Réunion sans titre' : name.trim(),
        code: generator.roomCode(),
        hostId: hostId,
        hostName: hostName,
        serverUrl: 'ws://$localIp:$mediaPort',
        apiUrl: 'http://$localIp:$joinPort',
        hostToken: generator.hostToken(),
        maxParticipants: maxParticipants,
        createdAt: DateTime.now(),
      );

      server.openRoom(conference: conference, credentials: credentials);
      _credentials = credentials;
      attendance.open(conference);

      // 7. Publication dans l'annuaire : c'est un confort pour les
      //    participants distants, pas une condition de fonctionnement. Un
      //    échec ici n'empêche pas la réunion de se tenir en local.
      _registryDocumentId =
          await ref.read(conferenceRegistryProvider).publish(conference);

      state = state.copyWith(
        status: HostState.running,
        conference: conference,
        localIp: localIp,
        apiPort: joinPort,
        mediaPort: mediaPort,
        published: _registryDocumentId != null,
        clearError: true,
      );
      return true;
    } on ConferenceException catch (error) {
      await _teardown();
      state = state.copyWith(status: HostState.failed, error: error.message);
      return false;
    } on Object catch (error) {
      await _teardown();
      state = state.copyWith(
        status: HostState.failed,
        error: 'Le service de réunion n\'a pas pu démarrer : $error',
      );
      return false;
    }
  }

  /// Termine la réunion et libère le processus média.
  Future<void> stop() async {
    final conference = state.conference;

    if (conference != null) {
      _server?.closeRoom(conference.id);
      final documentId = _registryDocumentId;
      if (documentId != null) {
        await ref.read(conferenceRegistryProvider).markEnded(documentId);
      }
    }

    await _teardown();
    _registryDocumentId = null;
    state = const ConferenceHostState();
  }

  /// Bascule la réunion en mode « internet » en publiant une adresse
  /// accessible depuis l'extérieur (tunnel, redirection de port).
  ///
  /// L'adresse locale reste valide : les participants déjà sur le réseau
  /// continuent de l'utiliser, rien n'est interrompu pour eux.
  Future<bool> enableInternetMode(String publicUrl) async {
    final conference = state.conference;
    final credentials = _credentials;
    if (conference == null || credentials == null) return false;

    final trimmed = publicUrl.trim();
    if (trimmed.isEmpty) return false;

    final updated = conference.copyWith(
      mode: ConferenceMode.internet,
      publicUrl: trimmed,
    );

    _server?.openRoom(conference: updated, credentials: credentials);

    final documentId = _registryDocumentId;
    if (documentId != null) {
      // Le document existant est remplacé plutôt que dupliqué : une même
      // réunion ne doit apparaître qu'une fois dans l'annuaire.
      await ref.read(conferenceRegistryProvider).markEnded(documentId);
    }
    _registryDocumentId =
        await ref.read(conferenceRegistryProvider).publish(updated);

    state = state.copyWith(
      conference: updated,
      published: _registryDocumentId != null,
    );
    return true;
  }

  /// Ticket de l'hôte pour entrer dans sa propre salle.
  ///
  /// Forgé localement avec les identifiants de la réunion : l'hôte n'a pas à
  /// passer par son propre code. Le serveur média est joint par la boucle
  /// locale plutôt que par l'adresse LAN : la réunion doit continuer pour
  /// l'hôte même si le Wi-Fi décroche, et rien ne transite alors par le
  /// réseau pour ses propres flux.
  ConferenceTicket? hostTicket({
    required String identity,
    required String displayName,
  }) {
    final conference = state.conference;
    final credentials = _credentials;
    final mediaPort = state.mediaPort;
    if (conference == null || credentials == null || mediaPort == null) {
      return null;
    }
    final token = const LiveKitTokenService().mint(
      apiKey: credentials.apiKey,
      apiSecret: credentials.apiSecret,
      roomName: conference.id,
      identity: identity,
      displayName: displayName,
      isHost: true,
    );
    return ConferenceTicket(
      token: token,
      serverUrl: 'ws://127.0.0.1:$mediaPort',
      roomId: conference.id,
      roomName: conference.name,
    );
  }

  /// Recharge le binaire et relance si nécessaire, après installation.
  Future<bool> retry({
    required String name,
    required String hostId,
    required String hostName,
  }) =>
      start(name: name, hostId: hostId, hostName: hostName);

  /// Vrai si le binaire du serveur média est présent sur la machine.
  Future<bool> isBinaryAvailable() => LiveKitServerProcess.isAvailable();

  /// Journal du serveur média, utile quand le démarrage échoue.
  List<String> get serverLog => _process?.log ?? const [];

  Future<void> _teardown() async {
    // La feuille se clôt avant que le serveur média s'arrête : les derniers
    // webhooks de départ ne viendront plus, ce sont les connexions encore
    // ouvertes qu'on ferme ici, à l'instant de l'arrêt.
    await ref.read(liveAttendanceProvider.notifier).close();
    await _server?.stop();
    _server = null;
    await _process?.stop();
    _process = null;
    _credentials = null;
  }
}
