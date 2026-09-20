import 'package:flutter/material.dart';

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
    Icons.grid_view_rounded,
    NavSection.pilotage,
    _everyone,
  ),
  personalWorkspace(
    'espace-personnel',
    'Espace personnel',
    Icons.auto_awesome_outlined,
    NavSection.pilotage,
    {UserRole.student, UserRole.teacher},
    personalOnly: true,
  ),
  notifications(
    'notifications',
    'Notifications',
    Icons.notifications_outlined,
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
    Icons.people_alt_outlined,
    NavSection.scolarite,
    {UserRole.delegate, UserRole.teacher, UserRole.admin},
  ),
  teachers(
    'enseignants',
    'Enseignants',
    Icons.school_outlined,
    NavSection.scolarite,
    {UserRole.admin},
  ),
  programs(
    'programmes',
    'Programmes',
    Icons.menu_book_outlined,
    NavSection.scolarite,
    {UserRole.teacher, UserRole.admin},
  ),
  teachingUnits(
    'unites-enseignement',
    'Unités d\'enseignement',
    Icons.dashboard_outlined,
    NavSection.scolarite,
    {UserRole.teacher, UserRole.admin},
  ),
  structure(
    'structure',
    'Structure',
    Icons.account_tree_outlined,
    NavSection.scolarite,
    {UserRole.admin},
  ),
  classrooms(
    'salles',
    'Salles',
    Icons.meeting_room_outlined,
    NavSection.scolarite,
    _everyone,
    universityOnly: true,
  ),
  schedule(
    'emploi-du-temps',
    'Emploi du temps',
    Icons.calendar_today_outlined,
    NavSection.scolarite,
    _everyone,
    universityOnly: true,
  ),

  // --- Pédagogie --------------------------------------------------------
  attendance(
    'presences',
    'Présences',
    Icons.event_available_outlined,
    NavSection.pedagogie,
    {UserRole.delegate, UserRole.teacher, UserRole.admin},
  ),
  assignments(
    'devoirs',
    'Devoirs',
    Icons.task_outlined,
    NavSection.pedagogie,
    _everyone,
    universityOnly: true,
  ),
  grades(
    'notes',
    'Notes',
    Icons.grade_outlined,
    NavSection.pedagogie,
    _everyone,
    universityOnly: true,
  ),
  library(
    'bibliotheque',
    'Bibliothèque',
    Icons.library_books_outlined,
    NavSection.pedagogie,
    _everyone,
  ),

  // --- Vie de campus ----------------------------------------------------
  conferences(
    'conferences',
    'Conférences',
    Icons.videocam_outlined,
    NavSection.campus,
    _everyone,
  ),
  messaging(
    'messagerie',
    'Messagerie',
    Icons.chat_bubble_outline,
    NavSection.campus,
    _everyone,
  ),
  teams(
    'equipe',
    'Équipe',
    Icons.groups_outlined,
    NavSection.campus,
    _everyone,
  ),

  // --- Administration ---------------------------------------------------
  // Création et gestion des comptes universitaires : réservée à
  // l'administration (`/admin-directory` refait la vérification côté serveur).
  accounts(
    'comptes',
    'Comptes',
    Icons.manage_accounts_outlined,
    NavSection.administration,
    {UserRole.admin},
  ),
  statistics(
    'statistiques',
    'Statistiques',
    Icons.bar_chart_outlined,
    NavSection.administration,
    _staff,
  ),
  sentinelle(
    'sentinelle',
    'Sentinelle IoT',
    Icons.security_outlined,
    NavSection.administration,
    {UserRole.admin},
  ),
  payments(
    'paiements',
    'Paiements',
    Icons.payments_outlined,
    NavSection.administration,
    {UserRole.admin},
  ),

  // --- Système ----------------------------------------------------------
  settings(
    'parametres',
    'Paramètres',
    Icons.settings_outlined,
    NavSection.systeme,
    _everyone,
  );

  /// Identifiant stable, en kebab-case, aligné sur les chemins du web
  /// (`/app/emploi-du-temps`, `/admin/utilisateurs`…). Il sert de clé de
  /// persistance et de journal, jamais d'affichage.
  final String id;

  final String label;
  final IconData icon;
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
    this.icon,
    this.section,
    this.roles, {
    this.personalOnly = false,
    this.universityOnly = false,
  });

  /// Faut-il un compte universitaire pour ouvrir cet écran ?
  bool get requiresUniversityAccount => universityOnly;
}
