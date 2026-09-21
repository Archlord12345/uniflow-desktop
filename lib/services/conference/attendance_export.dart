/// Exports d'une feuille de présence : lignes prêtes à imprimer, PDF, classeur.
///
/// Tout ici est du Dart pur, sans plugin de plateforme : la mise en forme des
/// lignes se teste sans rendu, et les deux rendus (PDF via `pdf`, classeur via
/// `excel`) produisent des octets que l'appelant écrit où il veut. C'est
/// `AttendanceExportService` qui connaît le dossier Documents et l'ouverture
/// du fichier.
library;

import 'dart:typed_data';

import 'package:excel/excel.dart' as xl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../utils/french_date.dart';
import 'conference_attendance.dart';

/// Une ligne du tableau exporté, déjà mise en forme.
class AttendanceExportRow {
  final String name;

  /// Identifiant Appwrite s'il est connu, sinon l'identité LiveKit : c'est
  /// la colonne qui permet au secrétariat de rapprocher la ligne d'un compte.
  final String identifier;
  final String arrival;
  final String departure;
  final String duration;
  final int connections;
  final AttendanceStatus status;

  const AttendanceExportRow({
    required this.name,
    required this.identifier,
    required this.arrival,
    required this.departure,
    required this.duration,
    required this.connections,
    required this.status,
  });
}

/// En-tête et synthèse de l'export.
class AttendanceExportSummary {
  final String title;
  final String hostName;
  final String dateLabel;
  final String durationLabel;
  final String thresholdLabel;
  final int invited;
  final int present;
  final int partial;
  final int absent;
  final bool provisional;
  final DateTime generatedAt;

  const AttendanceExportSummary({
    required this.title,
    required this.hostName,
    required this.dateLabel,
    required this.durationLabel,
    required this.thresholdLabel,
    required this.invited,
    required this.present,
    required this.partial,
    required this.absent,
    required this.provisional,
    required this.generatedAt,
  });

  /// « Invités 17 · Présents 12 · Partiels 3 · Absents 2 ».
  String get countsLabel => 'Invités $invited · Présents $present · '
      'Partiels $partial · Absents $absent';
}

class AttendanceExportData {
  final AttendanceExportSummary summary;
  final List<AttendanceExportRow> rows;

  const AttendanceExportData({required this.summary, required this.rows});
}

/// Absence de valeur dans une cellule (jamais arrivé, jamais parti).
const String exportDash = '—';

/// Met en forme la feuille pour l'export, à l'instant [now].
///
/// Une réunion encore en cours s'exporte aussi : ses verdicts sont
/// provisoires (le seuil grandit avec la durée) et l'export le dit.
AttendanceExportData buildAttendanceExport(
  ConferenceAttendance sheet, {
  DateTime? now,
}) {
  final instant = now ?? DateTime.now();
  final end = sheet.endedAt;
  final summary = sheet.summaryAt(instant);
  final rows = <AttendanceExportRow>[
    for (final entry in sheet.sortedEntries())
      AttendanceExportRow(
        name: entry.label,
        identifier: entry.userId ?? entry.identity,
        arrival: entry.firstJoinedAt == null
            ? exportDash
            : formatClock(entry.firstJoinedAt!),
        departure: !entry.hasConnected
            ? exportDash
            : entry.isConnected
                ? 'En ligne'
                : formatClock(entry.lastLeftAt!),
        duration: entry.hasConnected
            ? formatDurationFr(entry.totalDuration(instant))
            : exportDash,
        connections: entry.connectionCount,
        status: sheet.statusOf(entry, instant),
      ),
  ];

  return AttendanceExportData(
    summary: AttendanceExportSummary(
      title: sheet.title.trim().isEmpty ? 'Réunion' : sheet.title.trim(),
      hostName: sheet.hostName.trim().isEmpty ? exportDash : sheet.hostName,
      dateLabel: '${formatShortDate(sheet.startedAt)} · '
          '${formatClock(sheet.startedAt)} → '
          '${end == null ? 'en cours' : formatClock(end)}',
      durationLabel: formatDurationFr(sheet.durationAt(instant)),
      thresholdLabel: '${(sheet.presenceThreshold * 100).round()} % '
          '(${formatDurationFr(sheet.requiredPresenceAt(instant))})',
      invited: summary.invited,
      present: summary.present,
      partial: summary.partial,
      absent: summary.absent,
      provisional: end == null,
      generatedAt: instant,
    ),
    rows: rows,
  );
}

/// « presence-cours-de-reseaux-l3-2026-09-21 », sans extension.
String attendanceFileStem(ConferenceAttendance sheet) =>
    'presence-${slugify(sheet.title)}-${formatIsoDate(sheet.startedAt)}';

/// Réduit un titre à un fragment de nom de fichier : minuscules, sans accent,
/// tirets. Un titre vide ou fait de ponctuation donne « reunion ».
String slugify(String value, {int maxLength = 48}) {
  final buffer = StringBuffer();
  for (final rune in value.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_accentFold[char] ?? char);
  }
  var slug = buffer
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-{2,}'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (slug.length > maxLength) {
    slug = slug.substring(0, maxLength).replaceAll(RegExp(r'-+$'), '');
  }
  return slug.isEmpty ? 'reunion' : slug;
}

