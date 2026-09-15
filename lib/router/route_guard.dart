/// Gardes de navigation, transposées de `uniflow-we/src/App.tsx`.
///
/// Sur le web, `AdminRoute` renvoie vers `/app` quand le rôle n'est pas
/// `ADMIN` : l'écran n'est pas seulement absent du menu, il est **refusé**
/// même si on atteint son URL directement. Le desktop n'a pas d'URL, mais il a
/// l'équivalent : un écran peut être demandé par du code (une fiche étudiant
/// qui renvoie vers la liste, un futur lien profond, la restauration d'un
/// dernier écran consulté). La décision passe donc par [canAccess], et jamais
/// par la seule présence dans le menu.
///
/// Toutes les fonctions de ce fichier sont pures : la matrice
/// rôle × écran est vérifiable en test sans serveur ni interface.
///
/// La directive `library` doit précéder les imports — le commentaire ci-dessus
/// lui est rattaché, et l'analyseur refuse une directive qui suit un `import`.
library;

import '../models/app_destination.dart';
import '../models/user_role.dart';

/// L'écran est-il ouvert à ce couple (rôle, type de compte) ?
///
/// C'est **la** fonction de décision. La barre latérale s'en sert pour
/// construire le menu, la coquille pour refuser une destination atteinte par
/// un autre chemin : une seule règle, donc aucun risque qu'un écran affiché
/// soit refusé, ou l'inverse.
bool canAccess(
  AppDestination destination, {
  required UserRole role,
  required AccountType accountType,
}) {
  if (!destination.roles.contains(role)) return false;
  if (destination.personalOnly && accountType != AccountType.personal) {
    return false;
  }
  if (destination.universityOnly && accountType != AccountType.university) {
    return false;
  }
  return true;
}

/// Motif du refus, en clair.
///
/// Un écran qui disparaît sans explication passe pour une panne : le
/// propriétaire a demandé qu'aucun écran ne reste muet. Cette phrase est
/// affichée à l'utilisateur qui demande une destination interdite.
String refusalReason(
  AppDestination destination, {
  required UserRole role,
  required AccountType accountType,
}) {
  if (!destination.roles.contains(role)) {
    if (destination.roles.length == 1 &&
        destination.roles.contains(UserRole.admin)) {
      return '« ${destination.label} » est réservé à l\'administration.';
    }
    return 'Votre rôle (${role.label}) n\'ouvre pas « ${destination.label} ».';
  }
  if (destination.personalOnly) {
    return '« ${destination.label} » n\'existe que pour les comptes '
        'personnels.';
  }
  if (destination.universityOnly) {
    return '« ${destination.label} » suppose un rattachement à un '
        'établissement ; votre compte est personnel.';
  }
  return '« ${destination.label} » ne vous est pas accessible.';
}

/// Les écrans visibles pour ce couple (rôle, type de compte), dans l'ordre de
/// déclaration de [AppDestination] — donc dans l'ordre d'affichage du menu.
List<AppDestination> visibleDestinations({
  required UserRole role,
  required AccountType accountType,
}) =>
    AppDestination.values
        .where((destination) =>
            canAccess(destination, role: role, accountType: accountType))
        .toList();

/// Écran d'accueil auquel renvoyer après un refus ou une connexion.
///
/// Le web fait de même : `GuestRoute` renvoie un administrateur vers `/admin`
/// et tout autre compte vers `/app`. Ici, un compte personnel n'a pas de
/// tableau de bord d'établissement — il atterrit sur son espace personnel.
AppDestination homeDestination({
  required UserRole role,
  required AccountType accountType,
}) {
  if (accountType == AccountType.personal &&
      canAccess(
        AppDestination.personalWorkspace,
        role: role,
        accountType: accountType,
      )) {
    return AppDestination.personalWorkspace;
  }
  return AppDestination.dashboard;
}

/// Regroupe les écrans visibles par section, en omettant les sections vides.
///
/// Un en-tête « Administration » suivi de rien donnerait à un étudiant l'image
/// d'un menu cassé ; c'est exactement ce que produisait l'ancienne liste figée.
Map<NavSection, List<AppDestination>> groupedDestinations({
  required UserRole role,
  required AccountType accountType,
}) {
  final grouped = <NavSection, List<AppDestination>>{};
  for (final destination in visibleDestinations(
    role: role,
    accountType: accountType,
  )) {
    grouped.putIfAbsent(destination.section, () => []).add(destination);
  }
  return grouped;
}
