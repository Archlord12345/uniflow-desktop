// Tests des rôles, des destinations et des périmètres de visibilité du desktop.
//
// Ces règles décident de ce qu'un compte voit et peut ouvrir. Elles sont
// écrites en fonctions pures ; ces tests les vérifient donc sans serveur ni
// interface, ce qui est la raison pour laquelle elles ont été écrites ainsi.
//
// Le défaut qu'elles corrigent : les dix-neuf entrées de menu étaient les mêmes
// pour tout le monde, si bien qu'un étudiant voyait les écrans
// d'administration et l'annuaire complet de l'établissement.

import 'package:flutter_test/flutter_test.dart';

import 'package:uniflow/models/app_destination.dart';
import 'package:uniflow/models/user_role.dart';
import 'package:uniflow/models/visibility_scope.dart';
import 'package:uniflow/router/route_guard.dart';

/// Portée vide, pratique pour ne remplir que ce qu'un cas teste.
VisibilityScope portee({
  required UserRole role,
  String userId = 'moi',
  String? program,
  String? level,
  Set<String> myCourseIds = const {},
  Map<String, Set<String>> courseIdsByStudent = const {},
  Map<String, String> teacherIdByCourse = const {},
}) =>
    VisibilityScope(
      role: role,
      userId: userId,
      program: program,
      level: level,
      myCourseIds: myCourseIds,
      courseIdsByStudent: courseIdsByStudent,
      teacherIdByCourse: teacherIdByCourse,
    );

