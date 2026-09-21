// Fixtures et harnais partagés par les tests de mise en page du desktop.
//
// Chaque provider réseau est remplacé par une valeur vide : un test de mise en
// page ne doit dépendre d'aucun accès à Appwrite. Seuls les providers qui ne
// font qu'instancier un objet (les dépôts) restent réels — les écrans ne les
// interrogent jamais, puisqu'on court-circuite les providers qui les appellent.

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uniflow/models/appwrite_models.dart';
import 'package:uniflow/models/attendance_models.dart';
import 'package:uniflow/models/classroom.dart';
import 'package:uniflow/models/dashboard_models.dart';
import 'package:uniflow/models/program_tree.dart';
import 'package:uniflow/models/schedule_event.dart';
import 'package:uniflow/models/student.dart';
import 'package:uniflow/models/teacher.dart';
import 'package:uniflow/models/teaching_unit.dart';
import 'package:uniflow/models/team_member.dart';
import 'package:uniflow/services/conference/attendance_store.dart';
import 'package:uniflow/services/conference/conference_models.dart';
import 'package:uniflow/providers/analytics_provider.dart';
import 'package:uniflow/providers/attendance_provider.dart';
import 'package:uniflow/providers/auth_provider.dart';
import 'package:uniflow/providers/conference_provider.dart';
import 'package:uniflow/providers/directory_provider.dart';
import 'package:uniflow/providers/appwrite_provider.dart';
import 'package:uniflow/providers/program_provider.dart';
import 'package:uniflow/models/reference_models.dart';
import 'package:uniflow/repositories/academic_repository.dart';
import 'package:uniflow/repositories/management_repository.dart';
import 'package:uniflow/repositories/personal_repository.dart';
import 'package:uniflow/screens/academic_management_screens.dart';
import 'package:uniflow/screens/notifications_screen.dart';
import 'package:uniflow/repositories/reference_repository.dart';
import 'package:uniflow/services/appwrite_service.dart';
import 'package:uniflow/services/uniflow_api.dart';
import 'package:uniflow/providers/schedule_provider.dart';
import 'package:uniflow/repositories/messaging_repository.dart';
import 'package:uniflow/repositories/team_repository.dart';
import 'package:uniflow/screens/dashboard_screen.dart';
import 'package:uniflow/theme/app_theme.dart';

/// Charge le `.env` déclaré en asset.
///
/// Les dépôts lisent l'endpoint Appwrite à leur construction ; sans ce
/// chargement, `dotenv.env` est vide et l'instanciation échoue avant même que
/// le premier écran soit peint.
Future<void> loadTestEnv() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (!dotenv.isInitialized) {
    await dotenv.load(fileName: '.env');
  }
}

UniFlowUser testUser() => UniFlowUser(
      id: 'u1',
      email: 'ravel@uniflow.edu',
      name: 'NGHOMSI RAVEL',
      accountType: 'UNIVERSITY',
      role: 'ADMIN',
      username: 'ravel',
    );

/// Équipe de test, avec les cas qui cassent une mise en page : un nom très
/// long, un membre sans photo, un membre sans pastille ni pseudo GitHub, et un
/// membre de chaque équipe pour que les quatre tuiles de statistiques et les
/// filtres aient tous quelque chose à afficher.
List<TeamMember> equipeDeTest() => [
      TeamMember(
        id: 'ravel',
        slug: 'ravel',
        name: 'NGHOMSI FEUKOUO RAVEL',
        github: 'Archlord12345',
        email: 'ravelnghomsi@gmail.com',
        team: 'Leadership',
        subTeam: 'Architecture & Direction',
        role: 'Chef de projet & Architecte',
        badge: 'Lead Architect',
        accent: 'blue',
        avatarFileId: '',
        displayOrder: 0,
      ),
      TeamMember(
        id: 'aliya',
        slug: 'aliya',
        name: 'Aliyatou Rachid Oumou Tourab',
        github: 'aliya-nadi',
        email: 'oumou.aliyatou@facsciences-uy1.cm',
        team: 'Frontend',
        subTeam: 'Frontend Desktop & Web',
        role: 'Frontend Developer',
        badge: 'Web Desktop',
        accent: 'purple',
        avatarFileId: '',
        displayOrder: 1,
      ),
      TeamMember(
        id: 'sans-rien',
        slug: 'sans-rien',
        name: 'Membre Sans Photo Ni Pseudo',
        github: '',
        email: '',
        team: 'Backend',
        subTeam: '',
        role: 'Backend Developer',
        badge: '',
        accent: 'inconnue',
        avatarFileId: '',
        displayOrder: 2,
      ),
    ];

