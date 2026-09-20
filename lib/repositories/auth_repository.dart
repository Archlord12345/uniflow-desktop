// `Databases.*Document` est marqué déprécié par le SDK Dart 26 au profit de
// `TablesDB.*Row` (Appwrite 1.8). Le schéma du projet est encore déclaré en
// collections/documents (`uniflow-we/scripts/appwrite-schema.mjs`) et la
// migration vers TablesDB se fera pour les trois clients en même temps ; on
// ignore la dépréciation ici, fichier par fichier, sans assouplir l'analyse
// globale.
// ignore_for_file: deprecated_member_use

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/appwrite_models.dart';
import '../models/user_role.dart';
import '../providers/appwrite_provider.dart';
import '../services/appwrite_service.dart';
import '../services/uniflow_api.dart';

/// Données saisies à l'inscription native.
///
/// Pour un compte universitaire, le rôle n'est **pas** un champ : il vaut
/// toujours `STUDENT` (consigne du propriétaire). Les enseignants, délégués et
/// administrateurs sont créés par l'administration via `/admin-directory`.
class RegistrationRequest {
  final String name;
  final String email;
  final String password;
  final AccountType accountType;
  final String? university;
  final String? program;
  final String? level;
  final String? country;

  const RegistrationRequest({
    required this.name,
    required this.email,
    required this.password,
    required this.accountType,
    this.university,
    this.program,
    this.level,
    this.country,
  });

  /// Rôle écrit dans le document `users`, miroir d'affichage.
  String get role => 'STUDENT';

  String get accountTypeValue =>
      accountType == AccountType.personal ? 'PERSONAL' : 'UNIVERSITY';

  /// Document `users`, tel que le web l'écrit dans `createAccount`.
  Map<String, dynamic> toProfileDocument(String userId) => {
        'email': email.trim().toLowerCase(),
        'name': name.trim(),
        'accountType': accountTypeValue,
        'role': role,
        if (accountType == AccountType.university) ...{
          'university': university?.trim(),
          'program': program?.trim(),
          'level': level?.trim(),
        },
        if (country != null && country!.trim().isNotEmpty)
          'country': country!.trim(),
      };
}

/// Validation locale du formulaire d'inscription, hors réseau et testable.
///
/// Les règles reprennent celles d'Appwrite (mot de passe de 8 caractères
/// minimum) et du web (université, filière et niveau requis pour un compte
/// universitaire) : un refus côté serveur après une attente réseau lente est
/// bien plus frustrant qu'un message immédiat.
String? validateRegistration(RegistrationRequest request) {
  if (request.name.trim().length < 2) return 'Indiquez votre nom complet.';
  final email = request.email.trim();
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    return 'L\'adresse email n\'est pas valide.';
  }
  if (request.password.length < 8) {
    return 'Le mot de passe doit contenir au moins 8 caractères.';
  }
  if (request.accountType == AccountType.university) {
    if ((request.university ?? '').trim().isEmpty) {
      return 'Choisissez votre université.';
    }
    if ((request.program ?? '').trim().isEmpty) {
      return 'Choisissez votre filière.';
    }
    if ((request.level ?? '').trim().isEmpty) {
      return 'Choisissez votre niveau.';
    }
  }
  return null;
}

class AuthRepository {
  final AppwriteService _service;
  final UniFlowApi _api;
  AuthRepository(this._service, this._api);

  Account get _account => _service.account;
  Databases get _databases => _service.databases;

