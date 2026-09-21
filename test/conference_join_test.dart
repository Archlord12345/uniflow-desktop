// Parcours « rejoindre une réunion » : page navigateur servie par l'hôte,
// bundle client, recherche par code, client de bureau, liens d'invitation,
// choix de l'adresse LAN et logique pure de l'écran de salle.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:uniflow/services/conference/conference_client.dart';
import 'package:uniflow/services/conference/conference_host_server.dart';
import 'package:uniflow/services/conference/conference_join_page.dart';
import 'package:uniflow/services/conference/conference_models.dart';
import 'package:uniflow/services/conference/conference_network.dart';
import 'package:uniflow/services/conference/conference_room_model.dart';

const _credentials = ConferenceCredentials(
  apiKey: 'APItestkey0000000000000',
  apiSecret: 'secret-de-test-secret-de-test-32',
);

HostedConference _conference({
  String id = 'kf-0000abcd',
  String code = 'K7M2QP',
  ConferenceStatus status = ConferenceStatus.active,
}) =>
    HostedConference(
      id: id,
      name: 'Cours de Réseaux — L3',
      code: code,
      hostId: 'host-1',
      hostName: 'Pr. Fouda',
      serverUrl: 'ws://192.168.1.10:7880',
      apiUrl: 'http://192.168.1.10:8090',
      hostToken: 'host-token',
      status: status,
      createdAt: DateTime(2026, 9, 21, 8, 0),
    );

/// Faux bundle : les tests ne chargent pas le moteur Flutter, donc pas
/// `rootBundle`.
final Uint8List _fakeScript =
    Uint8List.fromList(utf8.encode('window.LivekitClient={fake:true};'));

