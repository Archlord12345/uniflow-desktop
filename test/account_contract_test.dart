// Contrat de comptes commun aux trois clients, vérifié sans réseau.
//
// Symptôme d'origine : le desktop lisait le rôle dans `users.role`, un champ
// que n'importe quel client peut écrire. Le rôle vient désormais des labels
// Appwrite du compte (`ADMIN`, `TEACHER`, `DELEGATE`, `superadmin`), posés
// côté serveur uniquement.

import 'package:appwrite/models.dart' as models;
import 'package:flutter_test/flutter_test.dart';

import 'package:uniflow/models/reference_models.dart';
import 'package:uniflow/models/user_role.dart';
import 'package:uniflow/providers/directory_provider.dart';
import 'package:uniflow/models/appwrite_models.dart';
import 'package:uniflow/repositories/auth_repository.dart';
import 'package:uniflow/services/uniflow_api.dart';

models.User _account(List<String> labels, {Map<String, dynamic> prefs = const {}}) {
  return models.User.fromMap({
    '\$id': 'u1',
    '\$createdAt': '',
    '\$updatedAt': '',
    'name': 'Test',
    'registration': '',
    'status': true,
    'labels': labels,
    'passwordUpdate': '',
    'email': 'test@uniflow.test',
    'phone': '',
    'emailVerification': true,
    'phoneVerification': false,
    'mfa': false,
    'prefs': {'data': prefs},
    'targets': <dynamic>[],
    'accessedAt': '',
  });
}

