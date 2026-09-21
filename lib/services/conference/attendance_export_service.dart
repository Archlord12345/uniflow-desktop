import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'attendance_export.dart';
import 'conference_attendance.dart';

/// Formats proposés à l'hôte.
enum AttendanceExportFormat {
  pdf('pdf', 'PDF'),
  excel('xlsx', 'Excel');

  final String extension;
  final String label;
  const AttendanceExportFormat(this.extension, this.label);
}

/// Écrit les exports dans le dossier Documents de l'utilisateur et propose de
/// les ouvrir.
///
/// Le dossier, le chargement des ressources et l'ouverture sont injectables :
/// ce sont des plugins de plateforme (`path_provider`, `url_launcher`,
/// `rootBundle`) qui n'existent pas dans un test — et un test ne doit de
/// toute façon rien écrire dans les Documents de qui le lance.
class AttendanceExportService {
  final Future<Directory> Function() resolveDirectory;
  final Future<bool> Function(Uri uri) launch;
  final Future<ByteData?> Function(String key) loadAsset;

  AttendanceExportService({
    Future<Directory> Function()? resolveDirectory,
    Future<bool> Function(Uri uri)? launch,
    Future<ByteData?> Function(String key)? loadAsset,
  })  : resolveDirectory = resolveDirectory ?? defaultDirectory,
        launch = launch ?? _launchExternal,
        loadAsset = loadAsset ?? _loadBundleAsset;

  /// Sous-dossier des exports dans les Documents de l'utilisateur.
  static const List<String> subfolders = ['UniFlow', 'Présences'];

  /// `~/Documents/UniFlow/Présences` (ou l'équivalent de la plateforme).
  static Future<Directory> defaultDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    final separator = Platform.pathSeparator;
    return Directory('${documents.path}$separator${subfolders.join(separator)}');
  }

  /// Produit le fichier et le renvoie ; lève si l'écriture échoue.
  Future<File> export(
    ConferenceAttendance sheet,
    AttendanceExportFormat format, {
    DateTime? now,
  }) async {
    final data = buildAttendanceExport(sheet, now: now);
    final List<int> bytes = switch (format) {
      AttendanceExportFormat.pdf => await buildAttendancePdf(
          data,
          logoPng: await _bytes('assets/brand/uniflow-wordmark.png'),
          fonts: await _fonts(),
        ),
      AttendanceExportFormat.excel => buildAttendanceExcel(data),
    };

    final directory = await resolveDirectory();
    await directory.create(recursive: true);
    final file = await uniqueFile(
        directory, attendanceFileStem(sheet), format.extension);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Ouvre le fichier avec l'application associée du système.
  Future<bool> open(File file) async {
    try {
      return await launch(Uri.file(file.absolute.path));
    } on Object {
      // `url_launcher` lève sur un poste sans gestionnaire de fichiers
      // associé : le fichier existe quand même, l'écran donne son chemin.
      return false;
    }
  }

  /// `presence-x-2026-09-21.pdf`, puis `-2`, `-3`… si le nom est pris : deux
  /// réunions homonymes le même jour ne doivent pas s'écraser, et un
  /// ré-export garde l'édition précédente, comme un téléchargement.
  static Future<File> uniqueFile(
      Directory directory, String stem, String extension) async {
    final separator = Platform.pathSeparator;
    var candidate = File('${directory.path}$separator$stem.$extension');
    var index = 2;
    while (await candidate.exists()) {
      candidate =
          File('${directory.path}$separator$stem-$index.$extension');
      index++;
    }
    return candidate;
  }

  Future<Uint8List?> _bytes(String key) async {
    final data = await loadAsset(key);
    return data?.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  Future<AttendancePdfFonts?> _fonts() async {
    final regular = await loadAsset('assets/fonts/Inter-Regular.ttf');
    final bold = await loadAsset('assets/fonts/Inter-Bold.ttf');
    if (regular == null || bold == null) return null;
    return AttendancePdfFonts.fromBytes(regular: regular, bold: bold);
  }

  static Future<bool> _launchExternal(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  static Future<ByteData?> _loadBundleAsset(String key) async {
    try {
      return await rootBundle.load(key);
    } on Object {
      // Ressource absente du bundle : le PDF se passe de logo ou de police
      // plutôt que d'échouer.
      return null;
    }
  }
}
