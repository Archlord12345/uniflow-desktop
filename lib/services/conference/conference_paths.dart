import 'dart:io';

/// Dossier de travail du service de réunion sur ce poste : configuration du
/// serveur média, journaux, feuilles de présence.
///
/// Dans le dossier personnel plutôt que dans celui de l'application : le
/// desktop doit pouvoir fonctionner un mois sans réseau, et ces fichiers
/// doivent survivre à une réinstallation. `systemTemp` n'est qu'un repli pour
/// un poste sans dossier personnel (compte de service).
String conferenceHomeDirectory() {
  final home = Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      Directory.systemTemp.path;
  return '$home${Platform.pathSeparator}.uniflow${Platform.pathSeparator}conference';
}

/// Sous-dossier des feuilles de présence.
String attendanceDirectory() =>
    '${conferenceHomeDirectory()}${Platform.pathSeparator}presences';