void main() {
  group('parseUserRole', () {
    test('reconnaît les rôles du serveur', () {
      expect(parseUserRole('STUDENT'), UserRole.student);
      expect(parseUserRole('DELEGATE'), UserRole.delegate);
      expect(parseUserRole('TEACHER'), UserRole.teacher);
      expect(parseUserRole('ADMIN'), UserRole.admin);
    });

    test('reconnaît les formes françaises et les comptes personnels', () {
      // Le web accepte ces formes ; les refuser ferait diverger les deux
      // clients sur le même compte.
      expect(parseUserRole('ETUDIANT'), UserRole.student);
      expect(parseUserRole('DELEGUE'), UserRole.delegate);
      expect(parseUserRole('ENSEIGNANT'), UserRole.teacher);
      expect(parseUserRole('ADMINISTRATEUR'), UserRole.admin);
      expect(parseUserRole('INDEPENDENT_STUDENT'), UserRole.student);
      expect(parseUserRole('INDEPENDENT_TEACHER'), UserRole.teacher);
    });

    test('tolère la casse et les espaces', () {
      expect(parseUserRole('  admin '), UserRole.admin);
    });

    test('un rôle illisible ferme les portes au lieu de les ouvrir', () {
      // Le repli est le rôle le MOINS permissif : une donnée manquante ne doit
      // jamais devenir un accès administrateur.
      expect(parseUserRole('SUPER_ROOT'), UserRole.student);
      expect(parseUserRole(''), UserRole.student);
      expect(parseUserRole(null), UserRole.student);
    });
  });

  group('parseAccountType', () {
    test('personnel et indépendant sont le même espace', () {
      expect(parseAccountType('PERSONAL'), AccountType.personal);
      expect(parseAccountType('INDEPENDENT'), AccountType.personal);
    });

    test('tout le reste est universitaire', () {
      expect(parseAccountType('UNIVERSITY'), AccountType.university);
      expect(parseAccountType(null), AccountType.university);
      expect(parseAccountType('n\'importe quoi'), AccountType.university);
    });

    test(
        'PLATFORM est reconnu (insensible à la casse) et voit l\'établissement',
        () {
      expect(parseAccountType('PLATFORM'), AccountType.platform);
      expect(parseAccountType(' platform '), AccountType.platform);
      expect(AccountType.platform.seesInstitution, isTrue);
      expect(AccountType.university.seesInstitution, isTrue);
      expect(AccountType.personal.seesInstitution, isFalse);
      expect(AccountType.platform.wireValue, 'PLATFORM');
    });

    test(
        'la plateforme ouvre les écrans d\'établissement, pas l\'espace personnel',
        () {
      expect(
          canAccess(AppDestination.classrooms,
              role: UserRole.admin, accountType: AccountType.platform),
          isTrue);
      expect(
          canAccess(AppDestination.accounts,
              role: UserRole.admin, accountType: AccountType.platform),
          isTrue);
      expect(
          canAccess(AppDestination.personalWorkspace,
              role: UserRole.admin, accountType: AccountType.platform),
          isFalse);
      expect(
          homeDestination(
              role: UserRole.admin, accountType: AccountType.platform),
          AppDestination.dashboard);
    });
  });

  group('UserRole', () {
    test('seul l\'administrateur administre', () {
      expect(UserRole.admin.isAdmin, isTrue);
      expect(UserRole.teacher.isAdmin, isFalse);
      expect(UserRole.delegate.isAdmin, isFalse);
      expect(UserRole.student.isAdmin, isFalse);
    });

    test('le cursus est étudiant ou délégué', () {
      expect(UserRole.student.isLearning, isTrue);
      expect(UserRole.delegate.isLearning, isTrue);
      expect(UserRole.teacher.isLearning, isFalse);
      expect(UserRole.admin.isLearning, isFalse);
    });

    test('chaque rôle porte un libellé, un badge et un périmètre expliqué', () {
      for (final role in UserRole.values) {
        expect(role.label, isNotEmpty);
        expect(role.badge, isNotEmpty);
        expect(role.scope, isNotEmpty);
      }
    });
  });

  group('table des destinations', () {
    test('aucune destination n\'est ouverte à personne', () {
      for (final destination in AppDestination.values) {
        expect(destination.roles, isNotEmpty,
            reason: '${destination.id} n\'autorise aucun rôle');
      }
    });

    test('aucun identifiant n\'est déclaré deux fois', () {
      // L'identifiant sert de clé de persistance et de journal.
      final ids = AppDestination.values.map((d) => d.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('un écran réservé aux comptes personnels l\'est vraiment', () {
      // `personalOnly` et `universityOnly` à la fois seraient contradictoires :
      // l'écran n'ouvrirait à personne.
      for (final destination in AppDestination.values) {
        expect(destination.personalOnly && destination.universityOnly, isFalse,
            reason: '${destination.id} s\'exclut lui-même');
      }
    });
  });

  group('canAccess', () {
    test('un étudiant n\'ouvre pas l\'administration', () {
      expect(
          canAccess(AppDestination.teachers,
              role: UserRole.student, accountType: AccountType.university),
          isFalse);
      expect(
          canAccess(AppDestination.statistics,
              role: UserRole.student, accountType: AccountType.university),
          isFalse);
      expect(
          canAccess(AppDestination.settings,
              role: UserRole.student, accountType: AccountType.university),
          isTrue);
    });

    test(
        'un délégué voit les étudiants mais pas les paramètres de l\'établissement',
        () {
      expect(
          canAccess(AppDestination.students,
              role: UserRole.delegate, accountType: AccountType.university),
          isTrue);
      expect(
          canAccess(AppDestination.teachers,
              role: UserRole.delegate, accountType: AccountType.university),
          isFalse);
    });

    test('l\'écran personnel n\'existe que pour les comptes personnels', () {
      expect(
          canAccess(AppDestination.personalWorkspace,
              role: UserRole.student, accountType: AccountType.personal),
          isTrue);
      expect(
          canAccess(AppDestination.personalWorkspace,
              role: UserRole.student, accountType: AccountType.university),
          isFalse);
    });

    test('la règle est la même pour le menu et pour le refus', () {
      // C'est l'intérêt d'une source unique : un écran affiché ne peut pas être
      // refusé ensuite, ni l'inverse.
      for (final role in UserRole.values) {
        for (final type in AccountType.values) {
          final visibles = visibleDestinations(role: role, accountType: type);
          for (final destination in AppDestination.values) {
            expect(visibles.contains(destination),
                canAccess(destination, role: role, accountType: type),
                reason: '${destination.id} pour $role / $type');
          }
        }
      }
    });
  });

  group('groupedDestinations', () {
    test('aucune section vide n\'est proposée', () {
      // Un en-tête « Administration » suivi de rien donne l'image d'un menu
      // cassé : c'est ce que produisait l'ancienne liste figée.
      for (final role in UserRole.values) {
        for (final type in AccountType.values) {
          final groupes = groupedDestinations(role: role, accountType: type);
          for (final entry in groupes.entries) {
            expect(entry.value, isNotEmpty, reason: '${entry.key} pour $role');
          }
        }
      }
    });

    test('les destinations d\'une section gardent l\'ordre de déclaration', () {
      final groupes = groupedDestinations(
        role: UserRole.admin,
        accountType: AccountType.university,
      );
      for (final entry in groupes.entries) {
        final attendu = AppDestination.values
            .where((d) => d.section == entry.key && entry.value.contains(d))
            .toList();
        expect(entry.value, attendu);
      }
    });
  });

  group('homeDestination', () {
    test('un compte personnel atterrit sur son espace personnel', () {
      expect(
        homeDestination(
            role: UserRole.student, accountType: AccountType.personal),
        AppDestination.personalWorkspace,
      );
    });

    test('un compte universitaire atterrit sur le tableau de bord', () {
      for (final role in UserRole.values) {
        expect(
          homeDestination(role: role, accountType: AccountType.university),
          AppDestination.dashboard,
        );
      }
    });

    test('l\'accueil renvoyé est toujours accessible', () {
      // Renvoyer vers un écran fermé boucherait sur un refus après connexion.
      for (final role in UserRole.values) {
        for (final type in AccountType.values) {
          final accueil = homeDestination(role: role, accountType: type);
          expect(canAccess(accueil, role: role, accountType: type), isTrue,
              reason: '${accueil.id} pour $role / $type');
        }
      }
    });
  });

  group('refusalReason', () {
    test('explique toujours le refus, en nommant l\'écran', () {
      // Un écran qui disparaît sans explication passe pour une panne.
      for (final role in UserRole.values) {
        for (final type in AccountType.values) {
          for (final destination in AppDestination.values) {
            if (canAccess(destination, role: role, accountType: type)) continue;
            final motif =
                refusalReason(destination, role: role, accountType: type);
            expect(motif, contains(destination.label));
          }
        }
      }
    });

    test('distingue un écran d\'administration d\'un écran hors rôle', () {
      // Un écran réservé à l'administrateur le dit ; un écran simplement hors
      // du rôle nomme le rôle, pour que la personne comprenne ce qui manque.
      final admin = refusalReason(AppDestination.sentinelle,
          role: UserRole.student, accountType: AccountType.university);
      final horsRole = refusalReason(AppDestination.students,
          role: UserRole.student, accountType: AccountType.university);
      expect(admin, contains('administration'));
      expect(horsRole, contains('Étudiant'));
    });
  });

  group('VisibilityScope.seesStudent', () {
    test('l\'administrateur voit tout le monde', () {
      final porteeAdmin = portee(role: UserRole.admin);
      expect(porteeAdmin.seesStudent('n\'importe qui'), isTrue);
      expect(porteeAdmin.seesEveryone, isTrue);
    });

    test('l\'enseignant ne voit que les étudiants de ses cours', () {
      final enseignant = portee(
        role: UserRole.teacher,
        myCourseIds: {'ue1'},
        courseIdsByStudent: {
          'inscrit': {'ue1', 'ue2'},
          'ailleurs': {'ue3'},
        },
      );
      expect(enseignant.seesStudent('inscrit'), isTrue);
      expect(enseignant.seesStudent('ailleurs'), isFalse);
      expect(enseignant.seesStudent('inconnu'), isFalse);
    });

    test('l\'étudiant voit sa promotion : même filière ET même niveau', () {
      // Comparer la seule filière ferait voir les L3 à un L1.
      final etudiant = portee(
        role: UserRole.student,
        program: 'Informatique',
        level: 'Licence 3',
      );
      expect(
        etudiant.seesStudent('camarade',
            studentProgram: 'Informatique', studentLevel: 'Licence 3'),
        isTrue,
      );
      expect(
        etudiant.seesStudent('autre-niveau',
            studentProgram: 'Informatique', studentLevel: 'Licence 1'),
        isFalse,
      );
      expect(
        etudiant.seesStudent('autre-filiere',
            studentProgram: 'Mathématiques', studentLevel: 'Licence 3'),
        isFalse,
      );
    });

    test('un étudiant ne se voit pas lui-même dans une liste', () {
      final etudiant = portee(
        role: UserRole.student,
        userId: 'moi',
        program: 'Informatique',
        level: 'Licence 3',
      );
      expect(
        etudiant.seesStudent('moi',
            studentProgram: 'Informatique', studentLevel: 'Licence 3'),
        isFalse,
      );
    });

    test('sans filière ni niveau renseignés, personne n\'est visible', () {
      // Le repli ferme : une promotion inconnue ne doit pas ouvrir
      // l'établissement entier.
      final etudiant = portee(role: UserRole.delegate);
      expect(
        etudiant.seesStudent('camarade',
            studentProgram: 'Informatique', studentLevel: 'Licence 3'),
        isFalse,
      );
    });
  });

  group('VisibilityScope.seesTeacher', () {
    test('un enseignant ne consulte que sa propre fiche', () {
      final enseignant = portee(role: UserRole.teacher, userId: 'moi');
      expect(enseignant.seesTeacher('moi'), isTrue);
      expect(enseignant.seesTeacher('collegue'), isFalse);
    });

    test('l\'étudiant voit les enseignants qui encadrent ses cours', () {
      final etudiant = portee(
        role: UserRole.student,
        userId: 'moi',
        myCourseIds: {'ue1'},
        teacherIdByCourse: {'ue1': 'prof1', 'ue2': 'prof2'},
      );
      expect(etudiant.seesTeacher('prof1'), isTrue);
      expect(etudiant.seesTeacher('prof2'), isFalse);
      // Sa propre fiche reste visible, même sans cours en commun.
      expect(etudiant.seesTeacher('moi'), isTrue);
    });

    test('filterTeachers et filterStudents appliquent la même règle', () {
      final enseignant = portee(
        role: UserRole.teacher,
        myCourseIds: {'ue1'},
        courseIdsByStudent: {
          'inscrit': {'ue1'},
          'ailleurs': {'ue2'},
        },
      );
      expect(
        enseignant.filterStudents(['inscrit', 'ailleurs'], (s) => s),
        ['inscrit'],
      );
      final etudiant = portee(
        role: UserRole.student,
        userId: 'moi',
        myCourseIds: {'ue1'},
        teacherIdByCourse: {'ue1': 'prof1'},
      );
      expect(etudiant.filterTeachers(['prof1', 'prof2'], (t) => t), ['prof1']);
    });
  });
}
