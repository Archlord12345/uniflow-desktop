import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../ui/app_button.dart';
import 'uni/uni_mascot.dart';

/// États vides, de chargement et d'erreur, partagés par les écrans desktop qui
/// lisent Appwrite.
///
/// Sans eux, une requête refusée et une liste réellement vide se ressemblaient :
/// les deux donnaient un tableau sans lignes, sans explication.
///
/// `compact` : version resserrée (marges et mascotte réduites) pour un bloc
/// posé **dans** une page — une carte du tableau de bord, un panneau — plutôt
/// qu'en plein écran. En pleine taille, trois cartes en état de chargement
/// empilaient trois Uni de 96 px et repoussaient le reste sous le pli.

class DataLoadingView extends StatelessWidget {
  final String label;
  final bool compact;

  const DataLoadingView({
    super.key,
    this.label = 'Chargement des données…',
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    // Défilant : Uni est plus haut que l'ancien cercle et la vue est souvent
    // posée dans un `Expanded` d'une fenêtre basse.
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        vertical: compact ? AppSpacing.lg : AppSpacing.section,
        horizontal: AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          UniMascot(pose: UniPose.thinking, size: compact ? 64 : 96),
          const SizedBox(height: AppSpacing.sm),
          const UniDots(),
          const SizedBox(height: AppSpacing.md),
          Text(label, textAlign: TextAlign.center, style: AppTextStyles.body),
        ],
      ),
    );
  }
}

class DataEmptyView extends StatelessWidget {
  final String message;
  final IconData icon;
  final bool compact;

  /// Titre en gras au-dessus de l'explication (« Aucune note saisie »).
  /// Optionnel : un état vide court se lit très bien sans.
  final String? title;

  /// Bouton sous l'explication quand l'état vide a une sortie évidente
  /// (« Nouvelle conversation »). Sans lui, les écrans recomposaient leur
  /// propre colonne icône + texte + bouton, chacun avec ses marges.
  final Widget? action;

  const DataEmptyView({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.compact = false,
    this.title,
    this.action,
  });

  /// Largeur de lecture de l'explication : au-delà, une phrase de trois
  /// lignes s'étire sur toute la fenêtre et devient pénible à suivre.
  static const double readingWidth = 520;

  @override
  Widget build(BuildContext context) {
    // Défilant : posé directement dans un `Expanded` d'une fenêtre basse
    // (620 px avec une barre de filtres au-dessus), le bloc dépassait de
    // 68 px vers le bas.
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        vertical: compact ? AppSpacing.lg : 60,
        horizontal: AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Uni cherche à la loupe : l'icône passée reste disponible pour
          // les appels qui la personnalisent, en petit sous le personnage.
          UniMascot(pose: UniPose.search, size: compact ? 72 : 110),
          const SizedBox(height: AppSpacing.md),
          if (title != null) ...[
            Text(
              title!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: readingWidth),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: AppSpacing.lg),
            action!,
          ],
        ],
      ),
    );
  }
}

class DataErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  /// Titre du bloc ; « Lecture Appwrite impossible » par défaut, mais un écran
  /// qui sait ce qu'il chargeait peut être plus précis.
  final String title;
  final bool compact;

  const DataErrorView({
    super.key,
    required this.error,
    required this.onRetry,
    this.title = 'Lecture Appwrite impossible',
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        vertical: compact ? AppSpacing.lg : 50,
        horizontal: AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          UniMascot(pose: UniPose.sorry, size: compact ? 72 : 110),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
          ),
          const SizedBox(height: 6),
          Text(
            error.toString(),
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(fontSize: 12.5),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton.secondary(
            label: 'Réessayer',
            icon: Icons.refresh,
            height: 40,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
