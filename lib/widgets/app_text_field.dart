import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Champ de saisie custom réutilisé sur tous les formulaires de l'app
/// (login, création d'étudiant, d'enseignant, etc.)
///
/// Affiche : un label au-dessus, un champ stylé (fond gris clair, bordure
/// qui devient bleue au focus), une icône optionnelle à gauche, et un
/// bouton "œil" pour afficher/masquer le texte si c'est un champ mot de passe.
class AppTextField extends StatefulWidget {
  final String label;   // texte affiché au-dessus du champ (ex: "Email")
  final String hint;    // texte d'exemple affiché en placeholder (ex: "admin@uniflow.edu")
  final bool obscureText; // true = champ mot de passe (texte masqué par défaut)
  final IconData? prefixIcon; // icône optionnelle à gauche du texte saisi
  final TextEditingController? controller; // pour récupérer/contrôler la valeur saisie
  final TextInputType keyboardType; // type de clavier (texte, email, etc.)

  const AppTextField({
    super.key,
    required this.label,
    required this.hint,
    this.obscureText = false,
    this.prefixIcon,
    this.controller,
    this.keyboardType = TextInputType.text,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  // Etat local qui suit si le texte est actuellement masqué ou visible.
  // Initialisé à la valeur de obscureText passée par le parent,
  // puis modifiable indépendamment via le bouton "œil".
  late bool _obscure = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label au-dessus du champ (ex: "Mot de passe")
        Text(widget.label, style: AppTextStyles.label),
        const SizedBox(height: 8),
        TextField(
          controller: widget.controller,
          obscureText: _obscure,
          keyboardType: widget.keyboardType,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(
              fontSize: 14,
              color: AppColors.textMuted,
            ),
            filled: true,
            fillColor: AppColors.inputFill, // fond gris clair du champ
            // icône à gauche (ex: enveloppe pour l'email, cadenas pour le mot de passe)
            prefixIcon: widget.prefixIcon != null
                ? Icon(widget.prefixIcon, size: 20, color: AppColors.textMuted)
                : null,
            // bouton "œil" affiché uniquement si c'est un champ mot de passe,
            // permet de basculer entre texte masqué / visible
            suffixIcon: widget.obscureText
                ? IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  )
                : null,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            // Bordure par défaut (état neutre, ni focus ni erreur)
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.inputBorder),
            ),
            // Bordure quand le champ n'est pas sélectionné (même style que "border" ici)
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.inputBorder),
            ),
            // Bordure bleue et légèrement plus épaisse quand l'utilisateur
            // clique/sélectionne le champ, pour un feedback visuel clair
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppColors.primaryBlue,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
