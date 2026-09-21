// Vérification EN DIRECT de l'hébergement d'une réunion, avec le vrai
// `livekit-server` installé sur le poste : c'est le seul moyen de savoir que
// le jeton signé par l'API de jonction est accepté par le serveur média, et
// que la page navigateur servie par l'hôte est complète.
//
// Enchaîne ce que fait « Créer une réunion » : ports libres, identifiants,
// lancement du serveur média, API de jonction, ouverture de la salle ; puis
// ce que fait un participant : recherche par code, ticket, validation du
// jeton par le serveur média (`GET /rtc/validate`, l'appel que fait le
// client LiveKit avant d'ouvrir le WebSocket), page `/join/CODE` et bundle.
//
//   flutter test test_live/conference_host_live_test.dart
//
// Sans `livekit-server` dans le PATH (ou aux emplacements connus de
// l'application), le test est ignoré, pas échoué : la suite principale
// reste indépendante de l'installation.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uniflow/services/conference/conference_client.dart';
import 'package:uniflow/services/conference/conference_host_server.dart';
import 'package:uniflow/services/conference/conference_join_page.dart';
import 'package:uniflow/services/conference/conference_models.dart';
import 'package:uniflow/services/conference/conference_network.dart';
import 'package:uniflow/services/conference/livekit_server_process.dart';
import 'package:uniflow/services/conference/livekit_token_service.dart';

Future<String> _body(HttpClientResponse response) =>
    utf8.decodeStream(response);

void main() async {
  final executable = await LiveKitServerProcess.locateBinary();

  test(
    'créer puis rejoindre une réunion, de bout en bout, sur ce poste',
    () async {
      final workDir = await Directory.systemTemp.createTemp('uniflow-visio-');
      final process = LiveKitServerProcess();
      final server = ConferenceHostServer(
        assetLoader: (path) async => File(path).readAsBytes(),
      );
      final issued = <IssuedTicket>[];
      server.onTicketIssued = issued.add;

      try {
        // --- Côté hôte : ce que fait ConferenceHostController.start ---
        final localIp = await ConferenceNetwork.localIpAddress();
        expect(localIp, isNotNull,
            reason: 'le poste doit avoir une adresse LAN pour héberger');
        expect(localIp, isNot(startsWith('127.')));
        expect(localIp, isNot(startsWith('172.17.')),
            reason: 'le pont Docker ne doit jamais être annoncé');

        final mediaPort = await ConferenceNetwork.findFreePort(17880);
        final rtcTcp = await ConferenceNetwork.findFreePort(17881);
        final rtcUdp = await ConferenceNetwork.findFreePort(17882);
        final joinPort = await ConferenceNetwork.findFreePort(18090);

        const generator = ConferenceSecretGenerator();
        final credentials = ConferenceCredentials(
          apiKey: generator.apiKey(),
          apiSecret: generator.apiSecret(),
        );

        await process.start(
          executable: executable!,
          credentials: credentials,
          apiPort: mediaPort,
          rtcTcpPort: rtcTcp,
          rtcUdpPort: rtcUdp,
          workingDirectory: workDir.path,
          webhookUrl:
              'http://127.0.0.1:$joinPort${ConferenceHostServer.webhookPath}',
        );
        expect(process.isRunning, isTrue);

        await server.start(port: joinPort);
        final conference = HostedConference(
          id: generator.roomId(),
          name: 'Réunion de vérification',
          code: generator.roomCode(),
          hostId: 'host-live',
          hostName: 'Hôte du test',
          serverUrl: 'ws://$localIp:$mediaPort',
          apiUrl: 'http://$localIp:$joinPort',
          hostToken: generator.hostToken(),
          createdAt: DateTime.now(),
        );
        server.openRoom(conference: conference, credentials: credentials);

        // Le lien participant porte bien l'adresse LAN de ce poste.
        expect(conference.participantLink,
            'http://$localIp:$joinPort/join/${conference.code}');

        // --- Côté participant : ce que fait « Rejoindre » ---
        const client = ConferenceClient();
        final found = await client.lookup(
            apiUrl: conference.apiUrl, code: conference.code);
        expect(found.roomId, conference.id);

        final ticket = await client.join(
          apiUrl: conference.apiUrl,
          code: conference.code.toLowerCase(),
          identity: 'participant-live',
          displayName: 'Participant du test',
          userId: 'participant-live',
        );
        expect(ticket.serverUrl, conference.serverUrl);
        expect(issued.map((t) => t.identity), contains('participant-live'),
            reason: 'la feuille de présence apprend le ticket');

        // Le serveur média accepte le jeton signé par l'API de jonction :
        // c'est exactement ce que le client LiveKit vérifie avant d'ouvrir
        // le WebSocket. Un secret ou une salle qui divergeraient répondraient
        // 401 ici, et la salle resterait « Connexion… » pour toujours.
        final http = HttpClient();
        try {
          final validate = await (await http.getUrl(Uri.parse(
                  'http://127.0.0.1:$mediaPort/rtc/validate?access_token=${ticket.token}')))
              .close();
          final validateBody = await _body(validate);
          expect(validate.statusCode, HttpStatus.ok,
              reason: 'livekit-server a refusé le jeton : $validateBody');
          expect(validateBody.toLowerCase(), contains('success'));

          // Le même contrôle pour le jeton de l'hôte (droits d'administration).
          final hostToken = const LiveKitTokenService().mint(
            apiKey: credentials.apiKey,
            apiSecret: credentials.apiSecret,
            roomName: conference.id,
            identity: 'host-live',
            displayName: 'Hôte du test',
            isHost: true,
          );
          final validateHost = await (await http.getUrl(Uri.parse(
                  'http://127.0.0.1:$mediaPort/rtc/validate?access_token=$hostToken')))
              .close();
          expect(validateHost.statusCode, HttpStatus.ok,
              reason: await _body(validateHost));

          // Un jeton signé avec un autre secret est bien refusé.
          final forged = const LiveKitTokenService().mint(
            apiKey: credentials.apiKey,
            apiSecret: 'mauvais-secret-mauvais-secret-32',
            roomName: conference.id,
            identity: 'intrus',
          );
          final validateForged = await (await http.getUrl(Uri.parse(
                  'http://127.0.0.1:$mediaPort/rtc/validate?access_token=$forged')))
              .close();
          await _body(validateForged);
          expect(validateForged.statusCode, HttpStatus.unauthorized);

          // La page navigateur et le bundle, tels que les recevra un
          // téléphone du réseau.
          final page =
              await (await http.getUrl(Uri.parse(conference.participantLink)))
                  .close();
          final pageBody = await _body(page);
          expect(page.statusCode, HttpStatus.ok);
          expect(pageBody, contains(conference.code));
          expect(pageBody, contains('Réunion de vérification'));

          final bundle = await (await http.getUrl(Uri.parse(
                  '${conference.apiUrl}${ConferenceJoinPage.clientScriptPath}')))
              .close();
          final bundleBody = await _body(bundle);
          expect(bundle.statusCode, HttpStatus.ok,
              reason: 'bundle livekit-client introuvable : $bundleBody');
          expect(bundleBody.length, greaterThan(100 * 1024));
          expect(bundleBody, contains('LivekitClient'));
        } finally {
          http.close(force: true);
        }
      } finally {
        await server.stop();
        await process.stop();
        await workDir.delete(recursive: true);
      }
    },
    skip: executable == null
        ? 'livekit-server absent : installez-le (voir docs/) pour ce test'
        : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
