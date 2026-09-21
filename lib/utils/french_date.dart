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
