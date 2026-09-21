import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'conference_models.dart';

/// Pilote le processus `livekit-server` qui sert les flux audio/vidéo.
///
/// C'est le cœur du « service serveur embarqué » : le poste de l'enseignant
/// fait tourner le serveur média lui-même, il n'y a plus de machine centrale.
/// Cette classe se charge de trouver le binaire, d'écrire sa configuration,
/// de le lancer et de l'arrêter proprement.
///
/// La configuration est écrite en YAML à la main plutôt qu'avec un paquet
/// dédié : le fichier attendu par `livekit-server` tient en une quinzaine de
/// lignes, ajouter une dépendance pour cela n'apporterait rien.
class LiveKitServerProcess {
  Process? _process;
  File? _configFile;

  /// Dernières lignes écrites par le serveur, conservées pour diagnostiquer
  /// un démarrage qui échoue (port occupé, binaire incompatible…).
  final List<String> _log = [];
  static const int _maxLogLines = 200;

  /// Résout le chemin du binaire `livekit-server`.
  ///
  /// Ordre de recherche : la variable `LIVEKIT_SERVER_PATH` de `.env` (qui
  /// reste prioritaire et permet d'épingler une version précise), puis les
  /// emplacements d'installation habituels, puis le `PATH` du système.
  ///
  /// Renvoie `null` si rien n'est trouvé : l'écran doit alors expliquer quoi
  /// installer, pas échouer silencieusement.
  static Future<String?> locateBinary() async {
    final configured = dotenv.maybeGet('LIVEKIT_SERVER_PATH')?.trim();
    if (configured != null && configured.isNotEmpty) {
      if (await File(configured).exists()) return configured;
    }

    final candidates = <String>[
      if (Platform.environment['HOME'] != null) ...[
        '${Platform.environment['HOME']}/.local/bin/livekit-server',
        '${Platform.environment['HOME']}/bin/livekit-server',
      ],
      '/usr/local/bin/livekit-server',
      '/usr/bin/livekit-server',
      '/opt/livekit/livekit-server',
      r'C:\Program Files\LiveKit\livekit-server.exe',
    ];
    for (final candidate in candidates) {
      if (await File(candidate).exists()) return candidate;
    }

    // Dernier recours : le PATH. `which` n'existe pas sur Windows, `where` n'y
    // répond pas avec le même format — on tente les deux.
    final which = Platform.isWindows ? 'where' : 'which';
    try {
      final result = await Process.run(which, ['livekit-server']);
      if (result.exitCode == 0) {
        final path = (result.stdout as String)
            .split('\n')
            .map((line) => line.trim())
            .firstWhere((line) => line.isNotEmpty, orElse: () => '');
        if (path.isNotEmpty && await File(path).exists()) return path;
      }
    } on ProcessException {
      // `which`/`where` absent : on considère simplement que le binaire ne
      // peut pas être localisé par ce moyen.
    }

    return null;
  }

  /// Vrai si le binaire est présent sur la machine.
  static Future<bool> isAvailable() async => (await locateBinary()) != null;

  bool get isRunning => _process != null;

  /// Journal du serveur, du plus ancien au plus récent.
  List<String> get log => List.unmodifiable(_log);

