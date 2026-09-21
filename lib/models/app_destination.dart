import '../widgets/uni_icons.dart';
import 'user_role.dart';

/// Section du menu latéral.
///
/// Le desktop n'a pas d'URL : contrairement au web, il n'y a pas de route
/// « /admin/etudiants » qu'on puisse taper directement. La section joue le
/// rôle que joue le préfixe de route sur le web — elle sépare visuellement
/// l'espace de travail de l'espace d'administration, qui n'est montré qu'aux
/// administrateurs.
enum NavSection {
  pilotage('Pilotage'),
  scolarite('Scolarité'),
  pedagogie('Pédagogie'),
  campus('Vie de campus'),
  administration('Administration'),
  systeme('Système');

  final String label;
  const NavSection(this.label);
}

/// Tous les rôles : raccourci pour les écrans réellement communs.
const Set<UserRole> _everyone = {
  UserRole.student,
  UserRole.delegate,
  UserRole.teacher,
  UserRole.admin,
};

/// Les personnels : ils encadrent et évaluent.
const Set<UserRole> _staff = {UserRole.teacher, UserRole.admin};

/// Un écran atteignable depuis l'application.
///
/// Chaque entrée porte **elle-même** les rôles qui y ont droit. C'est ce qui
/// remplace la liste figée d'autrefois : la barre latérale se construit à
/// partir de ces rôles, et la garde de navigation relit la même donnée. Une
/// seule source de vérité, donc pas de menu qui propose un écran que la garde
/// refuse ensuite.
enum AppDestination {
  // --- Pilotage ---------------------------------------------------------
  dashboard(
    'tableau-de-bord',
    'Tableau de bord',
    UniIcons.dashboard,
    NavSection.pilotage,
    _everyone,
  ),
  personalWorkspace(
    'espace-personnel',
    'Espace personnel',
    UniIcons.assistant,
    NavSection.pilotage,
    {UserRole.student, UserRole.teacher},
    personalOnly: true,
  ),
  notifications(
    'notifications',
    'Notifications',
    UniIcons.notifications,
    NavSection.pilotage,
    _everyone,
  ),

  // --- Scolarité --------------------------------------------------------
  // « Étudiants » et « Enseignants » sont des écrans d'administration au sens
  // du web (`/admin/etudiants`, `/admin/enseignants`) : un étudiant ne doit
  // pas pouvoir parcourir l'annuaire complet de l'établissement.
  students(
    'etudiants',
    'Étudiants',
    UniIcons.students,
    NavSection.scolarite,
    {UserRole.delegate, UserRole.teacher, UserRole.admin},
  ),
  teachers(
    'enseignants',
    'Enseignants',
    UniIcons.teachers,
    NavSection.scolarite,
    {UserRole.admin},
  ),
  programs(
    'programmes',
    'Programmes',
    UniIcons.courses,
    NavSection.scolarite,
    {UserRole.teacher, UserRole.admin},
  ),
  teachingUnits(
    'unites-enseignement',
    'Unités d\'enseignement',
    UniIcons.teachingUnits,
    NavSection.scolarite,
    {UserRole.teacher, UserRole.admin},
  ),
  structure(
    'structure',
    'Structure',
    UniIcons.treeStructure,
    NavSection.scolarite,
    {UserRole.admin},
  ),
  classrooms(
    'salles',
    'Salles',
    UniIcons.room,
    NavSection.scolarite,
    _everyone,
    universityOnly: true,
  ),
  schedule(
    'emploi-du-temps',
    'Emploi du temps',
    UniIcons.schedule,
    NavSection.scolarite,
    _everyone,
    universityOnly: true,
  ),

  // --- Pédagogie --------------------------------------------------------
  attendance(
    'presences',
    'Présences',
    UniIcons.attendance,
    NavSection.pedagogie,
    {UserRole.delegate, UserRole.teacher, UserRole.admin},
  ),
  assignments(
    'devoirs',
    'Devoirs',
    UniIcons.assignments,
    NavSection.pedagogie,
    _everyone,
    universityOnly: true,
  ),
  grades(
    'notes',
    'Notes',
    UniIcons.grades,
    NavSection.pedagogie,
    _everyone,
    universityOnly: true,
  ),
  library(
    'bibliotheque',
    'Bibliothèque',
    UniIcons.library,
    NavSection.pedagogie,
    _everyone,
  ),

  // --- Vie de campus ----------------------------------------------------
  conferences(
    'conferences',
    'Conférences',
    UniIcons.video,
    NavSection.campus,
    _everyone,
  ),
  messaging(
    'messagerie',
    'Messagerie',
    UniIcons.messaging,
    NavSection.campus,
    _everyone,
  ),
  teams(
    'equipe',
    'Équipe',
    UniIcons.team,
    NavSection.campus,
    _everyone,
  ),

