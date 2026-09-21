// Exports de la feuille de présence : lignes mises en forme (fonction pure),
// nom de fichier, rendu PDF et classeur, écriture dans un dossier.

import 'dart:io';

import 'package:excel/excel.dart' as xl;
import 'package:flutter/services.dart' show ByteData;
import 'package:flutter_test/flutter_test.dart';
import 'package:uniflow/services/conference/attendance_export.dart';
import 'package:uniflow/services/conference/attendance_export_service.dart';
import 'package:uniflow/services/conference/conference_attendance.dart';

final DateTime _t0 = DateTime(2026, 9, 21, 8, 0);
DateTime _at(int minutes) => _t0.add(Duration(minutes: minutes));

ConferenceAttendance _closedSheet() => ConferenceAttendance(
      conferenceId: 'kf-3f9a2c81',
      title: 'Cours de Réseaux — L3',
      hostId: 'host-1',
      hostName: 'Pr. Fouda',
      startedAt: _t0,
    )
        .recordTicket(
            identity: 'alice',
            displayName: 'Alice K.',
            userId: 'u-1',
            at: _at(0))
        .recordTicket(identity: 'chloe', displayName: 'Chloé', at: _at(0))
        .recordJoin(identity: 'alice', at: _at(2))
        .recordLeave(identity: 'alice', at: _at(20))
        .recordJoin(identity: 'alice', at: _at(25))
        .recordLeave(identity: 'alice', at: _at(58))
        .recordJoin(identity: 'bob', displayName: 'Bob', at: _at(5))
        .recordLeave(identity: 'bob', at: _at(15))
        .close(at: _at(60));

/// Polices lues sur le disque du dépôt : `rootBundle` n'existe pas ici, et
/// Helvetica n'a pas le « — » du titre.
Future<ByteData> _font(String name) async {
  final bytes = await File('assets/fonts/$name').readAsBytes();
  return ByteData.sublistView(bytes);
}