  /// Écrit la configuration, lance le serveur et attend qu'il écoute.
  ///
  /// [apiPort] est le port de signalisation (WebSocket) ; [rtcTcpPort] et
  /// [rtcUdpPort] transportent les médias. Lève une [ConferenceException]
  /// explicite si le binaire ne démarre pas.
  Future<void> start({
    required String executable,
    required ConferenceCredentials credentials,
    required int apiPort,
    required int rtcTcpPort,
    required int rtcUdpPort,
    required String workingDirectory,
    String? webhookUrl,
  }) async {
    if (_process != null) {
      throw const ConferenceException('Le serveur média tourne déjà.');
    }

    final directory = Directory(workingDirectory);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final configFile = File('$workingDirectory/livekit.yaml');
    await configFile.writeAsString(
      buildConfig(
        credentials: credentials,
        apiPort: apiPort,
        rtcTcpPort: rtcTcpPort,
        rtcUdpPort: rtcUdpPort,
        webhookUrl: webhookUrl,
      ),
    );
    _configFile = configFile;

    final Process process;
    try {
      process = await Process.start(
        executable,
        ['--config', configFile.path],
        workingDirectory: workingDirectory,
      );
    } on ProcessException catch (error) {
      throw ConferenceException(
        'Impossible de lancer « $executable » : ${error.message}',
      );
    }

    _process = process;
    _log.clear();

    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_appendLog);
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => _appendLog('! $line'));

    // Si le serveur se termine tout seul, on lâche la référence pour que
    // `isRunning` redevienne faux et que l'écran puisse le signaler.
    unawaited(process.exitCode.then((code) {
      _appendLog('— serveur arrêté (code $code)');
      _process = null;
    }));

    final ready = await _waitUntilListening(apiPort);
    if (!ready) {
      final detail = _log.isEmpty ? '' : ' Dernier message : ${_log.last}';
      await stop();
      throw ConferenceException(
        'Le serveur média n\'a pas ouvert le port $apiPort à temps.$detail',
      );
    }
  }

  /// Arrête le serveur : SIGTERM, puis SIGKILL s'il ne répond pas.
  Future<void> stop() async {
    final process = _process;
    if (process == null) return;

    process.kill(ProcessSignal.sigterm);
    try {
      await process.exitCode.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      await process.exitCode;
    }
    _process = null;
  }

  /// Configuration YAML de `livekit-server`.
  ///
  /// `auto_create` évite d'avoir à déclarer chaque salle à l'avance : l'hôte
  /// en ouvre une nouvelle à chaque réunion. La plage UDP est restreinte pour
  /// rester ouverte sur un pare-feu de poste de travail.
  ///
  /// [webhookUrl] fait poster au serveur média ses événements (arrivées,
  /// départs) à l'API de jonction, signés avec la clé de la réunion : c'est
  /// ce qui alimente la feuille de présence. Sans lui, la feuille ne
  /// connaîtrait que les tickets délivrés, jamais les connexions réelles.
  static String buildConfig({
    required ConferenceCredentials credentials,
    required int apiPort,
    required int rtcTcpPort,
    required int rtcUdpPort,
    String? webhookUrl,
  }) {
    final webhook = webhookUrl == null || webhookUrl.isEmpty
        ? ''
        : '''
webhook:
  api_key: ${credentials.apiKey}
  urls:
    - $webhookUrl
''';
    return '''
# Généré par UniFlow — serveur média embarqué.
port: $apiPort
rtc:
  tcp_port: $rtcTcpPort
  udp_port: $rtcUdpPort
  use_external_ip: false
keys:
  ${credentials.apiKey}: ${credentials.apiSecret}
room:
  auto_create: true
  empty_timeout: 300
  departure_timeout: 20
turn:
  enabled: false
${webhook}logging:
  level: info
''';
  }

  /// Attend que le port de signalisation réponde, jusqu'à 20 secondes.
  Future<bool> _waitUntilListening(int port) async {
    for (var attempt = 0; attempt < 40; attempt++) {
      if (_process == null) return false;
      if (await _canConnect(port)) return true;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return false;
  }

  Future<bool> _canConnect(int port) async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: const Duration(milliseconds: 400),
      );
      return true;
    } on SocketException {
      return false;
    } finally {
      // `Socket.destroy()` renvoie `void` : l'`await` produisait
      // « use_of_void_result » et empêchait la compilation.
      socket?.destroy();
    }
  }

  void _appendLog(String line) {
    _log.add(line);
    if (_log.length > _maxLogLines) _log.removeAt(0);
  }

  /// Chemin du fichier de configuration écrit au dernier démarrage.
  String? get configPath => _configFile?.path;
}
