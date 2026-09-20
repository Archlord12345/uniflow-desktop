// Symptôme du 2026-09-20 : un étudiant ICT4D L1 voyait sur le desktop les
// séances de biochimie et de botanique — la grille chargeait toute la
// collection. Ces tests fixent la règle : un étudiant ne voit que sa filière
// et son niveau, rien d'autre ; sans rattachement complet, il ne voit rien.

import 'package:flutter_test/flutter_test.dart';
import 'package:uniflow/models/appwrite_models.dart';
import 'package:uniflow/models/schedule_scope.dart';

UniFlowUser _user({
  String role = 'STUDENT',
  String accountType = 'UNIVERSITY',
  String? program,
  String? level,
  String name = 'Ravel NGHOMSI',
  String id = 'u1',
  bool isSuperAdmin = false,
}) =>
    UniFlowUser(
      id: id,
      email: 'ravel@uniflow.edu',
      name: name,
      accountType: accountType,
      role: role,
      university: 'Université de Yaoundé I',
      program: program,
      level: level,
      isSuperAdmin: isSuperAdmin,
    );

AcademicSchedule _session(
  String id, {
  String program = '',
  String level = '',
  String courseId = '',
  String teacherName = '',
  String semester = 'S1',
}) =>
    AcademicSchedule(
      id: id,
      courseId: courseId,
      courseCode: id.toUpperCase(),
      dayOfWeek: 'Lundi',
      startTime: '08:00',
      endTime: '10:00',
      classroom: 'A1',
      program: program,
      level: level,
      teacherName: teacherName,
      semester: semester,
    );

