/// Rôles et types de compte UniFlow, côté desktop.
///
/// Ce fichier est la transposition de `uniflow-we/src/utils/userRole.tsx` : le
/// desktop n'avait jusqu'ici aucun modèle de rôle, il affichait les mêmes
/// dix-neuf entrées de menu à tout le monde. Un `STUDENT` voyait donc les
/// écrans d'administration, et la liste des enseignants.
///
/// Deux notions distinctes, comme sur le web :
///  - le **rôle** (`UserRole`) dit ce que la personne fait ;
///  - le **type de compte** (`AccountType`) dit à quel espace elle
///    appartient — une université ou un usage personnel.
library;

/// Rôle d'un utilisateur. L'ordre de déclaration va du moins au plus
/// privilégié : c'est ce qui permet de comparer deux rôles si le besoin
/// apparaît un jour.
enum UserRole {
  student,
  delegate,
  teacher,
  admin;

  /// Libellé affiché dans l'interface, aligné sur le web
  /// (`buildUserProfile` de `userRole.tsx`).
  String get label {
    switch (this) {
      case UserRole.student:
        return 'Étudiant';
      case UserRole.delegate:
        return 'Délégué';
      case UserRole.teacher:
        return 'Enseignant';
      case UserRole.admin:
        return 'Administrateur';
    }
  }

  /// Libellé court, pour les badges de la barre latérale et du bandeau.
  String get badge {
    switch (this) {
      case UserRole.student:
        return 'Étudiant';
      case UserRole.delegate:
        return 'Délégué';
      case UserRole.teacher:
        return 'Enseignant';
      case UserRole.admin:
        return 'Admin';
    }
  }

  /// Description de ce que le rôle ouvre, affichée sur la fiche de profil.
  /// Le propriétaire a demandé que chacun sache ce qu'il voit et pourquoi ;
  /// une liste d'écrans masqués sans explication ne le permet pas.
  String get scope {
    switch (this) {
      case UserRole.student:
        return 'Vos cours, vos notes, vos devoirs et votre emploi du temps.';
      case UserRole.delegate:
        return 'Comme un étudiant, plus la gestion des présences de votre '
            'promotion.';
      case UserRole.teacher:
        return 'Vos enseignements, vos étudiants et vos évaluations.';
      case UserRole.admin:
        return 'La totalité de l\'établissement, y compris les comptes et '
            'les paramètres.';
    }
  }

  /// Seul l'administrateur ouvre les écrans d'administration.
  bool get isAdmin => this == UserRole.admin;

  /// L'enseignant participe à la pédagogie sans administrer l'établissement.
  bool get isTeaching => this == UserRole.teacher;

  /// Rôles qui suivent un cursus (et ont donc des notes et des devoirs).
  bool get isLearning => this == UserRole.student || this == UserRole.delegate;
}

/// Alias acceptés par [parseUserRole].
///
/// Le serveur porte aujourd'hui `STUDENT` / `DELEGATE` / `TEACHER` / `ADMIN`
/// pour les comptes réels, mais `academic_directory` et les anciens documents
/// portent les formes françaises, et le web accepte les deux. Refuser une
/// forme que le web accepte ferait diverger les deux clients sur le même
/// compte : le desktop afficherait « Étudiant » là où le web affiche
/// « Enseignant ».
const Map<String, UserRole> _roleAliases = {
  'STUDENT': UserRole.student,
  'ETUDIANT': UserRole.student,
  'INDEPENDENT_STUDENT': UserRole.student,
  'DELEGATE': UserRole.delegate,
  'DELEGUE': UserRole.delegate,
  'TEACHER': UserRole.teacher,
  'ENSEIGNANT': UserRole.teacher,
  'INDEPENDENT_TEACHER': UserRole.teacher,
  'ADMIN': UserRole.admin,
  'ADMINISTRATOR': UserRole.admin,
  'ADMINISTRATEUR': UserRole.admin,
};

/// Résout un rôle brut venant de la base.
///
/// Repli sur [UserRole.student] : c'est le rôle le **moins** permissif des
/// quatre. Un rôle inconnu ou absent doit fermer des portes, pas en ouvrir —
/// l'inverse ferait d'une donnée manquante un accès administrateur.
UserRole parseUserRole(String? raw) {
  if (raw == null) return UserRole.student;
  return _roleAliases[raw.trim().toUpperCase()] ?? UserRole.student;
}

/// Type de compte : rattaché à un établissement, ou usage personnel.
enum AccountType {
  university,
  personal;

  String get label {
    switch (this) {
      case AccountType.university:
        return 'Université';
      case AccountType.personal:
        return 'Personnel';
    }
  }
}

/// Résout le type de compte. Même prudence que pour le rôle : le repli est
/// `UNIVERSITY`, l'espace complet, mais c'est bien la valeur lue qui décide.
///
/// Le web accepte deux champs (`accountType` et `accountCategory`) ; le
/// desktop ne lit que `accountType`, mais accepte les deux valeurs `PERSONAL`
/// et `INDEPENDENT` que le web traite pareil.
AccountType parseAccountType(String? raw) {
  if (raw == null) return AccountType.university;
  switch (raw.trim().toUpperCase()) {
    case 'PERSONAL':
    case 'INDEPENDENT':
      return AccountType.personal;
    default:
      return AccountType.university;
  }
}
