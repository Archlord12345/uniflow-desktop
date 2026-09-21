// Rattrapage du raccordement académique à la connexion.
//
// Symptôme (2026-09-21) : un étudiant inscrit avant la publication des cours
// de sa filière (ICT4D L2, L3) n'avait aucune inscription aux cours, donc un
// tableau de bord vide, et rien ne le rattrapait. La connexion rejoue
// désormais `provision` pour les apprenants universitaires — et seulement eux.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uniflow/models/appwrite_models.dart';
import 'package:uniflow/repositories/auth_repository.dart';
import 'package:uniflow/services/appwrite_service.dart';
import 'package:uniflow/services/uniflow_api.dart';

import 'layout_test_support.dart';

class _ApiEnregistreuse extends UniFlowApi {
  _ApiEnregistreuse(super.service, {this.erreur});

  final Object? erreur;
  final List<(String, Map<String, dynamic>)> appels = [];

  @override
  Future<Map<String, dynamic>> call(
    String path,
    Map<String, dynamic> payload,
  ) async {
    appels.add((path, payload));
    if (erreur != null) throw erreur!;
    return {'ok': true, 'coursesReady': false};
  }
}

UniFlowUser _utilisateur({
  String accountType = 'UNIVERSITY',
  String role = 'STUDENT',
  String? program = 'ICT4D',
  String? level = 'L2',
}) =>
    UniFlowUser(
      id: 'u-test',
      email: 'etu@uniflow.test',
      name: 'Étudiant Test',
      accountType: accountType,
      role: role,
      program: program,
      level: level,
    );

void main() {
  late _ApiEnregistreuse api;
  late AuthRepository depot;

  setUpAll(() async {
    await loadTestEnv();
    // Le client Appwrite interroge `path_provider` à sa construction (jar de
    // cookies) ; sans doublure, l'erreur asynchrone fait échouer le test.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => Directory.systemTemp.path,
    );
  });

  setUp(() {
    final service = AppwriteService();
    api = _ApiEnregistreuse(service);
    depot = AuthRepository(service, api);
  });

  test('un étudiant universitaire rattaché à une filière est raccordé',
      () async {
    await depot.retryAcademicProvisioning(_utilisateur());
    expect(api.appels, hasLength(1));
    expect(api.appels.single.$1, ApiPaths.academicRegistration);
    expect(api.appels.single.$2, {'action': 'provision'});
  });

  test(
      'un délégué l\'est aussi ; enseignant, administration, compte personnel non',
      () async {
    await depot.retryAcademicProvisioning(_utilisateur(role: 'DELEGATE'));
    expect(api.appels, hasLength(1));

    api.appels.clear();
    await depot.retryAcademicProvisioning(_utilisateur(role: 'TEACHER'));
    await depot.retryAcademicProvisioning(_utilisateur(role: 'ADMIN'));
    await depot.retryAcademicProvisioning(
        _utilisateur(accountType: 'PERSONAL', role: 'STUDENT'));
    await depot.retryAcademicProvisioning(
        _utilisateur(accountType: 'PLATFORM', role: 'ADMIN'));
    expect(api.appels, isEmpty);
  });

  test('sans filière ou sans niveau, rien à raccorder : aucun appel réseau',
      () async {
    await depot.retryAcademicProvisioning(_utilisateur(program: ''));
    await depot.retryAcademicProvisioning(_utilisateur(level: null));
    expect(api.appels, isEmpty);
  });

  test(
      'un échec du service ne remonte jamais : c\'est un rattrapage, pas une condition d\'accès',
      () async {
    final service = AppwriteService();
    final apiEnPanne = _ApiEnregistreuse(
      service,
      erreur:
          const ApiException('Function indisponible', code: 'EXECUTION_FAILED'),
    );
    final depotEnPanne = AuthRepository(service, apiEnPanne);
    await expectLater(
      depotEnPanne.retryAcademicProvisioning(_utilisateur()),
      completes,
    );
    expect(apiEnPanne.appels, hasLength(1));
  });
}