void main() {
  group('Liens de participation', () {
    test('le lien participant porte l\'adresse de l\'API et le code', () {
      expect(_conference().participantLink,
          'http://192.168.1.10:8090/join/K7M2QP');
      expect(HostedConference.participantLinkFor('http://10.0.0.5:8090/', 'ab12cd'),
          'http://10.0.0.5:8090/join/AB12CD');
    });

    test('un lien complet donne l\'API et le code', () {
      final parsed =
          ConferenceInviteLink.parse('http://192.168.1.10:8090/join/k7m2qp');
      expect(parsed?.apiUrl, 'http://192.168.1.10:8090');
      expect(parsed?.code, 'K7M2QP');
    });

    test('une adresse dictée sans schéma est acceptée', () {
      final parsed = ConferenceInviteLink.parse('192.168.1.10:8090');
      expect(parsed?.apiUrl, 'http://192.168.1.10:8090');
      expect(parsed?.code, isNull);
    });

    test('le code peut venir d\'un paramètre de requête', () {
      final parsed =
          ConferenceInviteLink.parse('https://host.example/?code=zz99aa');
      expect(parsed?.apiUrl, 'https://host.example');
      expect(parsed?.code, 'ZZ99AA');
    });

    test('vide ou illisible → null', () {
      expect(ConferenceInviteLink.parse('   '), isNull);
      expect(ConferenceInviteLink.parse('ftp://x'), isNull);
      expect(ConferenceInviteLink.parse('://'), isNull);
    });
  });

  group('Page navigateur', () {
    test('la page pré-remplit le code et le titre de la réunion', () {
      final html = ConferenceJoinPage.render(
        roomId: 'kf-1',
        roomName: 'Cours de Réseaux — L3',
        code: 'K7M2QP',
        hostName: 'Pr. Fouda',
      );
      expect(html, contains('K7M2QP'));
      expect(html, contains('Cours de Réseaux'));
      expect(html, contains(ConferenceJoinPage.clientScriptPath));
    });

    test('un titre malveillant ne sort ni du <title> ni du JSON embarqué',
        () {
      final html = ConferenceJoinPage.render(
        roomId: 'kf-1',
        roomName: '</script><script>alert(1)</script>',
        code: 'K7M2QP',
      );
      expect(html, isNot(contains('<script>alert(1)</script>')));
      expect(html, contains('&lt;&#47;script&gt;'), reason: 'titre échappé');
      expect(html, contains(r'\u003c/script\u003e'),
          reason: 'JSON du <script> échappé');
    });
  });

  group('Serveur hôte : routes de participation', () {
    late ConferenceHostServer server;
    late String base;

    setUp(() async {
      server = ConferenceHostServer(
        assetLoader: (_) async => _fakeScript,
      );
      await server.start(port: 0);
      base = 'http://127.0.0.1:${server.port}';
      server.openRoom(conference: _conference(), credentials: _credentials);
    });

    tearDown(() => server.stop());

    Future<(int, HttpHeaders, String)> get(String path) async {
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse('$base$path'));
        final response = await request.close();
        final body = await utf8.decodeStream(response);
        return (response.statusCode, response.headers, body);
      } finally {
        client.close(force: true);
      }
    }

    test('GET / et GET /join/<CODE> servent la page HTML', () async {
      final (status, headers, body) = await get('/join/k7m2qp');
      expect(status, HttpStatus.ok);
      expect(headers.contentType?.mimeType, 'text/html');
      expect(headers.value(HttpHeaders.cacheControlHeader), 'no-store');
      expect(body, contains('K7M2QP'));
      expect(body, contains('Cours de Réseaux'));

      final (rootStatus, _, rootBody) = await get('/');
      expect(rootStatus, HttpStatus.ok);
      expect(rootBody, contains('<html'));
    });

    test('un code inconnu ouvre quand même la page (saisie à corriger)',
        () async {
      final (status, _, body) = await get('/join/NOPE00');
      expect(status, HttpStatus.ok);
      expect(body, contains('NOPE00'));
      expect(body, isNot(contains('Cours de Réseaux')));
    });

    test('le bundle client est servi une fois lu, en JavaScript, cacheable',
        () async {
      var loads = 0;
      final counting = ConferenceHostServer(
        assetLoader: (_) async {
          loads++;
          return _fakeScript;
        },
      );
      await counting.start(port: 0);
      try {
        final client = HttpClient();
        for (var i = 0; i < 2; i++) {
          final request = await client.getUrl(Uri.parse(
              'http://127.0.0.1:${counting.port}${ConferenceJoinPage.clientScriptPath}'));
          final response = await request.close();
          final body = await utf8.decodeStream(response);
          expect(response.statusCode, HttpStatus.ok);
          expect(response.headers.contentType?.mimeType,
              'application/javascript');
          expect(response.headers.value(HttpHeaders.cacheControlHeader),
              contains('max-age'));
          expect(body, 'window.LivekitClient={fake:true};');
        }
        client.close(force: true);
      } finally {
        await counting.stop();
      }
      expect(loads, 1, reason: 'le bundle est lu une seule fois');
    });

    test('un bundle introuvable répond 500 sans faire tomber le serveur',
        () async {
      final broken = ConferenceHostServer(
        assetLoader: (_) async => throw StateError('asset manquant'),
      );
      await broken.start(port: 0);
      try {
        final client = HttpClient();
        final request = await client.getUrl(Uri.parse(
            'http://127.0.0.1:${broken.port}${ConferenceJoinPage.clientScriptPath}'));
        final response = await request.close();
        expect(response.statusCode, HttpStatus.internalServerError);
        await utf8.decodeStream(response);
        final health = await (await client.getUrl(
                Uri.parse('http://127.0.0.1:${broken.port}/health')))
            .close();
        expect(health.statusCode, HttpStatus.ok);
        client.close(force: true);
      } finally {
        await broken.stop();
      }
    });

    test('GET /rooms/by-code/<CODE> retrouve la salle, insensible à la casse',
        () async {
      final (status, headers, body) = await get('/rooms/by-code/k7m2qp');
      expect(status, HttpStatus.ok);
      expect(headers.value('Access-Control-Allow-Origin'), '*');
      final json = jsonDecode(body) as Map<String, dynamic>;
      expect(json['roomId'], 'kf-0000abcd');
      expect(json['roomName'], 'Cours de Réseaux — L3');
      expect(json['hostName'], 'Pr. Fouda');
      expect(json['serverUrl'], 'ws://192.168.1.10:7880');
      expect(json.containsKey('token'), isFalse,
          reason: 'la recherche ne délivre pas de jeton');
    });

    test('un code inconnu → 404, et les échecs sont freinés', () async {
      for (var i = 0; i < 10; i++) {
        final (status, _, _) = await get('/rooms/by-code/WRONG$i');
        expect(status, HttpStatus.notFound);
      }
      final (throttled, _, _) = await get('/rooms/by-code/K7M2QP');
      expect(throttled, HttpStatus.tooManyRequests,
          reason: 'même le bon code est refusé après dix échecs en une minute');
    });

    test('une salle terminée n\'est plus trouvée par son code', () async {
      server.closeRoom('kf-0000abcd');
      server.openRoom(
        conference: _conference(status: ConferenceStatus.ended),
        credentials: _credentials,
      );
      final (status, _, _) = await get('/rooms/by-code/K7M2QP');
      expect(status, HttpStatus.notFound);
    });

    test('OPTIONS répond au pré-vol CORS', () async {
      final client = HttpClient();
      try {
        final request = await client.openUrl(
            'OPTIONS', Uri.parse('$base/rooms/by-code/K7M2QP'));
        final response = await request.close();
        expect(response.statusCode, HttpStatus.noContent);
        expect(response.headers.value('Access-Control-Allow-Origin'), '*');
        expect(response.headers.value('Access-Control-Allow-Methods'),
            contains('GET'));
        expect(response.headers.value('Access-Control-Allow-Headers'),
            contains('X-Host-Token'));
        await response.drain<void>();
      } finally {
        client.close(force: true);
      }
    });

    test('le client de bureau retrouve puis rejoint avec le code', () async {
      const client = ConferenceClient();
      final found = await client.lookup(apiUrl: base, code: 'k7m2qp');
      expect(found.roomId, 'kf-0000abcd');
      expect(found.roomName, 'Cours de Réseaux — L3');

      final ticket = await client.join(
        apiUrl: base,
        code: 'K7M2QP',
        identity: 'user-42',
        displayName: 'Awa Ndiaye',
        userId: 'user-42',
      );
      expect(ticket.serverUrl, 'ws://192.168.1.10:7880');
      expect(ticket.roomId, 'kf-0000abcd');
      expect(ticket.token.split('.'), hasLength(3), reason: 'JWT signé');
    });

    test('le client de bureau explique un code faux et un hôte injoignable',
        () async {
      const client = ConferenceClient(timeout: Duration(seconds: 2));
      await expectLater(
        client.lookup(apiUrl: base, code: 'ZZZZZZ'),
        throwsA(isA<ConferenceException>()),
      );
      // Port fermé : refus de connexion immédiat, message lisible.
      final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final deadPort = closed.port;
      await closed.close();
      await expectLater(
        client.lookup(apiUrl: 'http://127.0.0.1:$deadPort', code: 'K7M2QP'),
        throwsA(isA<ConferenceException>()),
      );
    });
  });

  group('Choix de l\'adresse LAN', () {
    test('le pont Docker passe derrière la carte physique', () {
      final ranked = ConferenceNetwork.rankAddresses(const [
        LocalAddress(interfaceName: 'docker0', address: '172.17.0.1'),
        LocalAddress(interfaceName: 'wlp3s0', address: '192.168.1.24'),
      ]);
      expect(ranked.first.address, '192.168.1.24');
    });

    test('bouclage et lien-local sont écartés', () {
      final ranked = ConferenceNetwork.rankAddresses(const [
        LocalAddress(interfaceName: 'lo', address: '127.0.0.1'),
        LocalAddress(interfaceName: 'eth0', address: '169.254.10.3'),
        LocalAddress(interfaceName: 'eth1', address: '0.0.0.0'),
        LocalAddress(interfaceName: 'eth2', address: '10.20.0.7'),
      ]);
      expect(ranked.map((a) => a.address), ['10.20.0.7']);
    });

    test('à rang égal, l\'ordre du système est conservé', () {
      final ranked = ConferenceNetwork.rankAddresses(const [
        LocalAddress(interfaceName: 'eth0', address: '192.168.0.2'),
        LocalAddress(interfaceName: 'wlan0', address: '192.168.1.2'),
      ]);
      expect(ranked.map((a) => a.address), ['192.168.0.2', '192.168.1.2']);
    });

    test('une adresse privée passe devant une publique ; VPN derrière', () {
      final ranked = ConferenceNetwork.rankAddresses(const [
        LocalAddress(interfaceName: 'tun0', address: '10.8.0.2'),
        LocalAddress(interfaceName: 'enp2s0', address: '41.202.1.9'),
        LocalAddress(interfaceName: 'br-1a2b', address: '172.18.0.1'),
        LocalAddress(interfaceName: 'Wi-Fi', address: '192.168.43.12'),
      ]);
      expect(ranked.map((a) => a.address),
          ['192.168.43.12', '41.202.1.9', '10.8.0.2', '172.18.0.1']);
    });

    test('les noms Windows (« vEthernet (WSL) ») sont reconnus virtuels', () {
      const wsl = LocalAddress(
          interfaceName: 'vEthernet (WSL)', address: '172.20.0.1');
      const wifi = LocalAddress(interfaceName: 'Wi-Fi', address: '192.168.1.5');
      expect(wsl.isVirtualInterface, isTrue);
      expect(wifi.isVirtualInterface, isFalse);
      expect(wifi.isWireless, isTrue);
    });
  });

  group('Écran de salle : logique pure', () {
    test('initiales sans les titres', () {
      expect(initialsOf('Pr. Jean Fouda'), 'JF');
      expect(initialsOf('awa'), 'A');
      expect(initialsOf('Dr.'), '?');
      expect(initialsOf(''), '?');
      expect(initialsOf('Élodie Ngo-Mbock'), 'ÉM');
    });

    test('libellé de vignette : nom ou identité, « (vous) » pour soi', () {
      const me = RoomTile(identity: 'u1', name: 'Awa', isLocal: true);
      const anon = RoomTile(identity: 'guest-7', name: '  ');
      expect(me.label, 'Awa (vous)');
      expect(anon.label, 'guest-7');
      expect(anon.initials, 'G7', reason: 'le tiret sépare deux mots');
    });

    test('la scène : épinglé d\'abord, sinon le partage d\'écran, sinon rien',
        () {
      const tiles = [
        RoomTile(identity: 'a', name: 'A'),
        RoomTile(identity: 'b', name: 'B', sharingScreen: true),
        RoomTile(identity: 'c', name: 'C'),
      ];
      expect(stageIdentity(tiles, pinned: 'c'), 'c');
      expect(stageIdentity(tiles, pinned: 'zz'), 'b',
          reason: 'un épinglé parti ne bloque pas la scène');
      expect(stageIdentity(tiles), 'b');
      expect(stageIdentity(const [RoomTile(identity: 'a', name: 'A')]), isNull);
    });

    test('colonnes de grille : lisibles et sans trou', () {
      expect(gridColumns(1, 1200), 1);
      expect(gridColumns(2, 1200), 2);
      expect(gridColumns(4, 1200), 2);
      expect(gridColumns(6, 1200), 3);
      expect(gridColumns(12, 1200), 4);
      expect(gridColumns(6, 500), 2, reason: 'largeur limitante : 500/220');
      expect(gridColumns(6, 200), 1);
    });

    test('ordre des vignettes : partage, qui parle, arrivée, soi en dernier',
        () {
      const tiles = [
        RoomTile(identity: 'me', name: 'Moi', isLocal: true, isSpeaking: true),
        RoomTile(identity: 'a', name: 'A'),
        RoomTile(identity: 'b', name: 'B', isSpeaking: true),
        RoomTile(identity: 'c', name: 'C', sharingScreen: true),
        RoomTile(identity: 'd', name: 'D'),
      ];
      expect(orderTiles(tiles).map((t) => t.identity),
          ['c', 'b', 'a', 'd', 'me']);
    });

    test('libellés : compteur et raisons de déconnexion', () {
      expect(participantCountLabel(0), '0 participant');
      expect(participantCountLabel(1), '1 participant');
      expect(participantCountLabel(4), '4 participants');
      expect(disconnectReasonLabel('ROOM_DELETED'), contains('terminé'));
      expect(disconnectReasonLabel('duplicateIdentity'), contains('autre appareil'));
      expect(disconnectReasonLabel('stateMismatch'), contains('perdue'));
      expect(disconnectReasonLabel(null), contains('interrompue'));
    });
  });
}