const Map<String, String> _accentFold = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a',
  'ç': 'c',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'î': 'i', 'ï': 'i', 'í': 'i', 'ì': 'i',
  'ô': 'o', 'ö': 'o', 'ó': 'o', 'ò': 'o', 'õ': 'o',
  'û': 'u', 'ù': 'u', 'ü': 'u', 'ú': 'u',
  'ÿ': 'y', 'ý': 'y',
  'ñ': 'n',
  'æ': 'ae', 'œ': 'oe', 'ß': 'ss',
};

/// Polices embarquées pour le PDF.
///
/// Les polices standard du PDF (Helvetica) n'ont pas d'Unicode : « — » ou un
/// nom avec un caractère hors Latin-1 sortirait en carré. Inter est déjà dans
/// les ressources de l'application, on l'embarque.
class AttendancePdfFonts {
  final pw.Font regular;
  final pw.Font bold;

  const AttendancePdfFonts({required this.regular, required this.bold});

  factory AttendancePdfFonts.fromBytes({
    required ByteData regular,
    required ByteData bold,
  }) =>
      AttendancePdfFonts(
        regular: pw.Font.ttf(regular),
        bold: pw.Font.ttf(bold),
      );
}

/// Pied de page des documents produits.
const String exportFooterLabel = 'Généré par UniFlow — KERNEL FORGE';

/// Rend la feuille en PDF A4. [logoPng] est le logotype de l'en-tête ; sans
/// lui (test sans ressources), l'en-tête porte le nom du produit en texte.
Future<Uint8List> buildAttendancePdf(
  AttendanceExportData data, {
  Uint8List? logoPng,
  AttendancePdfFonts? fonts,
}) async {
  final theme = fonts == null
      ? null
      : pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold);
  final document = pw.Document(
    title: 'Présence — ${data.summary.title}',
    author: 'UniFlow',
    creator: 'UniFlow desktop',
    theme: theme,
  );

  const ink = PdfColor.fromInt(0xFF1F2937);
  const muted = PdfColor.fromInt(0xFF6B7280);
  const rule = PdfColor.fromInt(0xFFE5E7EB);
  const headerFill = PdfColor.fromInt(0xFFF3F4F6);
  const stripe = PdfColor.fromInt(0xFFFAFAFB);
  final logo = logoPng == null ? null : pw.MemoryImage(logoPng);
  final summary = data.summary;

  pw.Widget meta(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Row(children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(label,
                style: const pw.TextStyle(fontSize: 10, color: muted)),
          ),
          pw.Expanded(
            child: pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 10,
                    color: ink,
                    fontWeight: pw.FontWeight.bold)),
          ),
        ]),
      );

  PdfColor statusColor(AttendanceStatus status) => switch (status) {
        AttendanceStatus.present => const PdfColor.fromInt(0xFF047857),
        AttendanceStatus.partial => const PdfColor.fromInt(0xFFB45309),
        AttendanceStatus.absent => const PdfColor.fromInt(0xFFB91C1C),
      };

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 40),
      header: (context) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 10),
        margin: const pw.EdgeInsets.only(bottom: 16),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: rule, width: 1)),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logo != null)
              pw.Image(logo, height: 26, fit: pw.BoxFit.contain)
            else
              pw.Text('UniFlow',
                  style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: ink)),
            pw.Spacer(),
            pw.Text('FEUILLE DE PRÉSENCE',
                style: pw.TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.2,
                    color: muted,
                    fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ),
      footer: (context) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 8),
        margin: const pw.EdgeInsets.only(top: 12),
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: rule, width: 1)),
        ),
        child: pw.Row(children: [
          pw.Text(exportFooterLabel,
              style: const pw.TextStyle(fontSize: 8.5, color: muted)),
          pw.Spacer(),
          pw.Text(
            'Édité le ${formatShortDateTime(summary.generatedAt)} · '
            'Page ${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8.5, color: muted),
          ),
        ]),
      ),
      build: (context) => [
        pw.Text(summary.title,
            style: pw.TextStyle(
                fontSize: 18, fontWeight: pw.FontWeight.bold, color: ink)),
        pw.SizedBox(height: 10),
        meta('Hôte', summary.hostName),
        meta('Date', summary.dateLabel),
        meta('Durée', summary.durationLabel),
        meta('Seuil de présence', summary.thresholdLabel),
        pw.SizedBox(height: 8),
        pw.Text(summary.countsLabel,
            style: pw.TextStyle(
                fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: ink)),
        if (summary.provisional)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Text(
              'Réunion en cours au moment de l\'édition : les statuts sont '
              'provisoires.',
              style: const pw.TextStyle(fontSize: 9, color: muted),
            ),
          ),
        pw.SizedBox(height: 14),
        if (data.rows.isEmpty)
          pw.Text('Aucun participant.',
              style: const pw.TextStyle(fontSize: 10, color: muted))
        else
          pw.TableHelper.fromTextArray(
            headers: const ['Nom', 'Arrivée', 'Départ', 'Durée', 'Statut'],
            data: [
              for (final row in data.rows)
                [
                  row.name,
                  row.arrival,
                  row.departure,
                  row.connections > 1
                      ? '${row.duration} (${row.connections} connexions)'
                      : row.duration,
                  row.status,
                ],
            ],
            cellBuilder: (index, cell, rowNum) {
              if (cell is! AttendanceStatus) return null;
              return pw.Text(cell.label,
                  style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                      color: statusColor(cell)));
            },
            headerStyle: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: muted,
                letterSpacing: 0.6),
            headerDecoration: const pw.BoxDecoration(color: headerFill),
            headerAlignment: pw.Alignment.centerLeft,
            cellStyle: const pw.TextStyle(fontSize: 9.5, color: ink),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding:
                const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            oddRowDecoration: const pw.BoxDecoration(color: stripe),
            border: const pw.TableBorder(
              horizontalInside: pw.BorderSide(color: rule, width: 0.5),
              bottom: pw.BorderSide(color: rule, width: 0.5),
            ),
            // « 1 h 05 min (2 connexions) » passait sur deux lignes dans une
            // colonne de poids 2.
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(2.6),
              4: pw.FlexColumnWidth(1.1),
            },
          ),
      ],
    ),
  );

  return document.save();
}