void main() {
  group('UserRole.fromLabels', () {
    test('lit les labels tels que la base les porte (vérifié le 2026-09-20)', () {
      expect(UserRole.fromLabels(['ADMIN', 'superadmin']), UserRole.admin);
      expect(UserRole.fromLabels(['ADMIN']), UserRole.admin);
      expect(UserRole.fromLabels(['TEACHER']), UserRole.teacher);
      expect(UserRole.fromLabels(['DELEGATE']), UserRole.delegate);
      expect(UserRole.fromLabels([]), UserRole.student);
    });

    test('est insensible à la casse et ignore les labels inconnus', () {
      expect(UserRole.fromLabels(['teacher']), UserRole.teacher);
      expect(UserRole.fromLabels(['beta', 'Admin ']), UserRole.admin);
      expect(UserRole.fromLabels(['superadmin']), UserRole.student);
      expect(UserRole.fromLabels(['role:TEACHER']), UserRole.teacher);
    });

    test('le plus privilégié gagne quand plusieurs labels de rôle coexistent', () {
      expect(UserRole.fromLabels(['TEACHER', 'ADMIN']), UserRole.admin);
      expect(UserRole.fromLabels(['STUDENT', 'DELEGATE']), UserRole.delegate);
    });

    test('le champ users.role ne sert de repli que sans aucun label', () {
      expect(UserRole.fromLabels([], fallbackRole: 'TEACHER'), UserRole.teacher);
      // Un label posé mais inconnu ne rend pas la main au document : le
      // serveur a explicitement parlé, même si on ne le comprend pas.
      expect(UserRole.fromLabels(['beta'], fallbackRole: 'ADMIN'), UserRole.student);
      expect(UserRole.fromLabels(['TEACHER'], fallbackRole: 'ADMIN'), UserRole.teacher);
    });

    test('superadmin est un label distinct du rôle', () {
      expect(UserRole.hasSuperAdminLabel(['ADMIN', 'superadmin']), isTrue);
      expect(UserRole.hasSuperAdminLabel(['ADMIN']), isFalse);
      expect(UserRole.hasSuperAdminLabel(['SUPERADMIN']), isTrue);
    });
  });

  group('AuthRepository.buildUser', () {
    test('kernel@forge.codes : ADMIN + superadmin', () {
      final user = AuthRepository.buildUser(
        _account(['ADMIN', 'superadmin']),
        {'role': 'STUDENT', 'accountType': 'UNIVERSITY'},
      );
      expect(user.userRole, UserRole.admin);
      expect(user.isSuperAdmin, isTrue);
      expect(user.role, 'ADMIN');
    });

    test('un étudiant sans label reste étudiant même si le document dit ADMIN', () {
      final user = AuthRepository.buildUser(
        _account(['beta']),
        {'role': 'ADMIN'},
      );
      expect(user.userRole, UserRole.student);
      expect(user.isSuperAdmin, isFalse);
    });

    test('le type de compte vient des préférences avant le document', () {
      final user = AuthRepository.buildUser(
        _account([], prefs: {'uniflowAccountType': 'PERSONAL'}),
        {'accountType': 'UNIVERSITY'},
      );
      expect(user.accountKind, AccountType.personal);
      expect(user.isPersonal, isTrue);
    });

    test('un compte sans document users entre quand même', () {
      final user = AuthRepository.buildUser(_account(['TEACHER']), const {});
      expect(user.userRole, UserRole.teacher);
      expect(user.name, 'Test');
      expect(user.accountKind, AccountType.university);
    });
  });

  group('validateRegistration', () {
    RegistrationRequest request({
      AccountType type = AccountType.university,
      String password = 'motdepasse',
      String? program = 'ICT4D',
    }) =>
        RegistrationRequest(
          name: 'Ada Lovelace',
          email: 'ada@uniflow.test',
          password: password,
          accountType: type,
          university: 'Université',
          program: program,
          level: 'L1',
        );

    test('un compte universitaire est toujours STUDENT', () {
      expect(request().role, 'STUDENT');
      expect(request().toProfileDocument('x')['role'], 'STUDENT');
      expect(request().toProfileDocument('x')['accountType'], 'UNIVERSITY');
    });

    test('exige université, filière et niveau pour un compte universitaire', () {
      expect(validateRegistration(request()), isNull);
      expect(validateRegistration(request(program: '')), contains('filière'));
      expect(validateRegistration(request(type: AccountType.personal, program: '')), isNull);
    });

    test('applique la longueur minimale d\'Appwrite', () {
      expect(validateRegistration(request(password: 'court')), contains('8'));
    });

    test('le document personnel ne porte pas de champs de cursus', () {
      final doc = request(type: AccountType.personal).toProfileDocument('x');
      expect(doc.containsKey('program'), isFalse);
      expect(doc['accountType'], 'PERSONAL');
    });
  });

  group('parseRecoveryLink', () {
    test('extrait userId et secret d\'un lien Appwrite', () {
      final parsed = parseRecoveryLink(
        'https://uniflow.kernelforge.codes/reset-password?userId=abc&secret=s3cr3t&expire=2026',
      );
      expect(parsed?.userId, 'abc');
      expect(parsed?.secret, 's3cr3t');
    });

    test('accepte la seule chaîne de requête et refuse un lien incomplet', () {
      expect(parseRecoveryLink('userId=a&secret=b')?.secret, 'b');
      expect(parseRecoveryLink('https://x/reset?userId=a'), isNull);
      expect(parseRecoveryLink(''), isNull);
    });
  });

  group('decodeApiResponse', () {
    test('un 404 sans JSON désigne un chemin inconnu du routeur', () {
      expect(
        () => decodeApiResponse('', httpStatus: 404, path: '/inconnu'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'NOT_FOUND')),
      );
    });

    test('le message de la Function est conservé tel quel', () {
      expect(
        () => decodeApiResponse('{"ok":false,"code":"SCOPE_DENIED","message":"Hors périmètre"}'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Hors périmètre')),
      );
    });

    test('renvoie la charge utile quand ok vaut true', () {
      expect(decodeApiResponse('{"ok":true,"items":[1]}')['items'], [1]);
    });
  });

  group('Référentiel académique', () {
    test('parseLevels nettoie et ordonne selon la déclaration', () {
      expect(AcademicProgram.parseLevels('L1,L2,L3'), ['L1', 'L2', 'L3']);
      expect(AcademicProgram.parseLevels(' l1 ; L2,,L1 '), ['L1', 'L2']);
      expect(AcademicProgram.parseLevels(''), isEmpty);
    });

    test('la cascade université → faculté → filière → niveau suit les codes', () {
      const reference = AcademicReference(
        universities: [University(id: '1', code: 'UY1', name: 'Université de Yaoundé I')],
        faculties: [
          Faculty(id: 'f', universityCode: 'UY1', code: 'FS', name: 'Faculté des Sciences'),
          Faculty(id: 'g', universityCode: 'UY2', code: 'FS', name: 'Autre'),
        ],
        programs: [
          AcademicProgram(id: 'p', universityCode: 'UY1', facultyCode: 'FS', code: 'ICT4D', name: 'ICT4D', levels: ['L1', 'L2', 'L3']),
          AcademicProgram(id: 'q', universityCode: 'UY1', facultyCode: 'FS', code: 'PHYS', name: 'Physique', levels: ['L1', 'M1']),
          AcademicProgram(id: 'r', universityCode: 'UY1', facultyCode: 'FALSH', code: 'HIST', name: 'Histoire', levels: ['L1']),
        ],
      );
      expect(reference.facultiesOf('UY1').map((f) => f.code), ['FS']);
      expect(reference.programsOf('UY1', facultyCode: 'FS').map((p) => p.code), ['ICT4D', 'PHYS']);
      expect(reference.levelsOf('ICT4D'), ['L1', 'L2', 'L3']);
      expect(reference.levelsOf(null), ['L1', 'L2', 'L3', 'M1']);
      expect(reference.universityByName('Université de Yaoundé I')?.code, 'UY1');
    });

    test('ProgramOptions découvre filières et niveaux depuis les cours', () {
      final options = ProgramOptions.fromCourses([
        AcademicCourse(id: 'a', code: 'ICT101', name: 'x', university: 'UY1', program: 'ICT4D', level: 'L1'),
        AcademicCourse(id: 'b', code: 'ICT201', name: 'y', university: 'UY1', program: 'ICT4D', level: 'L2'),
        AcademicCourse(id: 'c', code: 'PHY101', name: 'z', university: 'UY1', program: 'PHYS', level: 'M1'),
      ]);
      expect(options.programs, ['ICT4D', 'PHYS']);
      expect(options.levels, ['L1', 'L2', 'M1']);
      expect(options.levelsByProgram['ICT4D'], ['L1', 'L2']);
    });
  });
}
