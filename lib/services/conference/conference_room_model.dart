/// Logique pure de l'écran de salle : disposition des vignettes, libellés.
/// Séparée du widget pour être testée sans caméra ni serveur média.
library;

/// Ce que l'écran sait d'un participant, indépendamment du SDK média.
class RoomTile {
  final String identity;
  final String name;
  final bool isLocal;
  final bool isSpeaking;
  final bool micOn;
  final bool cameraOn;
  final bool sharingScreen;

  const RoomTile({
    required this.identity,
    required this.name,
    this.isLocal = false,
    this.isSpeaking = false,
    this.micOn = false,
    this.cameraOn = false,
    this.sharingScreen = false,
  });

  String get label {
    final base = name.trim().isEmpty ? identity : name.trim();
    return isLocal ? '$base (vous)' : base;
  }

  String get initials => initialsOf(name.trim().isEmpty ? identity : name);
}

/// Initiales d'un nom (« Pr. Jean Fouda » → « JF »), au plus deux lettres ;
/// « ? » si rien n'est exploitable.
String initialsOf(String name) {
  const titles = {'dr', 'pr', 'prof', 'm', 'mr', 'mme', 'mlle', 'ing'};
  final words = name
      .split(RegExp(r'[\s._-]+'))
      .map((w) => w.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), ''))
      .where((w) => w.isNotEmpty && !titles.contains(w.toLowerCase()))
      .toList();
  if (words.isEmpty) return '?';
  final first = words.first[0];
  final second = words.length > 1 ? words.last[0] : '';
  return '$first$second'.toUpperCase();
}

/// Vignette à mettre en scène (grande) : la vignette épinglée si elle existe
/// encore, sinon le premier partage d'écran, sinon aucune (grille égale).
String? stageIdentity(List<RoomTile> tiles, {String? pinned}) {
  if (pinned != null && tiles.any((t) => t.identity == pinned)) return pinned;
  for (final tile in tiles) {
    if (tile.sharingScreen) return tile.identity;
  }
  return null;
}

/// Nombre de colonnes d'une grille de [count] vignettes dans [width] pixels :
/// une vignette doit rester lisible (≥ 220 px) sans laisser de trou.
int gridColumns(int count, double width) {
  if (count <= 1) return 1;
  final fit = (width / 220).floor().clamp(1, 6);
  final wanted = switch (count) {
    2 => 2,
    3 || 4 => 2,
    5 || 6 => 3,
    7 || 8 || 9 => 3,
    _ => 4,
  };
  return wanted < fit ? wanted : fit;
}

/// Ordre d'affichage : le partage d'écran d'abord, puis qui parle, puis
/// l'ordre d'arrivée — et soi-même en dernier, comme sur les outils courants.
List<RoomTile> orderTiles(List<RoomTile> tiles) {
  final ordered = List<RoomTile>.of(tiles);
  int rank(RoomTile t) {
    if (t.sharingScreen) return 0;
    if (t.isLocal) return 3;
    if (t.isSpeaking) return 1;
    return 2;
  }
  final indexed = ordered.asMap().entries.toList()
    ..sort((a, b) {
      final byRank = rank(a.value).compareTo(rank(b.value));
      return byRank != 0 ? byRank : a.key.compareTo(b.key);
    });
  return [for (final e in indexed) e.value];
}

/// Phrase de la barre de titre : « 1 participant », « 4 participants ».
String participantCountLabel(int count) =>
    count <= 1 ? '$count participant' : '$count participants';

/// Message affiché quand le serveur média coupe la connexion.
String disconnectReasonLabel(String? reason) {
  switch ((reason ?? '').toLowerCase()) {
    case 'duplicateidentity':
    case 'duplicate_identity':
      return 'Vous avez rejoint cette réunion depuis un autre appareil : cette connexion a été fermée.';
    case 'roomdeleted':
    case 'room_deleted':
    case 'roomclosed':
    case 'room_closed':
      return 'L\'hôte a terminé la réunion.';
    case 'participantremoved':
    case 'participant_removed':
      return 'L\'hôte vous a retiré de la réunion.';
    case 'clientinitiated':
    case 'client_initiated':
      return 'Vous avez quitté la réunion.';
    case 'joinfailure':
    case 'join_failure':
      return 'La connexion à la salle a été refusée : le jeton est peut-être expiré.';
    case 'statemismatch':
    case 'state_mismatch':
    case 'signalclose':
    case 'signal_close':
      return 'La liaison avec le serveur média a été perdue.';
    default:
      return 'Connexion à la réunion interrompue.';
  }
}
