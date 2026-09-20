// Déconnexion et suppression de compte : ces deux flux touchent au serveur,
// au serveur de réunion et aux caches. Ils sont exercés avec un dépôt
// d'authentification simulé qui enregistre les appels.

import 'dart:io';

import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uniflow/providers/appwrite_provider.dart';
import 'package:uniflow/providers/auth_provider.dart';
import 'package:uniflow/providers/session_provider.dart';
import 'package:uniflow/repositories/auth_repository.dart';
import 'package:uniflow/screens/login_screen.dart';
import 'package:uniflow/screens/session_flow.dart';
import 'package:uniflow/services/appwrite_service.dart';
import 'package:uniflow/services/session_snapshot.dart';
import 'package:uniflow/services/uniflow_api.dart';
import 'package:uniflow/theme/app_theme.dart';
import 'package:uniflow/widgets/motion.dart';

import 'layout_test_support.dart';

class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository(AppwriteService service)
      : super(service, UniFlowApi(service));

  int logoutCalls = 0;
  bool logoutThrows = false;
  String acceptedPassword = 'bon-mot-de-passe';
  int deleteCalls = 0;
  ApiException? deleteError;

  @override
  Future<void> logout() async {
    logoutCalls++;
    if (logoutThrows) {
      throw AppwriteException('Session expirée', 401, 'user_session_not_found');
    }
  }

  @override
  Future<void> verifyPassword(String email, String password) async {
    if (password != acceptedPassword) {
      throw AppwriteException(
          'Invalid credentials', 401, 'user_invalid_credentials');
    }
  }

  @override
  Future<void> deleteOwnAccount() async {
    deleteCalls++;
    final error = deleteError;
    if (error != null) throw error;
  }
}

ProviderContainer conteneur(FakeAuthRepository repo,
    {bool superAdmin = false}) {
  final service = AppwriteService();
  final store = InMemorySessionSnapshotStore();
  return ProviderContainer(overrides: [
    appwriteServiceProvider.overrideWithValue(service),
    authRepositoryProvider.overrideWithValue(repo),
    currentUserProvider
        .overrideWith((ref) => testUser().copyWith(isSuperAdmin: superAdmin)),
    sessionControllerProvider.overrideWith(
      (ref) => SessionController(ref, snapshotStore: store),
    ),
  ]);
}

