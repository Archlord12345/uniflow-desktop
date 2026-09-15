import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/user_role.dart';

/// Instantané de profil conservé sur le poste, transposé de
/// `uniflow-we/src/lib/sessionPersistence.ts`.
///
/// **Ce que cet instantané n'est pas** : une preuve d'authentification. La
/// seule preuve reste le cookie de session Appwrite, que le SDK écrit
/// lui-même sur le disque (`PersistCookieJar` + `FileStorage`, voir
/// `appwrite/src/client_io.dart`) et rejoue au démarrage. L'instantané sert
/// uniquement à garder un profil affichable quand le serveur est injoignable
/// au lancement — sans lui, une coupure réseau renvoyait l'utilisateur sur
/// l'écran de connexion alors que sa session était valide.
///
/// **Ce qu'il ne contient jamais** : ni email, ni mot de passe, ni jeton, ni
/// clé. Le web retire explicitement l'email de son instantané ; on fait de
/// même, pour la même raison — le fichier est en clair dans le dossier de
/// l'utilisateur. L'email n'est pas un secret en soi, mais il est la moitié
/// d'un identifiant de connexion, et rien ici n'en a besoin.
@immutable
class SessionSnapshot {
  final String userId;
  final String name;
  final UserRole role;
  final AccountType accountType;
  final String? username;
  final String? university;
  final String? program;
  final String? level;
  final String? avatarFileId;

  /// Date d'écriture, en millisecondes depuis l'époque.
  final int persistedAt;

  const SessionSnapshot({
    required this.userId,
    required this.name,
    required this.role,
    required this.accountType,
    this.username,
    this.university,
    this.program,
    this.level,
    this.avatarFileId,
    required this.persistedAt,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'name': name,
        'role': role.name,
        'accountType': accountType.name,
        'username': username,
        'university': university,
        'program': program,
        'level': level,
        'avatarFileId': avatarFileId,
        'persistedAt': persistedAt,
      };

  /// Relit un instantané. Renvoie `null` plutôt que de lever : un fichier
  /// corrompu (arrêt brutal pendant l'écriture) ne doit pas empêcher
  /// l'application de démarrer.
  static SessionSnapshot? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final userId = raw['userId'];
    final name = raw['name'];
    if (userId is! String || userId.isEmpty) return null;
    if (name is! String) return null;

    return SessionSnapshot(
      userId: userId,
      name: name,
      // `parseUserRole` et `parseAccountType` replient sur les valeurs les
      // moins permissives : un rôle illisible ne doit pas rouvrir les écrans
      // d'administration au démarrage.
      role: parseUserRole(raw['role'] as String?),
      accountType: parseAccountType(raw['accountType'] as String?),
      username: raw['username'] as String?,
      university: raw['university'] as String?,
      program: raw['program'] as String?,
      level: raw['level'] as String?,
      avatarFileId: raw['avatarFileId'] as String?,
      persistedAt: (raw['persistedAt'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Où l'instantané est rangé.
///
/// L'interface existe pour que les tests n'écrivent rien sur le disque : un
/// test qui touche au dossier de l'utilisateur laisse des traces d'une
/// exécution à l'autre.
abstract class SessionSnapshotStore {
  Future<SessionSnapshot?> read();
  Future<void> write(SessionSnapshot snapshot);
  Future<void> clear();
}

/// Stockage sur disque, dans le dossier de données de l'application.
///
/// `getApplicationSupportDirectory` et non le dossier du projet : le fichier
/// ne doit jamais pouvoir être versionné ni embarqué dans le binaire. C'est la
/// raison pour laquelle son chemin est calculé à l'exécution et non écrit dans
/// `.env`.
class FileSessionSnapshotStore implements SessionSnapshotStore {
  static const String _fileName = 'session_profile.json';

  /// Chemin forcé, utilisé par les tests pour écrire dans un dossier
  /// temporaire au lieu du vrai dossier de l'application.
  final String? overrideDirectory;

  /// Dossier réellement utilisé, mémorisé après la première résolution : le
  /// chemin ne change pas pendant la vie du processus.
  String? _resolvedDirectory;

  FileSessionSnapshotStore({this.overrideDirectory});

  Future<File> _file() async {
    final directory = _resolvedDirectory ??
        overrideDirectory ??
        (await getApplicationSupportDirectory()).path;
    _resolvedDirectory = directory;
    return File('$directory${Platform.pathSeparator}$_fileName');
  }

  @override
  Future<SessionSnapshot?> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      return SessionSnapshot.fromJson(decoded);
    } catch (error) {
      // Une lecture impossible (fichier absent, JSON tronqué, dossier
      // inaccessible) équivaut à « aucun instantané » : le démarrage suit son
      // cours et la session Appwrite tranche.
      debugPrint('Instantané de session illisible : $error');
      return null;
    }
  }

  @override
  Future<void> write(SessionSnapshot snapshot) async {
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(snapshot.toJson()), flush: true);
    } catch (error) {
      // Ne jamais faire échouer une connexion réussie parce que le cache n'a
      // pas pu être écrit.
      debugPrint('Instantané de session non écrit : $error');
    }
  }

  @override
  Future<void> clear() async {
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } catch (error) {
      debugPrint('Instantané de session non supprimé : $error');
    }
  }
}

/// Stockage en mémoire, pour les tests et les plateformes sans système de
/// fichiers inscriptible.
class InMemorySessionSnapshotStore implements SessionSnapshotStore {
  SessionSnapshot? _snapshot;

  InMemorySessionSnapshotStore([this._snapshot]);

  @override
  Future<SessionSnapshot?> read() async => _snapshot;

  @override
  Future<void> write(SessionSnapshot snapshot) async => _snapshot = snapshot;

  @override
  Future<void> clear() async => _snapshot = null;
}
