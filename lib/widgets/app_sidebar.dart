import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
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
  schedule(Icons.calendar_today_outlined, 'Emploi du temps'),
  attendance(Icons.event_available_outlined, 'Présences'),
  conferences(Icons.videocam_outlined, 'Conférences'),
  communications(Icons.chat_bubble_outline, 'Communications'),
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
class AppSidebar extends StatelessWidget {
  final SidebarItem selected;
  final ValueChanged<SidebarItem> onSelect;

  const AppSidebar({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  static const double width = 250;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      color: AppColors.sidebarBg,
      child: Column(
        children: [
          // ----- En-tête : logo -----
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
            child: Row(
              children: [
                SizedBox(
                  width: 34,
                  height: 34,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Image.asset(
                      'assets/images/logo.jpg',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'UniFlow',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
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
                const InitialsAvatar(
                  initials: 'AD',
                  backgroundColor: Color(0xFF2A3352),
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
                      const Text(
                        'Administrateur !',
                        style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Administrateur',
                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Divider(color: Colors.white.withOpacity(0.08), height: 1),
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isActive ? AppColors.sidebarActive : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 19,
                  color: isActive ? Colors.white : Colors.white.withOpacity(0.6),
                ),
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    color: isActive ? Colors.white : Colors.white.withOpacity(0.75),
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
