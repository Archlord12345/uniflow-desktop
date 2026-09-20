import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/team_member.dart';
import '../repositories/team_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_bar.dart';
import '../widgets/data_state_view.dart';
import '../widgets/user_avatar.dart';

/// Page « Équipe KERNEL FORGE », alignée sur la page publique `/teams` du web.
///
/// Elle lit la collection `team_members` — la même que le web et le mobile, et
/// non une liste figée comme avant, qui ne comptait ici que quatre membres
/// contre neuf sur le web. La page est en **lecture seule** : l'ajout, la
/// modification et la suppression se font depuis l'espace d'administration du
/// web, qui passe par la Function `team-roster`.
///
/// Ce widget n'a pas de `Scaffold` ni de sidebar : il est affiché à l'intérieur
/// de `MainShell`.
class TeamsScreen extends ConsumerStatefulWidget {
  const TeamsScreen({super.key});

  @override
  ConsumerState<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends ConsumerState<TeamsScreen> {
  /// Filtre actif, « Tous » par défaut comme sur le web.
  String _filtre = 'Tous';

  /// Les neuf technologies du bandeau, identiques à celles du web.
  static const List<String> _technologies = [
    'React 18',
    'TypeScript',
    'Tailwind CSS',
    'PWA Offline-First',
    'SQLite / IndexedDB',
    'NestJS API',
    'Express Backend',
    'WebSockets',
    'QR Code Engine',
  ];

  Future<void> _ouvrir(String url) async {
    final opened =
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Aucune application ne peut ouvrir ce lien.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final equipeAsync = ref.watch(teamMembersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppPageBar(
          breadcrumb: ['Vie de campus', 'Équipe KERNEL FORGE'],
          subtitle: 'Les développeurs et ingénieurs qui ont conçu UniFlow',
        ),
        Expanded(
          child: equipeAsync.when(
            loading: () =>
                const DataLoadingView(label: 'Chargement de l\'équipe…'),
            error: (error, _) => DataErrorView(
              error: error,
              onRetry: () => ref.invalidate(teamMembersProvider),
            ),
            data: (membres) => _contenu(membres),
          ),
        ),
      ],
    );
  }

  Widget _contenu(List<TeamMember> membres) {
    final visibles = filterTeamMembers(membres, _filtre);

    return LayoutBuilder(
      builder: (context, contraintes) {
        // Le web passe à trois colonnes en `lg` (1024 px), deux en `sm`
        // (640 px), une en dessous. La fenêtre du desktop est redimensionnable,
        // donc les trois paliers servent réellement.
        final largeur = contraintes.maxWidth;
        final colonnes = largeur >= 1024
            ? 3
            : largeur >= 640
                ? 2
                : 1;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Intro(),
              const SizedBox(height: 18),
              _Statistiques(membres: membres),
              const SizedBox(height: 24),
              const Text('Nos Talents', style: AppTextStyles.h3),
              const SizedBox(height: 2),
              const Text(
                'Découvrez l\'équipe et leurs domaines d\'expertise',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: teamFilters
                    .map((filtre) => _PastilleFiltre(
                          label: filtre,
                          actif: _filtre == filtre,
                          onTap: () => setState(() => _filtre = filtre),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 18),
              if (visibles.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'Aucun membre dans cette catégorie.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall,
                  ),
                )
              else
                _Grille(
                  membres: visibles,
                  colonnes: colonnes,
                  onGithub: (membre) =>
                      _ouvrir('https://github.com/${membre.github}'),
                  onMail: (membre) => _ouvrir('mailto:${membre.email}'),
                ),
              const SizedBox(height: 24),
              const _BandeauTechnologies(technologies: _technologies),
              const SizedBox(height: 18),
              _AppelGithub(
                  onTap: () => _ouvrir('https://github.com/KERNEL-FORGE-G')),
            ],
          ),
        );
      },
    );
  }
}

/// Cartes des membres, réparties en [colonnes] colonnes.
///
/// Les cartes sont hautes de ce qu'exige leur contenu — un nom long sur deux
/// lignes, un rôle, une sous-équipe — plutôt que d'une hauteur fixe : avec un
/// texte agrandi par les réglages d'accessibilité, une hauteur imposée tronque
/// ou déborde. `IntrinsicHeight` égalise les cartes d'une même ligne.
class _Grille extends StatelessWidget {
  final List<TeamMember> membres;
  final int colonnes;
  final void Function(TeamMember) onGithub;
  final void Function(TeamMember) onMail;