  Future<void> login(String email, String password) async {
    try {
      await _account.deleteSession(sessionId: 'current');
    } catch (_) {}
    await _account.createEmailPasswordSession(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> logout() async {
    await _account.deleteSession(sessionId: 'current');
  }

  /// Vérifie le mot de passe du compte connecté en rouvrant une session.
  ///
  /// Lève `AppwriteException(401)` si le mot de passe est faux. Appwrite ne
  /// permet pas de vérifier un mot de passe autrement ; la session courante
  /// est remplacée par une session équivalente, sans effet visible.
  Future<void> verifyPassword(String email, String password) async {
    try {
      await _account.deleteSession(sessionId: 'current');
    } catch (_) {}
    await _account.createEmailPasswordSession(
        email: email.trim(), password: password);
  }

  /// Demande au serveur la suppression du compte connecté (service
  /// `/account`, action `delete-self`). La Function répond `{ ok: true }` ;
  /// tout autre corps est traduit en [ApiException] par la passerelle.
  Future<void> deleteOwnAccount() async {
    await _api.call(ApiPaths.account, const {'action': 'delete-self'});
  }

  /// Compte connecté, ou `null` s'il n'y a pas de session.
  ///
  /// Le profil `users` est lu **en plus** du compte, jamais à sa place : un
  /// compte dont le document manque (créé depuis la console, inscription
  /// interrompue) doit quand même pouvoir entrer, avec le rôle porté par ses
  /// labels et un profil minimal. Avant, ce cas renvoyait `null` et l'écran
  /// disait « aucun profil » alors que la session était valide.
  Future<UniFlowUser?> getCurrentUser() async {
    final models.User account;
    try {
      account = await _account.get();
    } catch (_) {
      return null;
    }

    Map<String, dynamic> profile = const {};
    try {
      final doc = await _databases.getDocument(
        databaseId: _service.databaseId,
        collectionId: 'users',
        documentId: account.$id,
      );
      profile = doc.data;
    } catch (error) {
      debugPrint('Profil users illisible pour ${account.$id} : $error');
    }

    return buildUser(account, profile);
  }

  /// Construit l'utilisateur à partir du compte et de son document. Fonction
  /// pure, testable : c'est ici que le contrat des labels s'applique.
  static UniFlowUser buildUser(
      models.User account, Map<String, dynamic> profile) {
    final labels = account.labels.map((e) => e.toString()).toList();
    final role = UserRole.fromLabels(
      labels,
      fallbackRole: profile['role']?.toString(),
    );
    // Le type de compte est écrit à deux endroits par le web (`prefs` et
    // document) ; les préférences sont posées en premier, elles priment.
    final prefs = account.prefs.data;
    final accountType = (prefs['uniflowAccountType'] ??
            profile['accountType'] ??
            profile['accountCategory'] ??
            'UNIVERSITY')
        .toString();

    return UniFlowUser(
      id: account.$id,
      email: account.email,
      name: account.name.isNotEmpty
          ? account.name
          : (profile['name']?.toString() ?? account.email),
      accountType: parseAccountType(accountType).wireValue,
      role: role.wireValue,
      university: profile['university']?.toString(),
      faculty: profile['faculty']?.toString(),
      program: profile['program']?.toString(),
      level: profile['level']?.toString(),
      country: profile['country']?.toString(),
      username: profile['username']?.toString(),
      avatarFileId: profile['avatarFileId']?.toString(),
      labels: labels,
      isSuperAdmin: UserRole.hasSuperAdminLabel(labels),
    );
  }

  /// Relit uniquement le document de profil, sans repasser par le compte.
  ///
  /// Utilisé après un changement de photo : le compte Appwrite n'a pas bougé,
  /// seul le document `users` a été mis à jour.
  Future<UniFlowUser?> refreshProfile() => getCurrentUser();

  /// Inscription native, séquence identique à `createAccount` du web :
  /// compte → session → préférence de type → document `users` → pour un compte
  /// universitaire, provisionnement par `/academic-registration`.
  ///
  /// L'ordre compte : la session doit exister avant d'écrire le document,
  /// sinon la collection `users` refuse la création (permissions `users`).
  Future<UniFlowUser> register(RegistrationRequest request) async {
    final invalid = validateRegistration(request);
    if (invalid != null) throw ArgumentError(invalid);

    final email = request.email.trim().toLowerCase();
    try {
      await _account.deleteSession(sessionId: 'current');
    } catch (_) {}

    final created = await _account.create(
      userId: ID.unique(),
      email: email,
      password: request.password,
      name: request.name.trim(),
    );
    await _account.createEmailPasswordSession(
      email: email,
      password: request.password,
    );
    await _account.updatePrefs(
      prefs: {'uniflowAccountType': request.accountTypeValue},
    );

    try {
      await _databases.createDocument(
        databaseId: _service.databaseId,
        collectionId: 'users',
        documentId: created.$id,
        data: request.toProfileDocument(created.$id),
        permissions: [
          Permission.read(Role.user(created.$id)),
          Permission.update(Role.user(created.$id)),
          Permission.delete(Role.user(created.$id)),
        ],
      );
    } on AppwriteException catch (error) {
      // 409 : le document existe déjà (inscription reprise après une coupure
      // réseau). Le compte est valide, on continue.
      if (error.code != 409) rethrow;
    }

    if (request.accountType == AccountType.university) {
      // Le provisionnement crée l'entrée `academic_directory` et les
      // inscriptions aux cours de la promotion. Un échec ici ne doit pas
      // annuler le compte : le web fait pareil et journalise.
      try {
        await _api.call(ApiPaths.academicRegistration, {
          'action': 'provision',
          'university': request.university,
          'program': request.program,
          'level': request.level,
        });
      } catch (error) {
        debugPrint('Provisionnement académique différé : $error');
      }
    }

    final user = await getCurrentUser();
    if (user == null) {
      throw StateError('Compte créé, mais la session n\'a pas pu être relue.');
    }
    return user;
  }

  /// Envoie l'email de réinitialisation. Appwrite renvoie l'utilisateur vers
  /// la page web `/reset-password`, seule à pouvoir recevoir `userId` et
  /// `secret` par l'URL — le desktop n'a pas de lien profond.
  Future<void> requestPasswordRecovery(String email) async {
    await _account.createRecovery(
      email: email.trim(),
      url: '${_service.webAppUrl}/reset-password',
    );
  }

  /// Termine la réinitialisation depuis le desktop : l'utilisateur colle le
  /// lien reçu par email, on en extrait `userId` et `secret`.
  Future<void> completePasswordRecovery({
    required String userId,
    required String secret,
    required String newPassword,
  }) async {
    await _account.updateRecovery(
      userId: userId,
      secret: secret,
      password: newPassword,
    );
  }
}

/// Extrait `userId` et `secret` d'un lien de réinitialisation Appwrite
/// (`…/reset-password?userId=…&secret=…&expire=…`). Renvoie `null` si l'un
/// des deux manque : c'est le seul cas où la saisie est inutilisable.
({String userId, String secret})? parseRecoveryLink(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  final uri = Uri.tryParse(text.contains('://') ? text : 'https://x/?$text');
  if (uri == null) return null;
  final userId = uri.queryParameters['userId'];
  final secret = uri.queryParameters['secret'];
  if (userId == null || userId.isEmpty || secret == null || secret.isEmpty) {
    return null;
  }
  return (userId: userId, secret: secret);
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(appwriteServiceProvider),
    ref.watch(uniflowApiProvider),
  );
});