void main() {
  group('buildAttendanceExport', () {
    test('met en forme les lignes, triées, avec statut et cumul', () {
      final data = buildAttendanceExport(_closedSheet(), now: _at(90));
      final byName = {for (final row in data.rows) row.name: row};
      expect([for (final row in data.rows) row.name],
          ['Alice K.', 'Bob', 'Chloé']);

      final alice = byName['Alice K.']!;
      expect(alice.arrival, '08:02');
      expect(alice.departure, '08:58');
      expect(alice.duration, '51 min');
      expect(alice.connections, 2);
      expect(alice.status, AttendanceStatus.present);
      expect(alice.identifier, 'u-1');

      final bob = byName['Bob']!;
      expect(bob.duration, '10 min');
      expect(bob.status, AttendanceStatus.partial);
      expect(bob.identifier, 'bob');

      final chloe = byName['Chloé']!;
      expect(chloe.arrival, exportDash);
      expect(chloe.departure, exportDash);
      expect(chloe.duration, exportDash);
      expect(chloe.status, AttendanceStatus.absent);

      final summary = data.summary;
      expect(summary.title, 'Cours de Réseaux — L3');
      expect(summary.hostName, 'Pr. Fouda');
      expect(summary.dateLabel, '21/09/2026 · 08:00 → 09:00');
      expect(summary.durationLabel, '1 h 00 min');
      expect(summary.thresholdLabel, '50 % (30 min)');
      expect(summary.invited, 3);
      expect(summary.present, 1);
      expect(summary.partial, 1);
      expect(summary.absent, 1);
      expect(summary.provisional, isFalse);
      expect(summary.countsLabel,
          'Invités 3 · Présents 1 · Partiels 1 · Absents 1');
    });

    test('une réunion en cours s\'exporte comme provisoire', () {
      final live = ConferenceAttendance(
        conferenceId: 'kf-1',
        title: '',
        hostId: 'h',
        hostName: '',
        startedAt: _t0,
      ).recordJoin(identity: 'x', at: _at(0));
      final data = buildAttendanceExport(live, now: _at(10));
      expect(data.summary.title, 'Réunion');
      expect(data.summary.hostName, exportDash);
      expect(data.summary.provisional, isTrue);
      expect(data.summary.dateLabel, endsWith('→ en cours'));
      expect(data.rows.single.departure, 'En ligne');
      expect(data.rows.single.duration, '10 min');
    });
  });

  group('Nom de fichier', () {
    test('slug sans accent ni ponctuation', () {
      expect(slugify('Cours de Réseaux — L3'), 'cours-de-reseaux-l3');
      expect(slugify('  Éçà : Ünïcode/œuvre!  '), 'eca-unicode-oeuvre');
      expect(slugify('—'), 'reunion');
      expect(slugify(''), 'reunion');
      expect(slugify('a' * 80).length, 48);
    });

    test('presence-<slug>-<AAAA-MM-JJ>', () {
      expect(attendanceFileStem(_closedSheet()),
          'presence-cours-de-reseaux-l3-2026-09-21');
    });
  });

  group('Rendus', () {
    test('le PDF est un document valide avec police embarquée', () async {
      final data = buildAttendanceExport(_closedSheet(), now: _at(90));
      final bytes = await buildAttendancePdf(
        data,
        fonts: AttendancePdfFonts.fromBytes(
          regular: await _font('Inter-Regular.ttf'),
          bold: await _font('Inter-Bold.ttf'),
        ),
      );
      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      final tail = String.fromCharCodes(bytes.skip(bytes.length - 64));
      expect(tail, contains('%%EOF'));
    });

    test('le PDF sans logo ni police se rend quand même', () async {
      final data = buildAttendanceExport(_closedSheet(), now: _at(90));
      final bytes = await buildAttendancePdf(data);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('le classeur a une feuille « Présence », le tableau et la synthèse',
        () {
      final data = buildAttendanceExport(_closedSheet(), now: _at(90));
      final bytes = buildAttendanceExcel(data);
      final workbook = xl.Excel.decodeBytes(bytes);
      expect(workbook.sheets.keys, [excelSheetName]);
      final sheet = workbook.sheets[excelSheetName]!;
      final rows = [
        for (final row in sheet.rows)
          [for (final cell in row) cell?.value?.toString() ?? ''],
      ];
      final headerIndex =
          rows.indexWhere((row) => row.isNotEmpty && row.first == 'Nom');
      expect(headerIndex, greaterThan(0));
      expect(rows[headerIndex].take(excelHeaders.length), excelHeaders);
      expect(rows[headerIndex + 1].take(5),
          ['Alice K.', '08:02', '08:58', '51 min', 'Présent']);
      expect(rows[headerIndex + 1][5], '2');
      expect(rows[headerIndex + 3].take(5),
          ['Chloé', exportDash, exportDash, exportDash, 'Absent']);
      final synthese =
          rows.firstWhere((row) => row.isNotEmpty && row.first == 'Synthèse');
      expect(synthese.take(5), [
        'Synthèse',
        'Invités : 3',
        'Présents : 1',
        'Partiels : 1',
        'Absents : 1',
      ]);
      expect(
          rows.any((row) => row.isNotEmpty && row.first == exportFooterLabel),
          isTrue);
    });
  });

  group('AttendanceExportService', () {
    late Directory temp;
    final opened = <Uri>[];

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('uniflow-exports-');
      opened.clear();
    });

    tearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    AttendanceExportService service() => AttendanceExportService(
          resolveDirectory: () async =>
              Directory('${temp.path}/UniFlow/Présences'),
          launch: (uri) async {
            opened.add(uri);
            return true;
          },
          loadAsset: (key) async => null,
        );

    test('écrit le PDF et le classeur dans le dossier, sans écraser', () async {
      final sheet = _closedSheet();
      final pdf = await service()
          .export(sheet, AttendanceExportFormat.pdf, now: _at(90));
      final xlsx = await service()
          .export(sheet, AttendanceExportFormat.excel, now: _at(90));
      expect(
          pdf.path,
          endsWith(
              '/UniFlow/Présences/presence-cours-de-reseaux-l3-2026-09-21.pdf'));
      expect(
          xlsx.path, endsWith('presence-cours-de-reseaux-l3-2026-09-21.xlsx'));
      expect(await pdf.length(), greaterThan(500));
      expect(await xlsx.length(), greaterThan(500));

      final again = await service()
          .export(sheet, AttendanceExportFormat.pdf, now: _at(90));
      expect(again.path,
          endsWith('presence-cours-de-reseaux-l3-2026-09-21-2.pdf'));
      expect(await pdf.exists(), isTrue);
    });

    test('ouvre le fichier en file://', () async {
      final file = await service()
          .export(_closedSheet(), AttendanceExportFormat.excel, now: _at(90));
      expect(await service().open(file), isTrue);
      expect(opened.single.scheme, 'file');
      expect(opened.single.toFilePath(), file.absolute.path);
    });
  });
}
