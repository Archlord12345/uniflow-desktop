import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'uni/uni_mascot.dart';

/// États vides, de chargement et d'erreur, partagés par les écrans desktop qui
/// lisent Appwrite.
///
/// Sans eux, une requête refusée et une liste réellement vide se ressemblaient :
/// les deux donnaient un tableau sans lignes, sans explication.

class DataLoadingView extends StatelessWidget {
  final String label;
  const DataLoadingView({super.key, this.label = 'Chargement des données…'});

  @override
  Widget build(BuildContext context) {
    // Défilant : Uni est plus haut que l'ancien cercle et la vue est souvent
    // posée dans un `Expanded` d'une fenêtre basse.
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const UniMascot(pose: UniPose.thinking, size: 96),
          const SizedBox(height: 10),
          const UniDots(),
          const SizedBox(height: 12),
          Text(label, textAlign: TextAlign.center, style: AppTextStyles.body),
        ],
      ),
    );
  }
}

class DataEmptyView extends StatelessWidget {
  final String message;
  final IconData icon;

  const DataEmptyView({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    // Défilant : posé directement dans un `Expanded` d'une fenêtre basse
    // (620 px avec une barre de filtres au-dessus), le bloc dépassait de
    // 68 px vers le bas.
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Uni cherche à la loupe : l'icône passée reste disponible pour
          // les appels qui la personnalisent, en petit sous le personnage.
          const UniMascot(pose: UniPose.search, size: 110),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.body,
          ),
        ],
      ),
    );
  }
}

class DataErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const DataErrorView({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const UniMascot(pose: UniPose.sorry, size: 110),
          const SizedBox(height: 12),
          const Text(
            'Lecture Appwrite impossible',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
          ),
          const SizedBox(height: 6),
          Text(
            error.toString(),
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(fontSize: 12.5),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}
