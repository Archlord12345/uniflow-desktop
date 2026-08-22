import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Barre d'onglets simple (ex: "Curriculum / Enseignants / Prérequis",
/// ou "Informations personnelles / Parcours académique / Historique").
///
/// Volontairement non lié à un TabController Flutter classique : ici on
/// gère juste un index sélectionné + un callback, ce qui est suffisant
/// pour switcher le contenu affiché en dessous sans la complexité d'un
/// TabBarView (utile quand les onglets ne contiennent pas tous le même
/// type de contenu scrollable).
class SimpleTabBar extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const SimpleTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.inputBorder)),
      ),
      child: Row(
        children: [
          for (int i = 0; i < tabs.length; i++)
            _TabItem(
              label: tabs[i],
              isActive: i == selectedIndex,
              onTap: () => onTabSelected(i),
            ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TabItem({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        margin: const EdgeInsets.only(right: 28),
        decoration: BoxDecoration(
          // le trait bleu sous l'onglet actif est simplement une bordure
          // inférieure épaisse — pas besoin de superposer un widget en plus
          border: Border(
            bottom: BorderSide(
              color: isActive ? AppColors.primaryBlue : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? AppColors.primaryBlue : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