  // --- Administration ---------------------------------------------------
  // Création et gestion des comptes universitaires : réservée à
  // l'administration (`/admin-directory` refait la vérification côté serveur).
  accounts(
    'comptes',
    'Comptes',
    UniIcons.accounts,
    NavSection.administration,
    {UserRole.admin},
  ),
  statistics(
    'statistiques',
    'Statistiques',
    UniIcons.statistics,
    NavSection.administration,
    _staff,
  ),
  sentinelle(
    'sentinelle',
    'Sentinelle IoT',
    UniIcons.security,
    NavSection.administration,
    {UserRole.admin},
  ),
  payments(
    'paiements',
    'Paiements',
    UniIcons.subscription,
    NavSection.administration,
    {UserRole.admin},
  ),

  // --- Système ----------------------------------------------------------
  settings(
    'parametres',
    'Paramètres',
    UniIcons.settings,
    NavSection.systeme,
    _everyone,
  );

  /// Identifiant stable, en kebab-case, aligné sur les chemins du web
  /// (`/app/emploi-du-temps`, `/admin/utilisateurs`…). Il sert de clé de
  /// persistance et de journal, jamais d'affichage.
  final String id;

  final String label;

  /// Icône Phosphor de la destination, sous forme de constructeur : la barre
  /// latérale la rend en `fill` quand elle est active et en `bold` sinon
  /// (spec `docs/icones-uniflow.md`), donc l'entrée ne peut pas figer un
  /// style unique comme le faisait l'ancien `IconData` Material.
  final UniIcon phosphor;
  final NavSection section;

  /// Rôles autorisés à ouvrir cet écran.
  final Set<UserRole> roles;

  /// Réservé aux comptes personnels (`PERSONAL`). Le web fait de même avec
  /// `IndependentWorkspacePage`, qui n'existe que pour ces comptes.
  final bool personalOnly;

  /// Interdit aux comptes personnels. Sur le web, `PersonalLearningRoute`
  /// renvoie ces comptes vers leur espace personnel au lieu de la page de
  /// cursus : un compte personnel n'a ni promotion ni relevé de notes
  /// universitaire.
  final bool universityOnly;

  const AppDestination(
    this.id,
    this.label,
    this.phosphor,
    this.section,
    this.roles, {
    this.personalOnly = false,
    this.universityOnly = false,
  });

  /// Faut-il un compte universitaire pour ouvrir cet écran ?
  bool get requiresUniversityAccount => universityOnly;

  /// Icône dans le style demandé (`duotone` par défaut pour les tuiles).
  PhosphorIconData icon([UniIconStyle style = UniIcons.defaultStyle]) =>
      phosphor(style);
}

/// Ce qu'un écran pose dans le coin inférieur droit du corps de la coquille,
/// là où vit le bouton d'Uni.
///
/// Uni était posé au même endroit sur tous les écrans et recouvrait le bouton
/// « Envoyer » de la messagerie (constat du propriétaire sur le mobile le
/// 2026-09-21, même défaut sur le desktop). L'écran qui occupe ce coin le
/// **déclare** ici, et `AppShell` en déduit où accrocher Uni. Le `switch` de
/// [AppDestinationBottomEdge.bottomEdge] est exhaustif : une destination
/// ajoutée sans déclaration ne compile pas, et `test/uni_dock_test.dart`
/// monte chaque écran dans la coquille pour attraper une déclaration fausse.
enum BottomEdge {
  /// Rien : Uni garde son coin, en bas à droite.
  free,

  /// Un composeur (champ de saisie et bouton d'envoi) finit en bas à droite
  /// du corps : Uni glisse dans le coin bas gauche, qui est libre puisque le
  /// corps commence après la barre latérale.
  composer,
}

extension AppDestinationBottomEdge on AppDestination {
  /// Le bord inférieur de cet écran. Une entrée par destination, sans
  /// `default` : c'est ce qui oblige à se poser la question pour chaque
  /// nouvel écran.
  BottomEdge get bottomEdge => switch (this) {
        AppDestination.dashboard => BottomEdge.free,
        AppDestination.personalWorkspace => BottomEdge.free,
        AppDestination.notifications => BottomEdge.free,
        AppDestination.students => BottomEdge.free,
        AppDestination.teachers => BottomEdge.free,
        AppDestination.programs => BottomEdge.free,
        AppDestination.teachingUnits => BottomEdge.free,
        AppDestination.structure => BottomEdge.free,
        AppDestination.classrooms => BottomEdge.free,
        AppDestination.schedule => BottomEdge.free,
        AppDestination.attendance => BottomEdge.free,
        AppDestination.assignments => BottomEdge.free,
        AppDestination.grades => BottomEdge.free,
        AppDestination.library => BottomEdge.free,
        AppDestination.conferences => BottomEdge.free,
        // Liste des conversations à gauche, fil à droite : le composeur
        // (champ + « Envoyer ») termine le fil, en bas à droite du corps.
        AppDestination.messaging => BottomEdge.composer,
        AppDestination.teams => BottomEdge.free,
        AppDestination.accounts => BottomEdge.free,
        AppDestination.statistics => BottomEdge.free,
        AppDestination.sentinelle => BottomEdge.free,
        AppDestination.payments => BottomEdge.free,
        AppDestination.settings => BottomEdge.free,
      };
}
