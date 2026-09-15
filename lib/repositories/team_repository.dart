import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/team_member.dart';
import '../providers/appwrite_provider.dart';
import '../services/appwrite_service.dart';

/// Accès à la collection `team_members`.
///
/// Lecture seule : l'ajout, la modification et la suppression d'un membre se
/// font **uniquement** depuis l'espace d'administration du web, qui passe par
/// la Function `team-roster` après vérification du rôle ADMIN côté serveur. La
/// collection n'accorde aucune écriture, sans quoi n'importe quel compte
/// connecté pourrait effacer la page publique de l'équipe — et cette page est
/// la même pour les trois clients.
class TeamRepository {
  final AppwriteService _service;

  TeamRepository(this._service);

  /// Membres de l'équipe, dans l'ordre voulu par l'administration.
  ///
  /// Le tri est demandé au serveur (`displayOrder`) plutôt que refait ici :
  /// c'est ce qui garantit que le desktop, le mobile et le web listent les
  /// mêmes personnes dans le même ordre.
  Future<List<TeamMember>> getMembers() async {
    final response = await _service.databases.listDocuments(
      databaseId: _service.databaseId,
      collectionId: 'team_members',
      queries: [Query.orderAsc('displayOrder'), Query.limit(100)],
    );
    return response.documents.map((doc) => TeamMember.fromDocument(doc)).toList();
  }
}

final teamRepositoryProvider = Provider<TeamRepository>((ref) {
  return TeamRepository(ref.watch(appwriteServiceProvider));
});

/// L'équipe telle que l'affiche l'écran Équipe.
///
/// Aucune session n'est requise : la collection est lisible par tous, comme la
/// page publique du web. Un visiteur non connecté verrait donc la même page.
final teamMembersProvider = FutureProvider<List<TeamMember>>((ref) async {
  return ref.read(teamRepositoryProvider).getMembers();
});
