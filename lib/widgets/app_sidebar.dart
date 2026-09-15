import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/avatar.dart';
import 'uniflow_logo.dart';
import 'user_avatar.dart';

/// Représente chaque item du menu de la sidebar : icône, libellé.
/// Enum plutôt que Strings pour éviter les fautes de frappe et bénéficier
/// de l'autocomplétion / du switch exhaustif dans MainShell.
enum SidebarItem {
  dashboard(Icons.grid_view_rounded, 'Dashboard'),
  students(Icons.people_alt_outlined, 'Étudiants'),
  teachers(Icons.school_outlined, 'Enseignants'),
  programs(Icons.menu_book_outlined, 'Programmes'),
  ue(Icons.dashboard_outlined, 'UE (Unités)'),
  classrooms(Icons.meeting_room_outlined, 'Salles'),
  structure(Icons.account_tree_outlined, 'Structure'),
  schedule(Icons.calendar_today_outlined, 'Emploi du temps'),
  attendance(Icons.event_available_outlined, 'Présences'),
  assignments(Icons.task_outlined, 'Devoirs'),
  grades(Icons.grade_outlined, 'Notes'),
  library(Icons.library_books_outlined, 'Bibliothèque'),
  conferences(Icons.videocam_outlined, 'Conférences'),
  sentinelle(Icons.security_outlined, 'Sentinelle IoT'),
  teams(Icons.groups_outlined, 'Équipe'),
  communications(Icons.chat_bubble_outline, 'Communications'),
  payments(Icons.payments_outlined, 'Paiements'),
  statistics(Icons.bar_chart_outlined, 'Statistiques'),
  settings(Icons.settings_outlined, 'Paramètres');

  final IconData icon;
  final String label;
  const SidebarItem(this.icon, this.label);
}

/// Sidebar fixe (fond bleu nuit) affichée à gauche sur toutes les pages
/// internes de l'application. Contrairement à la version précédente, le
/// profil de l'utilisateur connecté est affiché en HAUT (sous le logo),
/// pas en bas — fidèle à la maquette "UniFlow Desktop Partie 1".
class AppSidebar extends ConsumerWidget {
  final SidebarItem selected;
  final ValueChanged<SidebarItem> onSelect;

  const AppSidebar({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  static const double width = 250;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return Container(
      width: width,
      // Fond en dégradé (bleu nuit → presque noir) plutôt qu'aplat : c'est ce
      // qui donne à la sidebar du web sa profondeur.
      decoration: const BoxDecoration(gradient: AppColors.sidebarGradient),
      child: Column(
        children: [
          // ----- En-tête : logo -----
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 18),
            child: Row(
              children: [
                // `UniFlowIcon` plutôt qu'une copie locale de l'image : la
                // copie locale reprenait le logotype horizontal dans un carré
                // de 34 px avec `BoxFit.cover`, donc le même rognage — le mot
                // « UniFlow » n'y apparaissait jamais.
                UniFlowIcon(size: 34),
                SizedBox(width: 10),
                // `Expanded` + ellipse : sans cela, un libellé ou un jour de
                // police plus large que prévu déborde de la sidebar, dont la
                // largeur est pourtant fixe.
                Expanded(
                  child: Text(
                    'UniFlow',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ----- Profil de l'utilisateur connecté (en haut de la sidebar) -----
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                InitialsAvatar(
                  initials: user == null ? '?' : initialsOf(user.name),
                  avatarFileId: user?.avatarFileId,
                  backgroundColor: const Color(0xFF2A3352),
                  textColor: Colors.white,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Bonjour,',
                        style: TextStyle(color: Colors.white, fontSize: 12.5, height: 1.1),
                      ),
                      Text(
                        user == null ? 'Utilisateur' : '${user.name} !',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700),
                      ),
                      // Le pseudo prime sur le rôle : c'est le référent de la
                      // messagerie, donc ce que les autres utilisateurs
                      // reconnaissent.
                      Text(
                        user == null
                            ? 'Hors ligne'
                            : (user.username == null || user.username!.isEmpty
                                ? user.role
                                : '@${user.username}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
          const SizedBox(height: 8),

          // ----- Liste des items de menu -----
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: SidebarItem.values
                  .map((item) => _SidebarTile(
                        item: item,
                        isActive: item == selected,
                        onTap: () => onSelect(item),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Une ligne cliquable du menu de la sidebar.
///
/// L'état actif est signalé par un fond bleu plein **et** une barre d'accent
/// verticale à gauche : sur un fond bleu nuit, la seule différence de teinte
/// se lit mal, la barre donne un repère net.
class _SidebarTile extends StatelessWidget {
  final SidebarItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: isActive ? AppColors.sidebarActive : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AppColors.sidebarActive.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  item.icon,
                  size: 19,
                  color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 12),
                // `Expanded` + ellipse : la sidebar a une largeur fixe, un
                // libellé qui ne rentre pas doit se tronquer proprement au
                // lieu de faire déborder la ligne.
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
