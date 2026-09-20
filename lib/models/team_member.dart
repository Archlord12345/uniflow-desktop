import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Un membre de l'équipe KERNEL FORGE, tel que stocké dans la collection
/// `team_members`.
///
/// Cette collection est la source unique des trois clients : la page `/teams`
/// du web, cet écran, et celui du desktop lisent les mêmes documents. Avant
/// elle, chaque application portait sa propre liste figée — neuf membres sur le
/// web, six ici, quatre sur le desktop.
class TeamMember {
  final String id;
  final String slug;
  final String name;
  final String github;
  final String email;

  /// `Leadership`, `Frontend` ou `Backend` : c'est ce champ qui pilote les
  /// filtres de la page.
  final String team;
  final String subTeam;
  final String role;

  /// Libellé de la pastille affichée en haut de la carte. Facultatif.
  final String badge;

  /// Couleur sémantique (`blue`, `emerald`…), traduite localement par
  /// [teamAccentStyle]. La base ne stocke jamais une couleur Flutter.
  final String accent;

  /// Fichier de la photo dans le bucket `uniflow_assets`, vide s'il n'y en a
  /// pas encore.
  final String avatarFileId;

  final int displayOrder;

  TeamMember({
    required this.id,
    required this.slug,
    required this.name,
    required this.github,
    required this.email,
    required this.team,
    required this.subTeam,
    required this.role,
    required this.badge,
    required this.accent,
    required this.avatarFileId,
    required this.displayOrder,
  });

  /// Construit un membre depuis un document Appwrite.
  ///
  /// Chaque champ est replié sur une valeur neutre : un document écrit à la
  /// main depuis la console Appwrite peut omettre un attribut, et un écran qui
  /// plante sur `null` serait pire qu'un écran avec un libellé manquant.
  factory TeamMember.fromDocument(models.Document doc) {
    final data = doc.data;
    return TeamMember(
      id: doc.$id,
      slug: _text(data['slug']),
      name: _text(data['name']),
      github: _text(data['github']),
      email: _text(data['email']),
      team: _text(data['team']),
      subTeam: _text(data['subTeam']),
      role: _text(data['role']),
      badge: _text(data['badge']),
      accent: _text(data['accent']),
      avatarFileId: _text(data['avatarFileId']),
      displayOrder: _number(data['displayOrder']),
    );
  }

  static String _text(Object? value) => value is String ? value : '';

  static int _number(Object? value) => value is num ? value.toInt() : 0;
}

/// Couleur d'accent d'un membre, telle que stockée en base.
///
/// Les sept valeurs sont celles de `teamAccents` dans
/// `uniflow-we/scripts/appwrite-schema.mjs` ; la Function `team-roster` refuse
/// toute autre valeur à l'écriture.
enum TeamAccent { blue, purple, emerald, amber, rose, cyan, indigo }

/// Traduit la clé stockée en énumération.
///
/// Une clé inconnue — document modifié à la main, valeur ajoutée plus tard par
/// une version plus récente du schéma — retombe sur [TeamAccent.blue] plutôt
/// que de faire échouer l'affichage : une carte bleue vaut mieux qu'un écran
/// d'erreur.
TeamAccent mapTeamAccent(String? value) {
  switch ((value ?? '').trim().toLowerCase()) {
    case 'purple':
      return TeamAccent.purple;
    case 'emerald':
      return TeamAccent.emerald;
    case 'amber':
      return TeamAccent.amber;
    case 'rose':
      return TeamAccent.rose;
    case 'cyan':
      return TeamAccent.cyan;
    case 'indigo':
      return TeamAccent.indigo;
    case 'blue':
    default:
      return TeamAccent.blue;
  }
}

/// Trio de couleurs d'un accent : fond de la pastille, texte, bordure.
class TeamAccentStyle {
  final Color background;
  final Color foreground;
  final Color border;

  const TeamAccentStyle(this.background, this.foreground, this.border);
}

/// Couleurs de chaque accent, reprises de la palette Tailwind employée par la
/// page web (`bg-*-100`, `text-*-800`, `border-*-200`) pour que la carte ait le
/// même aspect sur les trois clients.
TeamAccentStyle teamAccentStyle(TeamAccent accent) {
  switch (accent) {
    case TeamAccent.blue:
      return const TeamAccentStyle(Color(0xFFDBEAFE), AppColors.primaryBlue, Color(0xFFBFDBFE));
    case TeamAccent.purple:
      return const TeamAccentStyle(Color(0xFFF3E8FF), Color(0xFF5B21B6), Color(0xFFE9D5FF));
    case TeamAccent.emerald:
      return const TeamAccentStyle(Color(0xFFD1FAE5), Color(0xFF065F46), Color(0xFFA7F3D0));
    case TeamAccent.amber:
      return const TeamAccentStyle(Color(0xFFFEF3C7), Color(0xFF92400E), Color(0xFFFDE68A));
    case TeamAccent.rose:
      return const TeamAccentStyle(Color(0xFFFFE4E6), Color(0xFF9F1239), Color(0xFFFECDD3));
    case TeamAccent.cyan:
      return const TeamAccentStyle(Color(0xFFCFFAFE), Color(0xFF155E75), Color(0xFFA5F3FC));
    case TeamAccent.indigo:
      return const TeamAccentStyle(Color(0xFFE0E7FF), Color(0xFF3730A3), Color(0xFFC7D2FE));
  }
}

/// Icône de la pastille, déduite du rôle.
///
/// L'ancienne liste figée portait une icône par membre ; plutôt que d'ajouter
/// un attribut en base pour un détail décoratif, on la retrouve depuis la
/// sous-équipe — même règle que `memberIcon()` côté web, pour que les deux
/// montrent la même icône.
IconData teamMemberIcon(TeamMember member) {
  final haystack = '${member.subTeam} ${member.role}'.toLowerCase();
  if (RegExp(r'sgbd|base de donn|bdd?|database').hasMatch(haystack)) {
    return Icons.storage_outlined;
  }
  if (RegExp(r'mobile|android|ios').hasMatch(haystack)) {
    return Icons.smartphone_outlined;
  }
  if (member.team == 'Leadership') return Icons.workspace_premium_outlined;
  if (member.team == 'Backend') return Icons.dns_outlined;
  return Icons.code_outlined;
}

/// Les catégories de filtre de la page, dans l'ordre des pastilles du web.
const List<String> teamFilters = ['Tous', 'Leadership', 'Frontend', 'Backend'];

/// Membres de [category] ; « Tous » ne filtre rien.
List<TeamMember> filterTeamMembers(List<TeamMember> members, String category) {
  if (category == 'Tous') return members;
  return members.where((m) => m.team == category).toList();
}
