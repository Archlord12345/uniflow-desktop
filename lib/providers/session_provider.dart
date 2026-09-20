import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/auth_repository.dart';
import '../services/session_snapshot.dart';
import '../services/uniflow_api.dart';
import 'auth_provider.dart';
import 'conference_provider.dart';
import 'schedule_provider.dart';

/// Mot que l'utilisateur doit recopier pour confirmer la suppression : il
/// est vérifié tel quel, sans tolérance de casse, pour que la seconde étape
/// soit un geste délibéré.
const String kDeleteAccountKeyword = 'SUPPRIMER';

/// Message montré à l'administrateur de la plateforme : son compte est le
/// seul à ne pas pouvoir disparaître depuis un client.
const String kSuperAdminDeletionRefused =
    'Le compte administrateur de la plateforme ne peut pas être supprimé depuis l\'application.';

/// Issue d'une tentative de suppression du compte courant.
enum DeleteAccountOutcome {
  deleted,
  wrongPassword,
  refusedSuperAdmin,
  serviceUnavailable,
  failed,
}

class DeleteAccountResult {
  final DeleteAccountOutcome outcome;
  final String message;
  const DeleteAccountResult(this.outcome, this.message);

  bool get succeeded => outcome == DeleteAccountOutcome.deleted;
}

/// Actions qui touchent à la session dans son ensemble.
///
/// Avant, la déconnexion ne faisait que `deleteSession` puis vidait
/// `currentUserProvider` : la réunion LiveKit hébergée continuait de tourner
/// derrière l'écran de connexion et les listes du compte précédent restaient
/// en cache jusqu'à la prochaine ouverture. Tout passe désormais par ici.
class SessionController {
  final Ref _ref;
  final SessionSnapshotStore _snapshotStore;

  SessionController(this._ref, {SessionSnapshotStore? snapshotStore})
      : _snapshotStore = snapshotStore ?? FileSessionSnapshotStore();

  /// Ferme la session côté serveur et côté poste, dans cet ordre :
  /// visioconférence (le processus média est le plus coûteux à laisser
  /// orphelin), session Appwrite (tolérante : déjà expirée = déjà fermée),
  /// stockage local, puis providers.
  Future<void> signOut() async {
    try {
      await _ref.read(conferenceHostProvider.notifier).stop();
    } catch (error) {
      debugPrint('Arrêt de la réunion à la déconnexion : $error');
    }

    try {
      await _ref.read(authRepositoryProvider).logout();
    } catch (error) {
      // 401 : la session était déjà expirée. L'objectif — ne plus être
      // connecté — est atteint, on ne bloque pas l'utilisateur pour autant.
      debugPrint('deleteSession à la déconnexion : $error');
    }

    try {
      await _snapshotStore.clear();
    } catch (_) {}

    clearLocalState();
  }

  /// Vide l'utilisateur courant. Les providers réseau observent l'identifiant
  /// du compte (`currentUserProvider.select`) : ils se recalculent d'eux-mêmes
  /// au prochain affichage, sans invalidation explicite — invalider ici
  /// relançait des appels réseau depuis l'écran de connexion.
  void clearLocalState() {
    _ref.read(currentUserProvider.notifier).state = null;
    _ref.invalidate(weekOffsetProvider);
  }

  /// Supprime le compte connecté, après vérification du mot de passe.
  ///
  /// La vérification passe par `createEmailPasswordSession` : Appwrite ne
  /// propose pas de « vérifier le mot de passe » sans ouvrir une session, et
  /// rouvrir la session courante est sans effet de bord visible. Le service
  /// `/account` est appelé ensuite ; il peut ne pas encore être déployé
  /// (404) : le message le dit sans faire passer l'échec pour une erreur du
  /// poste.
  Future<DeleteAccountResult> deleteOwnAccount({required String password}) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) {
      return const DeleteAccountResult(DeleteAccountOutcome.failed, 'Aucune session ouverte.');
    }
    if (user.isSuperAdmin) {
      return const DeleteAccountResult(
        DeleteAccountOutcome.refusedSuperAdmin,
        kSuperAdminDeletionRefused,
      );
    }

    final repo = _ref.read(authRepositoryProvider);
    try {
      await repo.verifyPassword(user.email, password);
    } on AppwriteException catch (error) {
      if (error.code == 401) {
        return const DeleteAccountResult(
          DeleteAccountOutcome.wrongPassword,
          'Mot de passe incorrect.',
        );
      }
      return DeleteAccountResult(
        DeleteAccountOutcome.failed,
        error.message ?? 'Vérification impossible (code ${error.code}).',
      );
    } catch (error) {
      return DeleteAccountResult(DeleteAccountOutcome.failed, error.toString());
    }

    try {
      await repo.deleteOwnAccount();
    } on ApiException catch (error) {
      if (error.status == 404 || error.code == 'NOT_FOUND') {
        return const DeleteAccountResult(
          DeleteAccountOutcome.serviceUnavailable,
          'La suppression de compte n\'est pas encore disponible sur le serveur. Réessayez plus tard.',
        );
      }
      if ((error.status ?? 0) >= 500) {
        return DeleteAccountResult(
          DeleteAccountOutcome.serviceUnavailable,
          'Le serveur n\'a pas pu supprimer le compte (${error.status}). ${error.message}',
        );
      }
      return DeleteAccountResult(DeleteAccountOutcome.failed, error.message);
    } catch (error) {
      return DeleteAccountResult(DeleteAccountOutcome.failed, error.toString());
    }

    // Le compte n'existe plus : la session est morte côté serveur, on ne
    // tente pas de la fermer, on nettoie seulement le poste.
    try {
      await _ref.read(conferenceHostProvider.notifier).stop();
    } catch (_) {}
    try {
      await _snapshotStore.clear();
    } catch (_) {}
    clearLocalState();
    return const DeleteAccountResult(DeleteAccountOutcome.deleted, 'Votre compte a été supprimé.');
  }
}

final sessionControllerProvider = Provider<SessionController>((ref) {
  return SessionController(ref);
});
