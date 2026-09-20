import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/appwrite_models.dart';
import '../providers/auth_provider.dart';
import '../repositories/personal_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/data_state_view.dart';
import '../widgets/motion.dart';

/// Espace personnel d'un compte indépendant (`PERSONAL`) : ses matières,
/// lues dans `personal_subjects`. C'est l'équivalent de
/// `IndependentWorkspacePage` du web ; un compte universitaire ne le voit pas
/// (garde `personalOnly`), et inversement un compte personnel n'a aucun écran
/// de cursus d'établissement.
class PersonalWorkspaceScreen extends ConsumerWidget {
  const PersonalWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(personalSubjectsProvider);
    final user = ref.watch(currentUserProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTopBar(
          title: 'Espace personnel',
          subtitle: user == null ? null : 'Vos matières et votre organisation, ${user.name}',
          actions: [
            FilledButton.icon(
              onPressed: user == null ? null : () => _addSubject(context, ref, user.id),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nouvelle matière'),
            ),
          ],
        ),
        Expanded(
          child: subjects.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(28),
              child: CardGridSkeleton(count: 4),
            ),
            error: (error, _) => DataErrorView(
              error: error,
              onRetry: () => ref.invalidate(personalSubjectsProvider),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const DataEmptyView(
                  icon: Icons.auto_awesome_outlined,
                  message: 'Aucune matière pour l\'instant. Ajoutez votre première '
                      'matière pour organiser votre travail.',
                );
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (var i = 0; i < items.length; i++)
                      CascadeIn(
                        index: i,
                        child: _SubjectCard(
                          subject: items[i],
                          onDelete: () => _deleteSubject(context, ref, items[i]),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _addSubject(BuildContext context, WidgetRef ref, String ownerId) async {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final instructorController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nouvelle matière'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nom de la matière'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(labelText: 'Code (facultatif)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: instructorController,
                decoration: const InputDecoration(labelText: 'Intervenant (facultatif)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Ajouter')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    if (nameController.text.trim().isEmpty) {
      showFeedback(context, message: 'Le nom de la matière est requis.', success: false);
      return;
    }
    try {
      await ref.read(personalRepositoryProvider).createSubject(
            ownerId: ownerId,
            name: nameController.text,
            code: codeController.text,
            instructor: instructorController.text,
          );
      ref.invalidate(personalSubjectsProvider);
      if (context.mounted) showFeedback(context, message: 'Matière ajoutée.');
    } catch (error) {
      if (context.mounted) {
        showFeedback(context, message: 'Ajout impossible.', detail: '$error', success: false);
      }
    }
  }

  Future<void> _deleteSubject(BuildContext context, WidgetRef ref, PersonalSubject subject) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer la matière ?'),
        content: Text('« ${subject.name} » sera retirée de votre espace.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(personalRepositoryProvider).deleteSubject(subject.id);
      ref.invalidate(personalSubjectsProvider);
      if (context.mounted) showFeedback(context, message: 'Matière supprimée.');
    } catch (error) {
      if (context.mounted) {
        showFeedback(context, message: 'Suppression impossible.', detail: '$error', success: false);
      }
    }
  }
}

class _SubjectCard extends StatelessWidget {
  final PersonalSubject subject;
  final VoidCallback onDelete;
  const _SubjectCard({required this.subject, required this.onDelete});

  Color get _accent {
    final hex = (subject.colorHex ?? '').replaceFirst('#', '');
    if (hex.length == 6) {
      final value = int.tryParse(hex, radix: 16);
      if (value != null) return Color(0xFF000000 | value);
    }
    return AppColors.teal;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: _accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  subject.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h3,
                ),
              ),
              IconButton(
                tooltip: 'Supprimer',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textMuted),
              ),
            ],
          ),
          if ((subject.code ?? '').isNotEmpty)
            Text(subject.code!, style: AppTextStyles.bodySmall),
          const SizedBox(height: 8),
          Text(
            (subject.instructor ?? '').isEmpty ? 'Sans intervenant' : subject.instructor!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body,
          ),
          if ((subject.credits ?? 0) > 0) ...[
            const SizedBox(height: 6),
            Text('${subject.credits} crédits', style: AppTextStyles.bodySmall),
          ],
        ],
      ),
    );
  }
}
