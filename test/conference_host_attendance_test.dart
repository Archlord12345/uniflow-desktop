// Alimentation de la feuille de présence : webhooks du serveur média
// (signature, format protojson), tickets de l'API de jonction, contrôleur.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniflow/providers/attendance_provider.dart';
import 'package:uniflow/services/conference/attendance_store.dart';
import 'package:uniflow/services/conference/conference_attendance.dart';
import 'package:uniflow/services/conference/conference_host_server.dart';
import 'package:uniflow/services/conference/conference_models.dart';
import 'package:uniflow/services/conference/livekit_server_process.dart';
import 'package:uniflow/services/conference/livekit_webhook.dart';

const _apiKey = 'APItestkey0000000000000';
const _apiSecret = 'secret-de-test-secret-de-test-32';
const _credentials =
    ConferenceCredentials(apiKey: _apiKey, apiSecret: _apiSecret);

HostedConference _conference({String id = 'kf-0000abcd'}) => HostedConference(
      id: id,
      name: 'Cours de Réseaux — L3',
      code: 'K7M2QP',
      hostId: 'host-1',
      hostName: 'Pr. Fouda',
      serverUrl: 'ws://192.168.1.10:7880',
      apiUrl: 'http://192.168.1.10:8090',
      hostToken: 'host-token',
      createdAt: DateTime(2026, 9, 21, 8, 0),
    );

String _base64Url(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

/// Signe un webhook comme le fait `livekit-server` : JWT HS256, `iss` = clé,
/// `sha256` = empreinte base64 standard du corps.
String _signWebhook(
  List<int> body, {
  String apiKey = _apiKey,
  String apiSecret = _apiSecret,
  int? exp,
  String? sha256Override,
}) {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final header =
      _base64Url(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})));
  final payload = _base64Url(utf8.encode(jsonEncode({
    'iss': apiKey,
    'nbf': now - 10,
    'exp': exp ?? now + 300,
    'sha256': sha256Override ?? base64.encode(sha256.convert(body).bytes),
  })));
  final signature = Hmac(sha256, utf8.encode(apiSecret))
      .convert(utf8.encode('$header.$payload'));
  return '$header.$payload.${_base64Url(signature.bytes)}';
}

List<int> _event(
  String type, {
  String room = 'kf-0000abcd',
  String? identity,
  String? name,
  Object? createdAt,
}) =>
    utf8.encode(jsonEncode({
      'id': 'evt-1',
      'event': type,
      if (createdAt != null) 'createdAt': createdAt,
      'room': {'sid': 'RM_x', 'name': room},
      if (identity != null)
        'participant': {
          'sid': 'PA_x',
          'identity': identity,
          if (name != null) 'name': name,
          'joinedAt': '1758441600',
        },
    }));