void main() {
  group('scheduleScopeFor', () {
    test('étudiant : filière et niveau du profil, verrouillés', () {
      final scope = _user(program: 'ICT4D', level: 'l1')
          .let((u) => scheduleScopeFor(u, const ScheduleSelection()));
      expect(scope.kind, ScheduleScopeKind.learner);
      expect(scope.program, 'ICT4D');
      expect(scope.level, 'L1');
      expect(scope.locked, isTrue);
      expect(scope.incomplete, isFalse);
      expect(scope.empty, isFalse);
      expect(scope.label, 'ICT4D · Licence 1');
    });

    test(
        'étudiant : la sélection de la barre d\'outils ne change pas son périmètre',
        () {
      final scope = scheduleScopeFor(
        _user(program: 'ICT4D', level: 'L1'),
        const ScheduleSelection(program: 'BCH', level: 'M1'),
      );
      expect(scope.program, 'ICT4D');
      expect(scope.level, 'L1');
    });

    test('étudiant sans niveau (ou sans filière) : rien à afficher, pas tout',
        () {
      final sansNiveau =
          scheduleScopeFor(_user(program: 'ICT4D'), const ScheduleSelection());
      expect(sansNiveau.incomplete, isTrue);
      expect(sansNiveau.empty, isTrue);

      final sansFiliere =
          scheduleScopeFor(_user(level: 'L1'), const ScheduleSelection());
      expect(sansFiliere.incomplete, isTrue);
      expect(sansFiliere.empty, isTrue);
    });

    test('délégué : même règle que l\'étudiant', () {
      final scope = scheduleScopeFor(
          _user(role: 'DELEGATE', program: 'INF', level: 'L2'),
          const ScheduleSelection());
      expect(scope.kind, ScheduleScopeKind.learner);
      expect(scope.label, 'INF · Licence 2');
    });

    test('enseignant : ses séances, quel que soit son profil', () {
      final scope = scheduleScopeFor(
          _user(role: 'TEACHER', program: 'INF'), const ScheduleSelection());
      expect(scope.kind, ScheduleScopeKind.teacher);
      expect(scope.empty, isFalse);
      expect(scope.label, 'Mes séances');
    });

    test('administration : attend une sélection, puis la suit', () {
      final sansChoix =
          scheduleScopeFor(_user(role: 'ADMIN'), const ScheduleSelection());
      expect(sansChoix.kind, ScheduleScopeKind.selectable);
      expect(sansChoix.needsSelection, isTrue);
      expect(sansChoix.empty, isTrue);

      final avecChoix = scheduleScopeFor(_user(role: 'ADMIN'),
          const ScheduleSelection(program: 'MAT', level: 'm1', semester: 's1'));
      expect(avecChoix.program, 'MAT');
      expect(avecChoix.level, 'M1');
      expect(avecChoix.semester, 'S1');
      expect(avecChoix.empty, isFalse);
    });

    test('plateforme : comme l\'administration, sans établissement', () {
      final scope = scheduleScopeFor(
          _user(role: 'STUDENT', accountType: 'PLATFORM', isSuperAdmin: true),
          const ScheduleSelection(program: 'PHY'));
      expect(scope.kind, ScheduleScopeKind.selectable);
      expect(scope.program, 'PHY');
      expect(scope.level, '');
    });

    test('compte personnel : pas d\'emploi du temps universitaire', () {
      final scope = scheduleScopeFor(
          _user(accountType: 'PERSONAL'), const ScheduleSelection());
      expect(scope.kind, ScheduleScopeKind.personal);
      expect(scope.empty, isTrue);
    });
  });

  group('schedulesWithin', () {
    test('ne garde que la filière et le niveau demandés', () {
      final kept = schedulesWithin([
        _session('ict101', program: 'ICT4D', level: 'L1'),
        _session('bch311', program: 'BCH', level: 'M1'),
        _session('ict201', program: 'ict4d', level: 'l2'),
        _session('bov311', program: 'BOV', level: 'L1'),
      ], program: 'ICT4D', level: 'L1');
      expect(kept.map((s) => s.id), ['ict101']);
    });

    test(
        'ancienne séance sans filière : lue depuis le cours joint, sinon écartée',
        () {
      final courses = {
        'c-ict': AcademicCourse(
            id: 'c-ict',
            code: 'ICT102',
            name: 'Algorithmique',
            university: 'UY1',
            program: 'ICT4D',
            level: 'L1'),
        'c-bch': AcademicCourse(
            id: 'c-bch',
            code: 'BCH311',
            name: 'Enzymologie',
            university: 'UY1',
            program: 'BCH',
            level: 'M1'),
      };
      final kept = schedulesWithin([
        _session('a', courseId: 'c-ict'),
        _session('b', courseId: 'c-bch'),
        _session('c', courseId: 'inconnu'),
      ], program: 'ICT4D', level: 'L1', coursesById: courses);
      expect(kept.map((s) => s.id), ['a']);
    });
  });

  group('schedulesTaughtBy', () {
    test('par nom (orthographe approximative) ou par cours attribué', () {
      final teacher = _user(role: 'TEACHER', name: 'Dr NKOUMOU', id: 't1');
      final courses = {
        'c1': AcademicCourse(
            id: 'c1',
            code: 'PHY301',
            name: 'Mécanique',
            university: 'UY1',
            program: 'PHY',
            level: 'L3',
            teacherId: 't1'),
      };
      final kept = schedulesTaughtBy([
        _session('a', teacherName: 'Pr. Nkoumou J.'),
        _session('b', courseId: 'c1'),
        _session('c', teacherName: 'Dr Mballa'),
      ], teacher: teacher, coursesById: courses);
      expect(kept.map((s) => s.id), ['a', 'b']);
    });
  });

  test('nameTokens : sans titre, initiale, accent ni ponctuation', () {
    expect(nameTokens('Pr. Nkoumou J.'), {'nkoumou'});
    expect(nameTokens('Dr Émilie MBALLA-ONANA'), {'emilie', 'mballa', 'onana'});
    expect(nameTokens(''), isEmpty);
    expect(nameTokens(null), isEmpty);
  });

  test('semestersOf : valeurs distinctes, normalisées, triées', () {
    expect(
      semestersOf([
        _session('a', semester: 's2'),
        _session('b', semester: 'S1'),
        _session('c', semester: 'S1'),
        _session('d', semester: ''),
      ]),
      ['S1', 'S2'],
    );
  });
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