void main() {
  setUpAll(() async {
    await loadTestEnv();
    // Le client Appwrite interroge `path_provider` à sa construction (jar de
    // cookies) ; sans doublure, l'erreur asynchrone fait échouer les tests
    // unitaires hors `testWidgets`.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => Directory.systemTemp.path,
    );
  });

  group('SessionController.signOut', () {
    test('ferme la session, tolère une session déjà expirée et vide le profil',
        () async {
      final repo = FakeAuthRepository(AppwriteService())..logoutThrows = true;
      final container = conteneur(repo);
      addTearDown(container.dispose);

      expect(container.read(currentUserProvider), isNotNull);
      await container.read(sessionControllerProvider).signOut();

      expect(repo.logoutCalls, 1);
      expect(container.read(currentUserProvider), isNull);
    });
  });

  group('SessionController.deleteOwnAccount', () {
    test('refuse le superadmin sans appeler le serveur', () async {
      final repo = FakeAuthRepository(AppwriteService());
      final container = conteneur(repo, superAdmin: true);
      addTearDown(container.dispose);

      final result = await container
          .read(sessionControllerProvider)
          .deleteOwnAccount(password: repo.acceptedPassword);

      expect(result.outcome, DeleteAccountOutcome.refusedSuperAdmin);
      expect(result.message, kSuperAdminDeletionRefused);
      expect(repo.deleteCalls, 0);
      expect(container.read(currentUserProvider), isNotNull);
    });

    test('mauvais mot de passe : rien n\'est supprimé', () async {
      final repo = FakeAuthRepository(AppwriteService());
      final container = conteneur(repo);
      addTearDown(container.dispose);

      final result = await container
          .read(sessionControllerProvider)
          .deleteOwnAccount(password: 'faux');

      expect(result.outcome, DeleteAccountOutcome.wrongPassword);
      expect(repo.deleteCalls, 0);
    });

    test('service /account absent (404) : message explicite, session conservée',
        () async {
      final repo = FakeAuthRepository(AppwriteService())
        ..deleteError =
            const ApiException('introuvable', code: 'NOT_FOUND', status: 404);
      final container = conteneur(repo);
      addTearDown(container.dispose);

      final result = await container
          .read(sessionControllerProvider)
          .deleteOwnAccount(password: repo.acceptedPassword);

      expect(result.outcome, DeleteAccountOutcome.serviceUnavailable);
      expect(result.message, contains('pas encore disponible'));
      expect(container.read(currentUserProvider), isNotNull);
    });

    test('erreur 500 : signalée comme indisponibilité du serveur', () async {
      final repo = FakeAuthRepository(AppwriteService())
        ..deleteError =
            const ApiException('boom', code: 'INTERNAL', status: 500);
      final container = conteneur(repo);
      addTearDown(container.dispose);

      final result = await container
          .read(sessionControllerProvider)
          .deleteOwnAccount(password: repo.acceptedPassword);

      expect(result.outcome, DeleteAccountOutcome.serviceUnavailable);
    });

    test('succès : le compte est supprimé et le poste est déconnecté',
        () async {
      final repo = FakeAuthRepository(AppwriteService());
      final container = conteneur(repo);
      addTearDown(container.dispose);

      final result = await container
          .read(sessionControllerProvider)
          .deleteOwnAccount(password: repo.acceptedPassword);

      expect(result.succeeded, isTrue);
      expect(repo.deleteCalls, 1);
      expect(container.read(currentUserProvider), isNull);
    });
  });

  group('Flux d\'interface', () {
    Widget appli(FakeAuthRepository repo, Widget body,
        {bool superAdmin = false}) {
      final service = AppwriteService();
      return ProviderScope(
        overrides: [
          appwriteServiceProvider.overrideWithValue(service),
          authRepositoryProvider.overrideWithValue(repo),
          currentUserProvider.overrideWith(
              (ref) => testUser().copyWith(isSuperAdmin: superAdmin)),
          sessionCheckProvider.overrideWith((ref) async {}),
          sessionControllerProvider.overrideWith(
            (ref) => SessionController(ref,
                snapshotStore: InMemorySessionSnapshotStore()),
          ),
        ],
        child:
            MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: body)),
      );
    }

    testWidgets('« Se déconnecter » ramène à l\'écran de connexion',
        (tester) async {
      motionReduced.value = true;
      addTearDown(() => motionReduced.value = false);
      final repo = FakeAuthRepository(AppwriteService());
      await tester
          .pumpWidget(appli(repo, const Center(child: SignOutButton())));

      await tester.tap(find.text('Se déconnecter'));
      await tester.pumpAndSettle();

      expect(repo.logoutCalls, 1);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('suppression : mot de passe, mot SUPPRIMER, écran de succès',
        (tester) async {
      motionReduced.value = true;
      addTearDown(() => motionReduced.value = false);
      final repo = FakeAuthRepository(AppwriteService());
      await tester.pumpWidget(appli(
        repo,
        Consumer(
          builder: (context, ref, _) => Center(
            child: TextButton(
              onPressed: () => showDeleteAccountFlow(context, ref),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      expect(find.text('Supprimer mon compte'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('delete-account-password')),
          repo.acceptedPassword);
      await tester.tap(find.byKey(const Key('delete-account-confirm')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('delete-account-keyword')), findsOneWidget);

      // Mot mal recopié : on reste dans le dialogue, rien n'est supprimé.
      await tester.enterText(
          find.byKey(const Key('delete-account-keyword')), 'supprimer');
      await tester.tap(find.byKey(const Key('delete-account-confirm')));
      await tester.pumpAndSettle();
      expect(repo.deleteCalls, 0);
      expect(find.textContaining('Recopiez exactement'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('delete-account-keyword')),
          kDeleteAccountKeyword);
      await tester.tap(find.byKey(const Key('delete-account-confirm')));
      await tester.pumpAndSettle();

      expect(repo.deleteCalls, 1);
      expect(find.text('Compte supprimé'), findsOneWidget);
    });

    testWidgets('superadmin : refus explicite, dialogue conservé',
        (tester) async {
      motionReduced.value = true;
      addTearDown(() => motionReduced.value = false);
      final repo = FakeAuthRepository(AppwriteService());
      await tester.pumpWidget(appli(
        repo,
        Consumer(
          builder: (context, ref, _) => Center(
            child: TextButton(
              onPressed: () => showDeleteAccountFlow(context, ref),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
        superAdmin: true,
      ));

      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('delete-account-password')),
          repo.acceptedPassword);
      await tester.tap(find.byKey(const Key('delete-account-confirm')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('delete-account-keyword')),
          kDeleteAccountKeyword);
      await tester.tap(find.byKey(const Key('delete-account-confirm')));
      await tester.pumpAndSettle();

      expect(repo.deleteCalls, 0);
      expect(find.text(kSuperAdminDeletionRefused), findsOneWidget);
    });
  });
}
