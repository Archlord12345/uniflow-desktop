// Feuille de présence des visioconférences : cumul des connexions, seuil de
// présence, invités jamais connectés, persistance sur le poste.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uniflow/services/conference/attendance_store.dart';
import 'package:uniflow/services/conference/conference_attendance.dart';
import 'package:uniflow/utils/french_date.dart';

final DateTime _t0 = DateTime(2026, 9, 21, 8, 0);

DateTime _at(int minutes) => _t0.add(Duration(minutes: minutes));

ConferenceAttendance _sheet() => ConferenceAttendance(
      conferenceId: 'kf-3f9a2c81',
      title: 'Cours de Réseaux — L3',
      hostId: 'host-1',
      hostName: 'Pr. Fouda',
      startedAt: _t0,
    );

void main() {
  group('AttendanceEntry — durées', () {
    test('cumule plusieurs connexions au lieu de mesurer du premier au dernier',
        () {
      // Alice : 8h00-8h10, coupure, 8h40-8h50 → 20 min, pas 50.
      final sheet = _sheet()
          .recordJoin(identity: 'alice', displayName: 'Alice', at: _at(0))
          .recordLeave(identity: 'alice', at: _at(10))
          .recordJoin(identity: 'alice', at: _at(40))
          .recordLeave(identity: 'alice', at: _at(50));
      final alice = sheet.entryFor('alice')!;
      expect(alice.connectionCount, 2);
      expect(alice.totalDuration(_at(60)), const Duration(minutes: 20));
      expect(alice.firstJoinedAt, _at(0));
      expect(alice.lastLeftAt, _at(50));
      expect(alice.isConnected, isFalse);
    });

    test('une connexion ouverte court jusqu\'à maintenant', () {
      final sheet = _sheet().recordJoin(identity: 'bob', at: _at(5));
      final bob = sheet.entryFor('bob')!;
      expect(bob.isConnected, isTrue);
      expect(bob.lastLeftAt, isNull);
      expect(bob.totalDuration(_at(35)), const Duration(minutes: 30));
    });

    test('une arrivée sans départ reçu clôt la connexion précédente', () {
      // Le webhook « participant_left » s'est perdu : la seconde arrivée ne
      // doit pas laisser deux connexions ouvertes en parallèle.
      final sheet = _sheet()
          .recordJoin(identity: 'bob', at: _at(0))
          .recordJoin(identity: 'bob', at: _at(30));
      final bob = sheet.entryFor('bob')!;
      expect(bob.connectionCount, 2);
      expect(bob.sessions.first.leftAt, _at(30));
      expect(bob.sessions.last.isOpen, isTrue);
      expect(bob.totalDuration(_at(40)), const Duration(minutes: 40));
    });

    test('un départ sans arrivée connue est ignoré', () {
      final sheet = _sheet().recordLeave(identity: 'fantome', at: _at(10));
      expect(sheet.entries, isEmpty);
    });

    test('un départ horodaté avant l\'arrivée ne retranche rien', () {
      final sheet = _sheet()
          .recordJoin(identity: 'carl', at: _at(10))
          .recordLeave(identity: 'carl', at: _at(9));
      expect(sheet.entryFor('carl')!.totalDuration(_at(60)), Duration.zero);
    });

    test('le nom affiché arrive parfois après le ticket', () {
      final sheet = _sheet()
          .recordTicket(identity: 'dan', at: _at(0))
          .recordJoin(identity: 'dan', displayName: 'Dan Ekwalla', at: _at(1));
      expect(sheet.entryFor('dan')!.label, 'Dan Ekwalla');
      expect(sheet.entryFor('dan')!.invitedAt, _at(0));
    });
  });

  group('ConferenceAttendance — seuil et verdicts', () {
    test('présent au-delà du seuil, partiel en dessous, absent sans connexion',
        () {
      final sheet = _sheet()
          .recordTicket(identity: 'alice', displayName: 'Alice', at: _at(0))
          .recordTicket(identity: 'bob', displayName: 'Bob', at: _at(0))
          .recordTicket(identity: 'chloe', displayName: 'Chloé', at: _at(0))
          .recordJoin(identity: 'alice', at: _at(0))
          .recordLeave(identity: 'alice', at: _at(45))
          .recordJoin(identity: 'bob', at: _at(0))
          .recordLeave(identity: 'bob', at: _at(20))
          .close(at: _at(60));

      // Réunion d'une heure, seuil 50 % → 30 min exigées.
      expect(sheet.requiredPresenceAt(_at(60)), const Duration(minutes: 30));
      expect(sheet.statusOf(sheet.entryFor('alice')!, _at(60)),
          AttendanceStatus.present);
      expect(sheet.statusOf(sheet.entryFor('bob')!, _at(60)),
          AttendanceStatus.partial);
      expect(sheet.statusOf(sheet.entryFor('chloe')!, _at(60)),
          AttendanceStatus.absent);

      final summary = sheet.summaryAt(_at(60));
      expect(summary.invited, 3);
      expect(summary.present, 1);
      expect(summary.partial, 1);
      expect(summary.absent, 1);
      expect(summary.connectedNow, 0);
      expect(summary.meetingDuration, const Duration(hours: 1));
    });

    test('le seuil est paramétrable et borné', () {
      final base = _sheet()
          .recordJoin(identity: 'bob', at: _at(0))
          .recordLeave(identity: 'bob', at: _at(20))
          .close(at: _at(60));
      expect(base.statusOf(base.entryFor('bob')!, _at(60)),
          AttendanceStatus.partial);
      final lenient = base.withPresenceThreshold(0.25);
      expect(lenient.statusOf(lenient.entryFor('bob')!, _at(60)),
          AttendanceStatus.present);
      expect(base.withPresenceThreshold(1.7).presenceThreshold, 1.0);
      expect(base.withPresenceThreshold(-1).presenceThreshold, 0.0);
    });

    test('un invité jamais connecté reste sur la feuille, absent', () {
      final sheet = _sheet()
          .recordTicket(identity: 'eva', displayName: 'Eva', userId: 'u-eva',
              at: _at(2))
          .close(at: _at(60));
      final eva = sheet.entryFor('eva')!;
      expect(eva.hasConnected, isFalse);
      expect(eva.userId, 'u-eva');
      expect(sheet.statusOf(eva, _at(60)), AttendanceStatus.absent);
      expect(sheet.invitedCount, 1);
    });

    test('pendant la réunion, le verdict suit la durée écoulée', () {
      final sheet = _sheet().recordJoin(identity: 'bob', at: _at(0));
      // Connecté depuis le début : présent quel que soit l'instant.
      expect(sheet.statusOf(sheet.entryFor('bob')!, _at(1)),
          AttendanceStatus.present);
      final left = sheet.recordLeave(identity: 'bob', at: _at(10));
      // À la 15e minute, 10 min sur 15 → présent ; à la 30e, 10 sur 30 → partiel.
      expect(left.statusOf(left.entryFor('bob')!, _at(15)),
          AttendanceStatus.present);
      expect(left.statusOf(left.entryFor('bob')!, _at(30)),
          AttendanceStatus.partial);
    });

    test('la clôture ferme toutes les connexions ouvertes', () {
      final sheet = _sheet()
          .recordJoin(identity: 'alice', at: _at(0))
          .recordJoin(identity: 'bob', at: _at(30))
          .close(at: _at(60));
      expect(sheet.isClosed, isTrue);
      expect(sheet.endedAt, _at(60));
      expect(sheet.connectedCount(), 0);
      expect(sheet.entryFor('alice')!.lastLeftAt, _at(60));
      expect(sheet.entryFor('bob')!.totalDuration(_at(90)),
          const Duration(minutes: 30));
      // Clore deux fois ne déplace pas la fin.
      expect(sheet.close(at: _at(90)).endedAt, _at(60));
    });

    test('le tri met les connectés d\'abord, puis les venus, puis les absents',
        () {
      final sheet = _sheet()
          .recordTicket(identity: 'z', displayName: 'Zoé', at: _at(0))
          .recordJoin(identity: 'y', displayName: 'Yann', at: _at(0))
          .recordLeave(identity: 'y', at: _at(5))
          .recordJoin(identity: 'b', displayName: 'béa', at: _at(0))
          .recordJoin(identity: 'a', displayName: 'Ali', at: _at(0));
      expect(
        [for (final entry in sheet.sortedEntries()) entry.label],
        ['Ali', 'béa', 'Yann', 'Zoé'],
      );
    });

    test('un second ticket complète sans écraser', () {
      final sheet = _sheet()
          .recordTicket(identity: 'f', displayName: 'Fatou', at: _at(0))
          .recordTicket(identity: 'f', displayName: 'Autre', userId: 'u-f',
              at: _at(3));
      final f = sheet.entryFor('f')!;
      expect(f.displayName, 'Fatou');
      expect(f.userId, 'u-f');
      expect(f.invitedAt, _at(0));
      expect(sheet.entries, hasLength(1));
    });
  });

  group('ConferenceAttendance — JSON', () {
    test('aller-retour complet, dates en UTC relues en heure locale', () {
      final sheet = _sheet()
          .recordTicket(identity: 'alice', displayName: 'Alice', userId: 'u1',
              at: _at(0))
          .recordJoin(identity: 'alice', at: _at(1))
          .recordLeave(identity: 'alice', at: _at(20))
          .recordJoin(identity: 'alice', at: _at(25))
          .withPresenceThreshold(0.75)
          .withSchedule('sched-1')
          .close(at: _at(60));
      final json = jsonDecode(jsonEncode(sheet.toJson()));
      final back = ConferenceAttendance.fromJson(json)!;
      expect(back.conferenceId, sheet.conferenceId);
      expect(back.title, sheet.title);
      expect(back.hostName, 'Pr. Fouda');
      expect(back.startedAt, sheet.startedAt);
      expect(back.endedAt, sheet.endedAt);
      expect(back.presenceThreshold, 0.75);
      expect(back.scheduleId, 'sched-1');
      final alice = back.entryFor('alice')!;
      expect(alice.userId, 'u1');
      expect(alice.invitedAt, _at(0));
      expect(alice.connectionCount, 2);
      expect(alice.totalDuration(_at(60)),
          sheet.entryFor('alice')!.totalDuration(_at(60)));
    });

    test('un JSON invalide rend null, un participant invalide est ignoré', () {
      expect(ConferenceAttendance.fromJson('pas un objet'), isNull);
      expect(ConferenceAttendance.fromJson({'title': 'sans id'}), isNull);
      final sheet = ConferenceAttendance.fromJson({
        'conferenceId': 'kf-1',
        'startedAt': _t0.toUtc().toIso8601String(),
        'presenceThreshold': 'n/a',
        'entries': [
          {'identity': 'ok', 'sessions': 'rien'},
          {'sessions': []},
        ],
      })!;
      expect(sheet.presenceThreshold,
          ConferenceAttendance.defaultPresenceThreshold);
      expect(sheet.entries, hasLength(1));
      expect(sheet.entries.single.identity, 'ok');
    });
  });

  group('FileAttendanceStore', () {
    late Directory temp;
    late FileAttendanceStore store;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('uniflow-presences-');
      store = FileAttendanceStore(temp.path);
    });

    tearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    test('écrit, relit, liste par date décroissante et supprime', () async {
      final older = _sheet().close(at: _at(60));
      final newer = ConferenceAttendance(
        conferenceId: 'kf-recent',
        title: 'TD Algo',
        hostId: 'h',
        hostName: 'Dr. Nkolo',
        startedAt: _at(24 * 60),
      ).recordJoin(identity: 'x', at: _at(24 * 60));
      await store.save(older);
      await store.save(newer);

      final listed = await store.list();
      expect([for (final s in listed) s.conferenceId], ['kf-recent', 'kf-3f9a2c81']);
      expect((await store.read('kf-3f9a2c81'))!.title, 'Cours de Réseaux — L3');
      // Le fichier temporaire de l'écriture atomique ne traîne pas.
      final leftovers = temp.listSync().where((e) => e.path.endsWith('.tmp'));
      expect(leftovers, isEmpty);

      await store.delete('kf-recent');
      expect(await store.read('kf-recent'), isNull);
      expect(await store.list(), hasLength(1));
    });

    test('un fichier corrompu n\'empêche pas de lire les autres', () async {
      await store.save(_sheet());
      await File('${temp.path}/casse.json').writeAsString('{"conferenceId": ');
      final listed = await store.list();
      expect(listed, hasLength(1));
      expect(listed.single.conferenceId, 'kf-3f9a2c81');
    });

    test('un identifiant hostile reste dans le dossier', () async {
      final hostile = ConferenceAttendance(
        conferenceId: '../../evil',
        title: 'x',
        hostId: 'h',
        hostName: 'h',
        startedAt: _t0,
      );
      await store.save(hostile);
      final files = temp.listSync().whereType<File>().toList();
      expect(files, hasLength(1));
      expect(files.single.path.startsWith(temp.path), isTrue);
      expect(files.single.path.contains('..'), isFalse);
    });

    test('un dossier absent rend une liste vide', () async {
      final missing = FileAttendanceStore('${temp.path}/inexistant');
      expect(await missing.list(), isEmpty);
    });
  });

  group('Formats français', () {
    test('durées lisibles', () {
      expect(formatDurationFr(const Duration(hours: 1, minutes: 5)), '1 h 05 min');
      expect(formatDurationFr(const Duration(minutes: 12, seconds: 30)), '12 min');
      expect(formatDurationFr(const Duration(seconds: 45)), '45 s');
      expect(formatDurationFr(const Duration(seconds: -3)), '0 s');
    });

    test('heures et dates', () {
      final date = DateTime(2026, 9, 21, 8, 5);
      expect(formatClock(date), '08:05');
      expect(formatShortDate(date), '21/09/2026');
      expect(formatShortDateTime(date), '21/09/2026 08:05');
      expect(formatIsoDate(date), '2026-09-21');
    });
  });
}
