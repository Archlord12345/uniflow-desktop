// Tableau de bord par rôle : mêmes indicateurs que le web pour le même compte.
//
// Le desktop affichait les compteurs d'administration (étudiants, enseignants,
// sessions) à tout le monde, y compris à un étudiant. Ces tests figent le
// calcul des indicateurs par rôle et vérifient que chaque rôle voit ses
// cartes, pas celles des autres.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uniflow/models/app_destination.dart';
import 'package:uniflow/models/appwrite_models.dart';
import 'package:uniflow/models/attendance_models.dart';
import 'package:uniflow/models/dashboard_overview.dart';
import 'package:uniflow/models/user_role.dart';
import 'package:uniflow/providers/navigation_provider.dart';
import 'package:uniflow/screens/dashboard_screen.dart';
import 'package:uniflow/utils/french_date.dart';
import 'package:uniflow/widgets/app_top_bar.dart';
import 'package:uniflow/widgets/data_state_view.dart';
import 'package:uniflow/widgets/stat_card.dart';

import 'layout_test_support.dart';

AcademicCourse _course(String id) => AcademicCourse(
      id: id,
      code: id.toUpperCase(),
      name: 'Cours $id',
      university: 'UY1',
      program: 'INFO',
      level: 'L1',
    );

AcademicAssignment _assignment(
  String id,
  String courseId, {
  String studentId = '',
  String? status,
  String? submittedAt,
}) =>
    AcademicAssignment(
      id: id,
      courseId: courseId,
      courseCode: courseId.toUpperCase(),
      studentId: studentId,
      title: 'Devoir $id',
      dueDate: '2026-10-01',
      status: status,
      submittedAt: submittedAt,
    );

AcademicGrade _grade(
  String studentId,
  String courseId,
  double score, {
  double maxScore = 20,
  double coefficient = 1,
}) =>
    AcademicGrade(
      id: '$studentId-$courseId-$score',
      studentId: studentId,
      courseId: courseId,
      courseCode: courseId.toUpperCase(),
      evaluationTitle: 'CC',
      score: score,
      maxScore: maxScore,
      coefficient: coefficient,
    );

StudentAttendance _attendance(String studentId,
        {required int present, required int absent, int late = 0}) =>
    StudentAttendance(
      studentId: studentId,
      name: studentId,
      matricule: studentId,
      present: present,
      absent: absent,
      late: late,
    );

UniFlowUser _user(String role) => UniFlowUser(
      id: 'u1',
      email: 'awa@uniflow.edu',
      name: 'Awa Ndiaye',
      accountType: 'UNIVERSITY',
      role: role,
      username: 'awa',
    );

