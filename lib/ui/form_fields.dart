import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/uni_icons.dart';

export '../widgets/app_text_field.dart' show AppTextField;
export '../widgets/auth_chrome.dart'
    show AuthDropdown, GradientButton, ErrorBanner;

/// Libellé + champ, disposition commune à tous les formulaires : le libellé
/// au-dessus (13 px, semi-gras), le champ dessous, une aide facultative.
/// Les formulaires qui posaient le libellé à l'intérieur du champ le
/// perdaient dès la saisie.
class LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  final String? help;
  final bool required;

  const LabeledField({
    super.key,
    required this.label,
    required this.child,
    this.help,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = UniFlowColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            style: AppTextStyles.label.copyWith(color: colors.text),
            children: [
              if (required)
                const TextSpan(
                    text: ' *', style: TextStyle(color: AppColors.danger)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        child,
        if (help != null) ...[
          const SizedBox(height: 6),
          Text(help!, style: AppTextStyles.bodySmall),
        ],
      ],
    );
  }
}

/// Champ de recherche compact avec loupe, utilisé dans les en-têtes de liste
/// et la barre supérieure.
class SearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final double height;

  const SearchField({
    super.key,
    this.hint = 'Rechercher…',
    this.onChanged,
    this.controller,
    this.focusNode,
    this.height = 40,
  });

  @override
  Widget build(BuildContext context) {
    final colors = UniFlowColors.of(context);
    return SizedBox(
      height: height,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        style: TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 13.5,
            color: colors.text),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: PhosphorIcon(UniIcons.search(UniIconStyle.bold),
              size: 18, color: colors.muted),
          isDense: true,
          filled: true,
          fillColor: colors.surfaceMuted,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: colors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: colors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: colors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}
