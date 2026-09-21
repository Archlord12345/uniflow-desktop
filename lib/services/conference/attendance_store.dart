import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'conference_attendance.dart';

/// Où les feuilles de présence sont conservées.
///
/// Une interface, pour que les tests et l'écran de mise en page n'écrivent
/// rien dans le dossier de l'utilisateur.
abstract class AttendanceStore {
  Future<void> save(ConferenceAttendance sheet);
  Future<ConferenceAttendance?> read(String conferenceId);

  /// Toutes les feuilles, la plus récente d'abord.
  Future<List<ConferenceAttendance>> list();
  Future<void> delete(String conferenceId);
}

/// Un fichier JSON par réunion, dans le dossier du service de réunion.
///
/// Le desktop doit fonctionner hors ligne pendant des semaines : la feuille
/// est écrite sur le poste à chaque événement, et relue telle quelle. Aucun
/// serveur n'intervient.
class FileAttendanceStore implements AttendanceStore {
  final String directory;

  const FileAttendanceStore(this.directory);

  static const String _extension = '.json';

  File _file(String conferenceId) => File(
      '$directory${Platform.pathSeparator}${_safeName(conferenceId)}$_extension');

  /// Un identifiant de réunion est produit par le poste (`kf-3f9a2c81`),
  /// mais un fichier relu d'un autre poste pourrait en porter n'importe quoi :
  /// on ne laisse jamais un identifiant écrire hors du dossier.
  static String _safeName(String conferenceId) {
    final cleaned = conferenceId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return cleaned.isEmpty ? 'reunion' : cleaned;
  }

  @override
  Future<void> save(ConferenceAttendance sheet) async {
    try {
      final file = _file(sheet.conferenceId);
      await file.parent.create(recursive: true);
      // Écriture dans un fichier voisin puis renommage : un arrêt brutal
      // pendant l'écriture laisse l'ancienne feuille intacte au lieu d'un
      // JSON tronqué, qui serait perdu à la relecture.
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(jsonEncode(sheet.toJson()), flush: true);
      await temp.rename(file.path);
    } catch (error) {
      // Une feuille non écrite ne doit jamais interrompre la réunion : on le
      // signale, et la prochaine écriture (au prochain événement) réessaie.
      debugPrint('Feuille de présence non écrite : $error');
    }
  }

  @override
  Future<ConferenceAttendance?> read(String conferenceId) async {
    try {
      final file = _file(conferenceId);
      if (!await file.exists()) return null;
      return ConferenceAttendance.fromJson(
          jsonDecode(await file.readAsString()));
    } catch (error) {
      debugPrint('Feuille de présence illisible : $error');
      return null;
    }
  }

  @override
  Future<List<ConferenceAttendance>> list() async {
    final root = Directory(directory);
    if (!await root.exists()) return const [];
    final sheets = <ConferenceAttendance>[];
    try {
      await for (final entity in root.list(followLinks: false)) {
        if (entity is! File || !entity.path.endsWith(_extension)) continue;
        try {
          final sheet = ConferenceAttendance.fromJson(
              jsonDecode(await entity.readAsString()));
          if (sheet != null) sheets.add(sheet);
        } catch (error) {
          // Un fichier illisible n'empêche pas les autres de s'afficher.
          debugPrint('Feuille de présence ignorée (${entity.path}) : $error');
        }
      }
    } on FileSystemException catch (error) {
      debugPrint('Dossier des présences illisible : $error');
    }
    sheets.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return sheets;
  }

  @override
  Future<void> delete(String conferenceId) async {
    try {
      final file = _file(conferenceId);
      if (await file.exists()) await file.delete();
    } catch (error) {
      debugPrint('Feuille de présence non supprimée : $error');
    }
  }
}

/// Stockage en mémoire, pour les tests et l'écran de mise en page.
class InMemoryAttendanceStore implements AttendanceStore {
  final Map<String, ConferenceAttendance> _sheets = {};

  InMemoryAttendanceStore([Iterable<ConferenceAttendance> initial = const []]) {
    for (final sheet in initial) {
      _sheets[sheet.conferenceId] = sheet;
    }
  }

  @override
  Future<void> save(ConferenceAttendance sheet) async =>
      _sheets[sheet.conferenceId] = sheet;

  @override
  Future<ConferenceAttendance?> read(String conferenceId) async =>
      _sheets[conferenceId];

  @override
  Future<List<ConferenceAttendance>> list() async {
    final sheets = _sheets.values.toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return sheets;
  }

  @override
  Future<void> delete(String conferenceId) async =>
      _sheets.remove(conferenceId);
}
