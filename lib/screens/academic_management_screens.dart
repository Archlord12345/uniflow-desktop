import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_bar.dart';
import '../repositories/academic_repository.dart';
import '../models/appwrite_models.dart';

class AssignmentsManagementScreen extends ConsumerWidget {
  const AssignmentsManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync = ref.watch(FutureProvider((ref) => ref.read(academicRepositoryProvider).getAssignments()));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTopBar(
                title: 'Gestion des Devoirs',
                subtitle: 'Publiez et suivez les travaux demandés aux étudiants',
                actions: [
                  ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.add), label: const Text('Nouveau Devoir')),
                ],
              ),
              const SizedBox(height: 24),
              assignmentsAsync.when(
                data: (list) => _buildTable(list),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Erreur: $e'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTable(List<AcademicAssignment> list) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.inputBorder)),
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Titre')),
          DataColumn(label: Text('UE')),
          DataColumn(label: Text('Date limite')),
          DataColumn(label: Text('Statut')),
          DataColumn(label: Text('Actions')),
        ],
        rows: list.map((a) => DataRow(cells: [
          DataCell(Text(a.title)),
          DataCell(Text(a.courseCode)),
          DataCell(Text(a.dueDate)),
          DataCell(Text(a.status ?? 'PENDING')),
          DataCell(IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () {})),
        ])).toList(),
      ),
    );
  }
}

class GradesManagementScreen extends ConsumerWidget {
  const GradesManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradesAsync = ref.watch(FutureProvider((ref) => ref.read(academicRepositoryProvider).getAllGrades()));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTopBar(
                title: 'Gestion des Notes',
                subtitle: 'Saisie et consultation des résultats académiques',
                actions: [
                  OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.upload_file), label: const Text('Importer CSV')),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.add), label: const Text('Saisie rapide')),
                ],
              ),
              const SizedBox(height: 24),
              gradesAsync.when(
                data: (list) => _buildTable(list),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Erreur: $e'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTable(List<AcademicGrade> list) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.inputBorder)),
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Étudiant ID')),
          DataColumn(label: Text('UE')),
          DataColumn(label: Text('Évaluation')),
          DataColumn(label: Text('Note')),
          DataColumn(label: Text('Coeff.')),
        ],
        rows: list.map((g) => DataRow(cells: [
          DataCell(Text(g.studentId)),
          DataCell(Text(g.courseCode)),
          DataCell(Text(g.evaluationTitle)),
          DataCell(Text('${g.score}/${g.maxScore}')),
          DataCell(Text('${g.coefficient}')),
        ])).toList(),
      ),
    );
  }
}

class LibraryManagementScreen extends ConsumerWidget {
  const LibraryManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTopBar(
                title: 'Bibliothèque Numérique',
                subtitle: 'Gérez les ressources et supports de cours (Buckets Appwrite)',
                actions: [
                  ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.cloud_upload_outlined), label: const Text('Téléverser un fichier')),
                ],
              ),
              const SizedBox(height: 40),
              const Center(
                child: Column(
                  children: [
                    Icon(Icons.folder_open, size: 64, color: AppColors.textMuted),
                    SizedBox(height: 16),
                    Text('Explorateur de fichiers Appwrite Storage', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Connectez-vous au bucket uniflow_assets pour voir les fichiers.', style: TextStyle(color: AppColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