  const _Grille({
    required this.membres,
    required this.colonnes,
    required this.onGithub,
    required this.onMail,
  });

  @override
  Widget build(BuildContext context) {
    final lignes = <Widget>[];
    for (var i = 0; i < membres.length; i += colonnes) {
      final tranche =
          membres.sublist(i, (i + colonnes).clamp(0, membres.length));
      lignes.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < colonnes; j++) ...[
                if (j > 0) const SizedBox(width: 16),
                Expanded(
                  child: j < tranche.length
                      ? _CarteMembre(
                          membre: tranche[j],
                          onGithub: () => onGithub(tranche[j]),
                          onMail: () => onMail(tranche[j]),
                        )
                      // Colonne vide en fin de liste : sans elle, la dernière
                      // carte d'un nombre non multiple s'étalerait sur toute la
                      // largeur et casserait l'alignement.
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
      if (i + colonnes < membres.length) lignes.add(const SizedBox(height: 16));
    }
    return Column(children: lignes);
  }
}

/// Carte d'un membre.
///
/// La photo et la pastille occupent une ligne, puis le nom, le rôle et la
/// sous-équipe, puis les boutons. C'est la disposition de la page web, où la
/// carte est en `flex flex-col justify-between`.
class _CarteMembre extends StatelessWidget {
  final TeamMember membre;
  final VoidCallback onGithub;
  final VoidCallback onMail;

  const _CarteMembre({
    required this.membre,
    required this.onGithub,
    required this.onMail,
  });

