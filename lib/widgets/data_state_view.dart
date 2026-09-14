import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(height: 14),
          Text(label, style: AppTextStyles.body),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: AppColors.textMuted),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 42, color: AppColors.danger),
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
