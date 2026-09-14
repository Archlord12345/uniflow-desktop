import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Filtre déroulant réellement fonctionnel : il remplace les faux menus
/// déroulants qui affichaient un libellé fixe et n'étaient reliés à rien.
///
/// [value] vaut `null` pour l'option « toutes les valeurs ».
/// [anyLabel] est le libellé de cette option neutre.
class FilterDropdown extends StatelessWidget {
  final String anyLabel;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  const FilterDropdown({
    super.key,
    required this.anyLabel,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Si la valeur sélectionnée disparaît des options (rechargement), on
    // retombe sur l'option neutre plutôt que de laisser DropdownButton lever.
    final safeValue = options.contains(value) ? value : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.inputBorder),
        borderRadius: BorderRadius.circular(10),
        color: AppColors.cardWhite,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: safeValue,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textMuted),
          style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
          hint: Text(anyLabel, style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary)),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(anyLabel, style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary)),
            ),
            ...options.map((option) => DropdownMenuItem<String?>(
                  value: option,
                  child: Text(
                    option,
                    style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