  @override
  Widget build(BuildContext context) {
    final accent = teamAccentStyle(mapTeamAccent(membre.accent));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Coins arrondis plutôt qu'un cercle : la page web affiche les
              // photos de l'équipe en `rounded-2xl`.
              SilhouetteAvatar(
                avatarFileId: membre.avatarFileId,
                size: 56,
                borderRadius: BorderRadius.circular(16),
              ),
              const SizedBox(width: 12),
              if (membre.badge.isNotEmpty)
                Flexible(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: accent.background,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: accent.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(teamMemberIcon(membre),
                            size: 12, color: accent.foreground),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            membre.badge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: accent.foreground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            membre.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            membre.role,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryBlue,
            ),
          ),
          if (membre.subTeam.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              membre.subTeam,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.inputBorder),
          const SizedBox(height: 10),
          Row(
            children: [
              if (membre.github.isNotEmpty)
                Flexible(
                  child: _BoutonLien(
                    icone: Icons.code,
                    label: '@${membre.github}',
                    onTap: onGithub,
                  ),
                ),
              // `Spacer` pousse le bouton mail à droite même quand le pseudo
              // GitHub est absent — c'est la disposition du web.
              const Spacer(),
              if (membre.email.isNotEmpty)
                _BoutonIcone(
                  icone: Icons.mail_outline,
                  tooltip: membre.email,
                  onTap: onMail,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BoutonLien extends StatelessWidget {
  final IconData icone;
  final String label;
  final VoidCallback onTap;

  const _BoutonLien(
      {required this.icone, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icone, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoutonIcone extends StatelessWidget {
  final IconData icone;
  final String tooltip;
  final VoidCallback onTap;

  const _BoutonIcone(
      {required this.icone, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: AppColors.inputBorder),
            ),
            child: Icon(icone, size: 16, color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _PastilleFiltre extends StatelessWidget {
  final String label;
  final bool actif;
  final VoidCallback onTap;

  const _PastilleFiltre(
      {required this.label, required this.actif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: actif ? AppColors.primaryBlue : AppColors.cardWhite,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: actif ? AppColors.primaryBlue : AppColors.inputBorder),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: actif ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bandeau d'introduction : la pastille « KERNEL FORGE — UY1 » et la phrase de
/// présentation du web.
class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // La pastille est enveloppée dans un `Flexible` : la `Row`
              // extérieure mesure ses enfants non flexibles sans contrainte de
              // largeur, si bien que le libellé ci-dessous ne pourrait pas se
              // replier et déborderait dans une fenêtre étroite. Avec cette
              // contrainte, le `Flexible` intérieur reçoit une largeur bornée
              // et peut élider.
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.code, size: 13, color: AppColors.teal),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'KERNEL FORGE — UY1',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Les développeurs et ingénieurs passionnés qui ont conçu UniFlow pour '
            'transformer la gestion académique universitaire en Afrique.',
            style: AppTextStyles.body,
          ),
        ],
      ),
    );
  }
}

/// Les quatre tuiles de statistiques, calculées depuis la liste.
class _Statistiques extends StatelessWidget {
  final List<TeamMember> membres;

  const _Statistiques({required this.membres});

  @override
  Widget build(BuildContext context) {
    // Les tuiles sont calculées et non écrites en dur : la page web affichait
    // « 9 », « 5 », « 3 », « 1 », et ces chiffres seraient devenus faux dès le
    // premier ajout de membre depuis l'administration.
    final tuiles = <Widget>[
      _tuile('Membres au total', membres.length, Icons.groups_outlined,
          AppColors.primaryBlue),
      _tuile('Ingénieurs Frontend', _compter('Frontend'), Icons.laptop_outlined,
          AppColors.purple),
      _tuile('Ingénieurs Backend & BD', _compter('Backend'), Icons.dns_outlined,
          AppColors.teal),
      _tuile('Lead & Architecture', _compter('Leadership'),
          Icons.workspace_premium_outlined, AppColors.warning),
    ];

    return LayoutBuilder(
      builder: (context, contraintes) {
        // Quatre tuiles de front dès que la fenêtre le permet, deux sinon :
        // c'est le `grid-cols-2 sm:grid-cols-4` du web.
        final parLigne = contraintes.maxWidth >= 640 ? 4 : 2;
        const espacement = 12.0;
        final largeur =
            (contraintes.maxWidth - espacement * (parLigne - 1)) / parLigne;
        return Wrap(
          spacing: espacement,
          runSpacing: espacement,
          children: tuiles
              .map((tuile) => SizedBox(width: largeur, child: tuile))
              .toList(),
        );
      },
    );
  }

  int _compter(String equipe) => membres.where((m) => m.team == equipe).length;

  Widget _tuile(String label, int valeur, IconData icone, Color couleur) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icone, size: 17, color: couleur),
          ),
          const SizedBox(height: 8),
          Text(
            '$valeur',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style:
                const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _BandeauTechnologies extends StatelessWidget {
  final List<String> technologies;

  const _BandeauTechnologies({required this.technologies});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'STACK TECHNIQUE PROJET',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 6),
          const Text('Conçu avec les meilleures technologies web',
              style: AppTextStyles.h3),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: technologies
                .map((technologie) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: AppColors.inputBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_outline,
                              size: 13, color: AppColors.teal),
                          const SizedBox(width: 5),
                          // `Flexible` : même correctif que sur le mobile, où
                          // « SQLite / IndexedDB » débordait de sa pastille à
                          // 320 px avec le texte agrandi. La fenêtre du desktop
                          // descend plus bas que la largeur minimale balayée
                          // par les tests.
                          Flexible(
                            child: Text(
                              technologie,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _AppelGithub extends StatelessWidget {
  final VoidCallback onTap;

  const _AppelGithub({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.logoGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.auto_awesome, color: Color(0xFFFCD34D), size: 28),
          const SizedBox(height: 8),
          const Text(
            'Rejoignez l\'organisation KERNEL FORGE',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'Projet open source développé avec passion pour la communauté académique.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: 14),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(11),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(11),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.code, size: 16, color: AppColors.primaryBlue),
                    SizedBox(width: 7),
                    // `Flexible` : le libellé n'avait aucune marge de repli. À
                    // 420 px de large avec le texte agrandi (×1.3), ce bouton
                    // débordait de 68 px — la fenêtre du desktop se réduit
                    // jusqu'à cette largeur, ce n'est pas un cas théorique.
                    Flexible(
                      child: Text(
                        'Organisation GitHub',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.open_in_new,
                        size: 13, color: AppColors.primaryBlue),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