void main() {
  group('LiveKitWebhookEvent', () {
    test('lit un événement protojson, createdAt en chaîne', () {
      final fallback = DateTime(2030);
      final event = LiveKitWebhookEvent.fromJson(
        jsonDecode(utf8.decode(_event('participant_joined',
            identity: 'alice', name: 'Alice', createdAt: '1758441600'))),
        now: fallback,
      )!;
      expect(event.type, LiveKitWebhookEventType.participantJoined);
      expect(event.roomName, 'kf-0000abcd');
      expect(event.participantIdentity, 'alice');
      expect(event.participantName, 'Alice');
      expect(event.concernsParticipant, isTrue);
      expect(event.createdAt.toUtc(),
          DateTime.fromMillisecondsSinceEpoch(1758441600 * 1000, isUtc: true));
    });

    test('createdAt numérique ou absent', () {
      final fallback = DateTime(2030);
      final numeric = LiveKitWebhookEvent.fromJson(
        jsonDecode(utf8.decode(
            _event('participant_left', identity: 'a', createdAt: 1758441601))),
        now: fallback,
      )!;
      expect(
          numeric.createdAt.toUtc().millisecondsSinceEpoch, 1758441601 * 1000);
      final missing = LiveKitWebhookEvent.fromJson(
        jsonDecode(utf8.decode(_event('participant_left', identity: 'a'))),
        now: fallback,
      )!;
      expect(missing.createdAt, fallback);
    });

    test('événements hors présence et corps invalides', () {
      final other = LiveKitWebhookEvent.fromJson(
        jsonDecode(utf8.decode(_event('track_published', identity: 'a'))),
        now: DateTime.now(),
      )!;
      expect(other.type, LiveKitWebhookEventType.other);
      expect(other.rawType, 'track_published');
      expect(other.concernsParticipant, isFalse);
      expect(LiveKitWebhookEvent.fromJson({'room': {}}, now: DateTime.now()),
          isNull);
      expect(
          LiveKitWebhookEvent.fromJson('texte', now: DateTime.now()), isNull);
    });
  });

  group('LiveKitWebhookVerifier', () {
    const verifier = LiveKitWebhookVerifier();
    final body = _event('participant_joined', identity: 'alice');

    String? check(String? authorization, {List<int>? withBody}) =>
        verifier.verify(
          body: withBody ?? body,
          authorization: authorization,
          apiKey: _credentials.apiKey,
          apiSecret: _credentials.apiSecret,
        );

    test('accepte une signature authentique, nue ou préfixée Bearer', () {
      final token = _signWebhook(body);
      expect(check(token), isNull);
      expect(check('Bearer $token'), isNull);
    });

    test('refuse un corps modifié après signature', () {
      final token = _signWebhook(body);
      final tampered = _event('participant_joined', identity: 'mallory');
      expect(check(token, withBody: tampered), 'empreinte du corps différente');
    });

    test('refuse un autre secret, une autre clé, un jeton expiré ou vide', () {
      expect(check(_signWebhook(body, apiSecret: 'autre-secret')),
          'signature invalide');
      expect(
          check(_signWebhook(body, apiKey: 'APIautre')), 'clé d\'API inconnue');
      final old = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 3600;
      expect(check(_signWebhook(body, exp: old)), 'jeton expiré');
      expect(check(null), 'en-tête Authorization absent');
      expect(check('a.b'), 'jeton mal formé');
      expect(check('a.b.c'), 'jeton illisible');
    });
  });

  group('LiveKitServerProcess.buildConfig', () {
    test('déclare le webhook signé avec la clé de la réunion', () {
      final config = LiveKitServerProcess.buildConfig(
        credentials: _credentials,
        apiPort: 7880,
        rtcTcpPort: 7881,
        rtcUdpPort: 7882,
        webhookUrl: 'http://127.0.0.1:8090/livekit/webhook',
      );
      expect(config, contains('webhook:\n  api_key: ${_credentials.apiKey}'));
      expect(config, contains('    - http://127.0.0.1:8090/livekit/webhook'));
      expect(config,
          contains('${_credentials.apiKey}: ${_credentials.apiSecret}'));
    });

    test('sans URL, pas de section webhook', () {
      final config = LiveKitServerProcess.buildConfig(
        credentials: _credentials,
        apiPort: 7880,
        rtcTcpPort: 7881,
        rtcUdpPort: 7882,
      );
      expect(config, isNot(contains('webhook')));
      expect(config, contains('logging:'));
    });
  });

  group('ConferenceHostServer', () {
    late ConferenceHostServer server;
    final tickets = <IssuedTicket>[];
    final events = <LiveKitWebhookEvent>[];

    setUp(() async {
      tickets.clear();
      events.clear();
      server = ConferenceHostServer(
        onTicketIssued: tickets.add,
        onWebhookEvent: events.add,
      );
      await server.start(port: 0);
      server.openRoom(conference: _conference(), credentials: _credentials);
    });

    tearDown(() => server.stop());

    Future<HttpClientResponse> post(String path, List<int> body,
        {String? authorization}) async {
      final client = HttpClient();
      final request = await client
          .postUrl(Uri.parse('http://127.0.0.1:${server.port}$path'));
      request.headers.contentType = ContentType('application', 'webhook+json');
      if (authorization != null) {
        request.headers.set(HttpHeaders.authorizationHeader, authorization);
      }
      request.add(body);
      final response = await request.close();
      await response.drain<void>();
      client.close();
      return response;
    }

    test('un ticket délivré est signalé avec le userId déclaré', () async {
      final client = HttpClient();
      final request = await client.getUrl(
          Uri.parse('http://127.0.0.1:${server.port}/rooms/kf-0000abcd/join'
              '?code=k7m2qp&identity=alice&name=Alice%20K&userId=u-alice'));
      final response = await request.close();
      final json = jsonDecode(await response.transform(utf8.decoder).join());
      client.close();
      expect(response.statusCode, 200);
      expect(json['token'], isNotEmpty);
      expect(tickets, hasLength(1));
      expect(tickets.single.roomId, 'kf-0000abcd');
      expect(tickets.single.identity, 'alice');
      expect(tickets.single.displayName, 'Alice K');
      expect(tickets.single.userId, 'u-alice');
    });

    test('un mauvais code ne délivre pas de ticket', () async {
      final client = HttpClient();
      final request = await client.getUrl(
          Uri.parse('http://127.0.0.1:${server.port}/rooms/kf-0000abcd/join'
              '?code=XXXXXX&identity=alice'));
      final response = await request.close();
      await response.drain<void>();
      client.close();
      expect(response.statusCode, 403);
      expect(tickets, isEmpty);
    });

    test('un webhook signé est relayé, un webhook falsifié est refusé',
        () async {
      final body =
          _event('participant_joined', identity: 'alice', name: 'Alice');
      final ok = await post(ConferenceHostServer.webhookPath, body,
          authorization: _signWebhook(body));
      expect(ok.statusCode, 200);
      expect(events, hasLength(1));
      expect(events.single.participantIdentity, 'alice');

      final forged = await post(ConferenceHostServer.webhookPath, body,
          authorization: _signWebhook(body, apiSecret: 'devine'));
      expect(forged.statusCode, 401);
      final unsigned = await post(ConferenceHostServer.webhookPath, body);
      expect(unsigned.statusCode, 401);
      expect(events, hasLength(1));
    });

    test(
        'une salle inconnue est ignorée sans erreur, un corps illisible refusé',
        () async {
      final body = _event('participant_joined', room: 'autre', identity: 'a');
      final ignored = await post(ConferenceHostServer.webhookPath, body,
          authorization: _signWebhook(body));
      expect(ignored.statusCode, 200);
      expect(events, isEmpty);
      final garbage = await post(
          ConferenceHostServer.webhookPath, utf8.encode('{pas du json'));
      expect(garbage.statusCode, 400);
    });
  });

  group('LiveAttendanceController', () {
    late ProviderContainer container;
    late InMemoryAttendanceStore store;

    setUp(() {
      store = InMemoryAttendanceStore();
      container = ProviderContainer(overrides: [
        attendanceStoreProvider.overrideWithValue(store),
      ]);
    });

    tearDown(() => container.dispose());

    LiveAttendanceController controller() =>
        container.read(liveAttendanceProvider.notifier);

    LiveKitWebhookEvent webhook(
            LiveKitWebhookEventType type, String identity, DateTime at,
            {String name = '', String room = 'kf-0000abcd'}) =>
        LiveKitWebhookEvent(
          type: type,
          rawType: type.wireName,
          roomName: room,
          participantIdentity: identity,
          participantName: name,
          createdAt: at,
        );

    test('suit tickets et webhooks, ignore l\'hôte et les autres salles',
        () async {
      final t0 = DateTime(2026, 9, 21, 8, 0);
      controller().open(_conference(), at: t0);
      controller().recordTicket(IssuedTicket(
          roomId: 'kf-0000abcd',
          identity: 'alice',
          displayName: 'Alice',
          userId: 'u1',
          issuedAt: t0));
      controller().recordTicket(IssuedTicket(
          roomId: 'autre-salle', identity: 'intrus', issuedAt: t0));
      controller().recordTicket(IssuedTicket(
          roomId: 'kf-0000abcd', identity: 'host-1', issuedAt: t0));
      controller().recordWebhook(webhook(
          LiveKitWebhookEventType.participantJoined,
          'alice',
          t0.add(const Duration(minutes: 1))));
      controller().recordWebhook(webhook(
          LiveKitWebhookEventType.participantJoined,
          'bob',
          t0.add(const Duration(minutes: 2)),
          name: 'Bob'));
      controller().recordWebhook(webhook(
          LiveKitWebhookEventType.participantJoined,
          'host-1',
          t0.add(const Duration(minutes: 2))));
      controller().recordWebhook(webhook(
          LiveKitWebhookEventType.participantLeft,
          'alice',
          t0.add(const Duration(minutes: 30))));

      final sheet = container.read(liveAttendanceProvider)!;
      expect([for (final e in sheet.entries) e.identity], ['alice', 'bob']);
      expect(sheet.entryFor('alice')!.userId, 'u1');
      expect(sheet.entryFor('alice')!.isConnected, isFalse);
      expect(sheet.entryFor('bob')!.isConnected, isTrue);
      expect(sheet.entryFor('bob')!.label, 'Bob');

      await controller().close(at: t0.add(const Duration(minutes: 60)));
      expect(container.read(liveAttendanceProvider), isNull);
      final saved = (await store.read('kf-0000abcd'))!;
      expect(saved.isClosed, isTrue);
      expect(saved.entryFor('bob')!.totalDuration(saved.endedAt!),
          const Duration(minutes: 58));
      final past = await container.read(pastAttendancesProvider.future);
      expect(past.single.conferenceId, 'kf-0000abcd');
    });

    test('la feuille est persistée après chaque événement', () async {
      final t0 = DateTime(2026, 9, 21, 8, 0);
      controller().open(_conference(), at: t0);
      controller().recordWebhook(
          webhook(LiveKitWebhookEventType.participantJoined, 'alice', t0));
      // Laisse la file d'écriture se vider.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      final saved = await store.read('kf-0000abcd');
      expect(saved, isNotNull);
      expect(saved!.isClosed, isFalse);
      expect(saved.entryFor('alice'), isNotNull);
    });

    test('une feuille orpheline est close à sa dernière activité', () async {
      final t0 = DateTime(2026, 9, 20, 8, 0);
      await store.save(ConferenceAttendance(
        conferenceId: 'kf-orpheline',
        title: 'Séance interrompue',
        hostId: 'h',
        hostName: 'h',
        startedAt: t0,
      )
          .recordJoin(identity: 'a', at: t0)
          .recordLeave(identity: 'a', at: t0.add(const Duration(minutes: 40)))
          .recordJoin(identity: 'b', at: t0.add(const Duration(minutes: 5))));
      final past = await container.read(pastAttendancesProvider.future);
      expect(past.single.isClosed, isTrue);
      expect(past.single.endedAt, t0.add(const Duration(minutes: 40)));
      expect(past.single.entryFor('b')!.isConnected, isFalse);
      expect((await store.read('kf-orpheline'))!.isClosed, isTrue);
    });
  });
}