List<Override> _overrides(UniFlowUser user) => [
      currentUserProvider.overrideWith((ref) => user),
      sessionCheckProvider.overrideWith((ref) async {}),
      directoryProvider.overrideWith((ref) async => <AcademicDirectoryEntry>[]),
      studentsProvider.overrideWith((ref) async => <Student>[]),
      teachersProvider.overrideWith((ref) async => <Teacher>[]),
      teachingUnitsProvider.overrideWith((ref) async => <TeachingUnit>[]),
      classroomsProvider.overrideWith((ref) async => <Classroom>[]),
      programTreeProvider.overrideWith((ref) async => <FacultyNode>[]),
      // La page Équipe lit la collection `team_members` : sans cette
      // neutralisation, le test de mise en page lancerait un appel réseau.
      teamMembersProvider.overrideWith((ref) async => equipeDeTest()),
      scheduleWeekProvider.overrideWith(
        (ref) async =>
            ScheduleWeek(weekStart: DateTime(2026, 9, 14), events: const []),
      ),
      studentAttendanceProvider
          .overrideWith((ref) async => <StudentAttendance>[]),
      gradeStatsProvider.overrideWith((ref) async => null),
      conversationsProvider.overrideWith((ref) async => <Conversation>[]),
      activeConferencesProvider
          .overrideWith((ref) async => <DiscoveredConference>[]),
      // Le panneau « Présence » relit les feuilles du poste : le test ne doit
      // ni dépendre du dossier personnel de qui le lance, ni y écrire.
      attendanceStoreProvider.overrideWithValue(InMemoryAttendanceStore()),
      dashboardStatsProvider.overrideWith((ref) async => <String, dynamic>{}),
      dashboardEnrollmentsProvider
          .overrideWith((ref) async => <MonthlyCount>[]),
      dashboardAttendanceProvider.overrideWith((ref) async => null),
      dashboardActivityProvider.overrideWith((ref) async => <ActivityEntry>[]),
      personalSubjectsProvider.overrideWith((ref) async => <PersonalSubject>[]),
      scopedCoursesProvider.overrideWith((ref) async => <AcademicCourse>[]),
      enrollmentsProvider.overrideWith((ref) async => <AcademicEnrollment>[]),
      notificationsProvider.overrideWith((ref) async => <AppNotification>[]),
      libraryProvider.overrideWith((ref) async => <LibraryItem>[]),
      programOptionsProvider
          .overrideWith((ref) async => ProgramOptions.fromCourses(const [])),
      managedAccountsProvider
          .overrideWith((ref, filter) async => <ManagedAccount>[]),
      // Référentiel avec une cascade complète : l'inscription doit être mesurée
      // avec ses quatre listes déroulantes, pas avec la saisie libre de secours.
      academicReferenceProvider
          .overrideWith((ref) async => referentielDeTest()),
    ];

AcademicReference referentielDeTest() => const AcademicReference(
      universities: [
        University(
            id: 'u', code: 'UY1', name: 'Université de test', shortName: 'UT')
      ],
      faculties: [
        Faculty(
            id: 'f', universityCode: 'UY1', code: 'FS', name: 'Faculté de test')
      ],
      programs: [
        AcademicProgram(
          id: 'p',
          universityCode: 'UY1',
          facultyCode: 'FS',
          code: 'TEST',
          name: 'Filière de test',
          levels: ['L1', 'L2', 'L3'],
        ),
      ],
      classrooms: [
        ClassroomRef(
            id: 'c',
            universityCode: 'UY1',
            code: 'A101',
            name: 'Salle de test',
            capacity: 40),
      ],
    );

/// Dépôt académique simulé.
///
/// Plusieurs écrans lisent le dépôt directement (`ref.read(academicRepository
/// Provider).getAssignments()`), sans passer par un provider `FutureProvider`
/// que l'on pourrait remplacer. Sans cette simulation, la construction de
/// l'écran déclenchait un véritable appel HTTP vers Appwrite : la requête
/// restait en vol à la fin du test et Flutter échouait sur
/// « A Timer is still pending even after the widget tree was disposed ».
class FakeAcademicRepository extends AcademicRepository {
  FakeAcademicRepository(super.service);

  @override
  Future<List<AcademicGrade>> getAllGrades() async => <AcademicGrade>[];

  @override
  Future<List<AcademicAssignment>> getAssignments() async =>
      <AcademicAssignment>[];

  @override
  Future<Map<String, dynamic>> getGlobalStats() async => <String, dynamic>{};

  @override
  Future<List<MonthlyCount>> getEnrollmentsByMonth({int months = 6}) async =>
      <MonthlyCount>[];

  @override
  Future<AttendanceBreakdown?> getAttendanceBreakdown(
          {int limit = 5000}) async =>
      null;

  @override
  Future<List<ActivityEntry>> getRecentActivity({int limit = 6}) async =>
      <ActivityEntry>[];
}

/// Messagerie simulée, pour la même raison.
class FakeMessagingRepository extends MessagingRepository {
  FakeMessagingRepository(super.api);

  @override
  Future<List<ChatContact>> searchContacts(String query) async =>
      <ChatContact>[];

  @override
  Future<int> markRead(String conversationId) async => 0;
}

/// Enveloppe un écran dans son `ProviderScope`, avec le thème de l'application.
///
/// Le `Scaffold` n'est pas décoratif : dans l'application, ces écrans sont le
/// `body` du `Scaffold` de `MainShell`, et c'est lui qui fournit le `Material`
/// attendu par les `InkWell`, `TextField` et `DropdownButton`. Les peindre nus
/// produisait une avalanche de « No Material widget found » sans rapport avec
/// la mise en page que l'on veut mesurer.
///
/// `user` : compte connecté simulé (administrateur par défaut). Les écrans par
/// rôle — tableau de bord, menu — se testent en passant un étudiant ou un
/// enseignant.
Widget host(
  Widget child, {
  List<Override> overrides = const [],
  UniFlowUser? user,
}) {
  final service = AppwriteService();
  return ProviderScope(
    overrides: [
      ..._overrides(user ?? testUser()),
      ...overrides,
      appwriteServiceProvider.overrideWithValue(service),
      academicRepositoryProvider
          .overrideWithValue(FakeAcademicRepository(service)),
      messagingRepositoryProvider
          .overrideWithValue(FakeMessagingRepository(UniFlowApi(service))),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: child),
    ),
  );
}