/// Nom de la feuille du classeur.
const String excelSheetName = 'Présence';

/// En-têtes du tableau du classeur.
const List<String> excelHeaders = [
  'Nom',
  'Arrivée',
  'Départ',
  'Durée',
  'Statut',
  'Connexions',
  'Identifiant',
];

/// Rend la feuille en classeur `.xlsx` : une feuille « Présence », l'en-tête
/// de la réunion, le tableau, puis une ligne de synthèse.
List<int> buildAttendanceExcel(AttendanceExportData data) {
  final excel = xl.Excel.createExcel();
  // Le classeur naît avec une feuille « Sheet1 » : on la renomme plutôt que
  // d'en créer une seconde, sinon le fichier s'ouvrirait sur une page vide.
  final defaultSheet = excel.getDefaultSheet();
  if (defaultSheet != null && defaultSheet != excelSheetName) {
    excel.rename(defaultSheet, excelSheetName);
  }
  final sheet = excel[excelSheetName];
  final summary = data.summary;
  final bold = xl.CellStyle(bold: true);

  void appendStyled(List<xl.CellValue?> cells, {xl.CellStyle? style}) {
    final rowIndex = sheet.maxRows;
    sheet.appendRow(cells);
    if (style == null) return;
    for (var column = 0; column < cells.length; column++) {
      sheet
          .cell(xl.CellIndex.indexByColumnRow(
              columnIndex: column, rowIndex: rowIndex))
          .cellStyle = style;
    }
  }

  appendStyled([xl.TextCellValue('Feuille de présence — ${summary.title}')],
      style: bold);
  appendStyled([xl.TextCellValue('Hôte'), xl.TextCellValue(summary.hostName)]);
  appendStyled([xl.TextCellValue('Date'), xl.TextCellValue(summary.dateLabel)]);
  appendStyled(
      [xl.TextCellValue('Durée'), xl.TextCellValue(summary.durationLabel)]);
  appendStyled([
    xl.TextCellValue('Seuil de présence'),
    xl.TextCellValue(summary.thresholdLabel),
  ]);
  if (summary.provisional) {
    appendStyled([
      xl.TextCellValue('Réunion en cours à l\'édition : statuts provisoires'),
    ]);
  }
  appendStyled(const []);

  appendStyled([for (final header in excelHeaders) xl.TextCellValue(header)],
      style: bold);
  for (final row in data.rows) {
    appendStyled([
      xl.TextCellValue(row.name),
      xl.TextCellValue(row.arrival),
      xl.TextCellValue(row.departure),
      xl.TextCellValue(row.duration),
      xl.TextCellValue(row.status.label),
      xl.IntCellValue(row.connections),
      xl.TextCellValue(row.identifier),
    ]);
  }

  appendStyled(const []);
  appendStyled([
    xl.TextCellValue('Synthèse'),
    xl.TextCellValue('Invités : ${summary.invited}'),
    xl.TextCellValue('Présents : ${summary.present}'),
    xl.TextCellValue('Partiels : ${summary.partial}'),
    xl.TextCellValue('Absents : ${summary.absent}'),
  ], style: bold);
  appendStyled([
    xl.TextCellValue(exportFooterLabel),
    xl.TextCellValue('Édité le ${formatShortDateTime(summary.generatedAt)}'),
  ]);

  sheet.setColumnWidth(0, 32);
  sheet.setColumnWidth(1, 12);
  sheet.setColumnWidth(2, 12);
  sheet.setColumnWidth(3, 14);
  sheet.setColumnWidth(4, 12);
  sheet.setColumnWidth(5, 12);
  sheet.setColumnWidth(6, 28);

  final bytes = excel.encode();
  if (bytes == null) {
    throw StateError('Le classeur n\'a pas pu être encodé.');
  }
  return bytes;
}
