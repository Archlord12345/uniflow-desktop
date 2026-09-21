/// Dates en français sans dépendre d'`intl` : l'application n'a que quelques
/// libellés à produire et le paquet imposerait d'initialiser les locales au
/// démarrage pour trois chaînes.
library;

const List<String> _weekdays = [
  'lundi',
  'mardi',
  'mercredi',
  'jeudi',
  'vendredi',
  'samedi',
  'dimanche',
];

const List<String> _months = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

/// « lundi 21 septembre 2026 », comme le `toLocaleDateString('fr-FR', …)`
/// de l'en-tête du tableau de bord web.
String formatLongDate(DateTime date) =>
    '${_weekdays[date.weekday - 1]} ${date.day} '
    '${_months[date.month - 1]} ${date.year}';

/// « Bonjour » avant midi, « Bonsoir » à partir de 18 h, « Bon après-midi »
/// entre les deux — le web se contente de « Bonjour », mais un poste de bureau
/// reste ouvert toute la journée et le salut du matin sonne faux le soir.
String greetingFor(DateTime now) {
  if (now.hour < 12) return 'Bonjour';
  if (now.hour < 18) return 'Bon après-midi';
  return 'Bonsoir';
}

String _two(int value) => value.toString().padLeft(2, '0');

/// « 08:05 » — l'heure d'une arrivée ou d'un départ sur une feuille de
/// présence ; les secondes n'y apportent rien.
String formatClock(DateTime date) => '${_two(date.hour)}:${_two(date.minute)}';

/// « 21/09/2026 », la date courte des tableaux.
String formatShortDate(DateTime date) =>
    '${_two(date.day)}/${_two(date.month)}/${date.year}';

/// « 21/09/2026 08:05 ».
String formatShortDateTime(DateTime date) =>
    '${formatShortDate(date)} ${formatClock(date)}';

/// « 2026-09-21 » : la date des noms de fichiers, qui se trient par ordre
/// chronologique dans un dossier.
String formatIsoDate(DateTime date) =>
    '${date.year}-${_two(date.month)}-${_two(date.day)}';

/// « 1 h 05 min », « 12 min », « 45 s » — une durée telle qu'on la lit sur une
/// feuille de présence. En dessous de la minute, les secondes disent qu'il y a
/// bien eu une connexion, là où « 0 min » ressemblerait à une absence.
String formatDurationFr(Duration duration) {
  if (duration.isNegative) duration = Duration.zero;
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) return '$hours h ${_two(minutes)} min';
  if (minutes > 0) return '$minutes min';
  return '${duration.inSeconds} s';
}