void main() {
  setUpAll(loadTestEnv);

  group('DashboardOverview.compute', () {
    final courses = [_course('c1'), _course('c2')];

    test('apprenant : devoirs à rendre, moyenne pondérée, sa présence', () {
      final overview = DashboardOverview.compute(
        role: UserRole.student,
        userId: 'u1',
        courses: courses,
        assignments: [
          // Adressé à la promotion, non rendu : compte.
          _assignment('a1', 'c1'),
          // Adressé à moi, rendu : ne compte plus.
          _assignment('a2', 'c1',
              studentId: 'u1', submittedAt: '2026-09-20T10:00:00Z'),
          // Adressé à moi, statut fermé : ne compte plus.
          _assignment('a3', 'c2', studentId: 'u1', status: 'GRADED'),
          // Adressé à quelqu'un d'autre : pas le mien.
          _assignment('a4', 'c2', studentId: 'u2'),
          // Hors de mes cours : ignoré.
          _assignment('a5', 'autre'),
        ],
        grades: [
          _grade('u1', 'c1', 10, coefficient: 1),
          _grade('u1', 'c2', 16, coefficient: 3),
          // Sur 10 : ramenée à 20 (8/10 → 16/20).
          _grade('u1', 'c2', 8, maxScore: 10, coefficient: 0),
          // La note d'un autre étudiant n'entre pas dans ma moyenne.
          _grade('u2', 'c1', 2),
        ],
        attendance: [
          _attendance('u1', present: 9, absent: 1),
          _attendance('u2', present: 0, absent: 10),
        ],
        studentCount: 42,
      );

      expect(overview.courseCount, 2);
      expect(overview.assignmentCount, 1);
      expect(overview.gradeCount, 3);
      // (10×1 + 16×3 + 16×1) / (1 + 3 + 1) = 74 / 5 = 14,8 — le coefficient
      // 0 vaut 1, sinon la note disparaîtrait de la moyenne en silence.
      expect(overview.averageOn20, closeTo(14.8, 0.001));
      expect(overview.averageLabel, '14,8/20');
      expect(overview.attendanceRate, closeTo(0.9, 0.001));
      expect(overview.attendanceLabel, '90 %');
    });

    test('enseignant : tous les devoirs de ses cours, présence moyenne', () {
      final overview = DashboardOverview.compute(
        role: UserRole.teacher,
        userId: 't1',
        courses: courses,
        assignments: [
          _assignment('a1', 'c1'),
          _assignment('a2', 'c1', studentId: 'u1', status: 'GRADED'),
          _assignment('a3', 'autre'),
        ],
        grades: [
          _grade('u1', 'c1', 12),
          _grade('u2', 'c2', 8),
          _grade('u3', 'autre', 20),
        ],
        attendance: [
          _attendance('u1', present: 10, absent: 0),
          _attendance('u2', present: 5, absent: 5),
          // Aucun enregistrement : n'abaisse pas la moyenne à tort.
          _attendance('u3', present: 0, absent: 0),
        ],
        studentCount: 2,
      );

      expect(overview.assignmentCount, 2);
      expect(overview.gradeCount, 2);
      expect(overview.averageOn20, closeTo(10, 0.001));
      expect(overview.attendanceRate, closeTo(0.75, 0.001));
      expect(overview.studentCount, 2);
    });

    test('sans donnée : « — » plutôt que 0 %', () {
      final overview = DashboardOverview.compute(
        role: UserRole.student,
        userId: 'u1',
        courses: const [],
        assignments: const [],
        grades: const [],
        attendance: const [],
        studentCount: 0,
      );
      expect(overview.averageOn20, isNull);
      expect(overview.attendanceRate, isNull);
      expect(overview.averageLabel, '—');
      expect(overview.attendanceLabel, '—');
    });
  });

  group('french_date', () {
    test('date longue en français', () {
      expect(formatLongDate(DateTime(2026, 9, 21)), 'lundi 21 septembre 2026');
      expect(formatLongDate(DateTime(2026, 1, 4)), 'dimanche 4 janvier 2026');
    });

    test('salut selon l’heure', () {
      expect(greetingFor(DateTime(2026, 9, 21, 8)), 'Bonjour');
      expect(greetingFor(DateTime(2026, 9, 21, 14)), 'Bon après-midi');
      expect(greetingFor(DateTime(2026, 9, 21, 21)), 'Bonsoir');
    });
  });

  group('DashboardScreen', () {
    Future<void> pumpAs(WidgetTester tester, String role) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(host(const DashboardScreen(), user: _user(role)));
      // Les providers asynchrones se résolvent en quelques micro-tâches ; la
      // vue de chargement anime Uni en boucle, donc pas de `pumpAndSettle`.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets(
        'étudiant : ses quatre indicateurs, pas ceux de l’administration',
        (tester) async {
      await pumpAs(tester, 'STUDENT');

      expect(find.byType(AppTopBar), findsOneWidget);
      expect(find.textContaining('Awa'), findsOneWidget);
      expect(find.textContaining('Étudiant ·'), findsOneWidget);

      expect(find.text('Mes cours'), findsOneWidget);
      expect(find.text('Devoirs à rendre'), findsOneWidget);
      expect(find.text('Moyenne générale'), findsOneWidget);
      expect(find.text('Taux de présence'), findsOneWidget);
      expect(find.byType(StatCard), findsNWidgets(4));

      expect(find.text('Étudiants'), findsNothing);
      expect(find.text('Inscriptions par mois'), findsNothing);
      expect(find.text('Activités récentes'), findsNothing);

      // Accès rapide filtré par rôle : pas d'écran d'administration.
      expect(find.text('Accès rapide'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('quick-emploi-du-temps')), findsOneWidget);
      expect(find.byKey(const ValueKey('quick-comptes')), findsNothing);
    });

    testWidgets('enseignant : cours, étudiants, devoirs créés, notes saisies',
        (tester) async {
      await pumpAs(tester, 'TEACHER');

      expect(find.text('Mes cours'), findsOneWidget);
      expect(find.text('Mes étudiants'), findsOneWidget);
      expect(find.text('Devoirs créés'), findsOneWidget);
      expect(find.text('Notes saisies'), findsOneWidget);
      expect(find.byKey(const ValueKey('quick-presences')), findsOneWidget);
    });

    testWidgets('administrateur : compteurs globaux, graphiques, activités',
        (tester) async {
      await pumpAs(tester, 'ADMIN');

      // « Enseignants » apparaît aussi comme accès rapide : on cible les
      // libellés des cartes.
      Finder card(String label) => find.descendant(
          of: find.byType(StatCard), matching: find.text(label));
      expect(card('Étudiants'), findsOneWidget);
      expect(card('Enseignants'), findsOneWidget);
      expect(card('Cours actifs'), findsOneWidget);
      expect(card('Sessions'), findsOneWidget);
      expect(find.textContaining('Administrateur ·'), findsOneWidget);

      // Les statistiques simulées sont vides : « — », jamais « null ».
      expect(find.text('null'), findsNothing);
      expect(find.text('—'), findsWidgets);

      // Les graphiques et l'activité sans donnée passent par l'état vide commun.
      expect(find.byType(DataEmptyView), findsNWidgets(3));
      expect(find.byKey(const ValueKey('quick-comptes')), findsOneWidget);
    });

    testWidgets('un accès rapide change la destination courante',
        (tester) async {
      await pumpAs(tester, 'STUDENT');

      final element = tester.element(find.byType(DashboardScreen));
      final container = ProviderScope.containerOf(element);
      expect(container.read(currentDestinationProvider), isNull);

      await tester.tap(find.byKey(const ValueKey('quick-notes')));
      await tester.pump();

      expect(container.read(currentDestinationProvider), AppDestination.grades);
    });

    testWidgets('sans nom : le salut reste seul, sans virgule orpheline',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(host(
        const DashboardScreen(),
        user: UniFlowUser(
          id: 'u1',
          email: 'x@uniflow.edu',
          name: '',
          accountType: 'UNIVERSITY',
          role: 'STUDENT',
          username: 'x',
        ),
      ));
      await tester.pump();

      expect(find.textContaining(', '), findsNothing);
      expect(find.byType(AppTopBar), findsOneWidget);
    });
  });
}
