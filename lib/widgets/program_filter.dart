import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/directory_provider.dart';
import '../repositories/reference_repository.dart';
import '../theme/app_theme.dart';

/// Filtre « filière + niveau » commun aux écrans d'administration.
///
/// Les valeurs viennent du référentiel `academic_programs` et, à défaut, des
/// cours existants : rien n'est codé en dur, d'autres filières de l'UY1
/// arrivent en base sans mise à jour du desktop.
class ProgramFilter extends ConsumerWidget {
  final String? program;
  final String? level;
  final ValueChanged<String?> onProgramChanged;
  final ValueChanged<String?> onLevelChanged;

  const ProgramFilter({
    super.key,
    required this.program,
    required this.level,
    required this.onProgramChanged,
    required this.onLevelChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reference = ref.watch(academicReferenceProvider).valueOrNull;
    final options = ref.watch(programOptionsProvider).valueOrNull;

    final programs = <String>{
      if (reference != null) ...reference.programCodes,
      if (options != null) ...options.programs,
    }.toList()
      ..sort();
    final levels = <String>{
      if (reference != null) ...reference.levelsOf(program),
      if (options != null) ...(program == null ? options.levels : options.levelsByProgram[program] ?? options.levels),
    }.toList()
      ..sort();

    String labelOf(String code) {
      final entry = reference?.programByCode(code);
      return entry == null || entry.name.isEmpty ? code : '${entry.name} ($code)';
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Chip<String?>(
          icon: Icons.menu_book_outlined,
          hint: 'Toutes les filières',
          value: program,
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('Toutes les filières')),
            for (final code in programs)
              DropdownMenuItem<String?>(value: code, child: Text(labelOf(code), overflow: TextOverflow.ellipsis)),
          ],
          onChanged: onProgramChanged,
        ),
        _Chip<String?>(
          icon: Icons.stairs_outlined,
          hint: 'Tous les niveaux',
          value: levels.contains(level) ? level : null,
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('Tous les niveaux')),
            for (final l in levels) DropdownMenuItem<String?>(value: l, child: Text(l)),
          ],
          onChanged: onLevelChanged,
        ),
      ],
    );
  }
}

class _Chip<T> extends StatelessWidget {
  final IconData icon;
  final String hint;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T> onChanged;

  const _Chip({
    required this.icon,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textMuted),
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          hint: Text(hint, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          items: items,
          onChanged: (v) => onChanged(v as T),
          selectedItemBuilder: (context) => [
            for (final item in items)
              Row(
                children: [
                  Icon(icon, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DefaultTextStyle(
                      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      child: item.child,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
