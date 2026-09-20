import 'package:appwrite/appwrite.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/appwrite_models.dart';
import '../models/user_role.dart';
import '../providers/appwrite_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/directory_provider.dart';
import '../repositories/academic_repository.dart';
import '../repositories/management_repository.dart';
import '../services/uniflow_api.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/data_state_view.dart';
import '../widgets/motion.dart';

// ---------------------------------------------------------------------------
// Sélecteur de cours commun
// ---------------------------------------------------------------------------

/// Cours retenu dans les écrans Devoirs / Notes / Présences. Partagé pour
/// qu'un enseignant qui passe des devoirs aux notes retrouve le même cours.
final selectedCourseIdProvider = StateProvider<String?>((ref) => null);

class _CoursePicker extends ConsumerWidget {
  const _CoursePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(scopedCoursesProvider).valueOrNull ?? const <AcademicCourse>[];
    final selected = ref.watch(selectedCourseIdProvider);
    final value = courses.any((c) => c.id == selected) ? selected : (courses.isEmpty ? null : courses.first.id);
    if (value != selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(selectedCourseIdProvider.notifier).state = value;
      });
    }
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          hint: const Text('Aucun cours dans votre périmètre', style: TextStyle(fontSize: 13)),
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          items: [
            for (final c in courses)
              DropdownMenuItem(
                value: c.id,
                child: Text('${c.code} · ${c.name} (${c.program} ${c.level})', overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) => ref.read(selectedCourseIdProvider.notifier).state = v,
        ),
      ),
    );
  }
}

String _formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _formatDateTime(DateTime d) =>
    '${_formatDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

// ---------------------------------------------------------------------------
// Devoirs
// ---------------------------------------------------------------------------

final _assignmentsOfCourseProvider = FutureProvider.family<List<AcademicAssignment>, String>((ref, courseId) async {
  final all = await ref.watch(academicRepositoryProvider).getAssignments();
  return all.where((a) => a.courseId == courseId).toList()
    ..sort((a, b) => b.dueDate.compareTo(a.dueDate));
});

final _submissionsProvider = FutureProvider.family<List<SubmissionInfo>, String>((ref, assignmentId) {
  return ref.watch(assignmentsApiProvider).submissionsOf(assignmentId);
});

/// Gestion des devoirs. Un enseignant crée, modifie, publie et corrige ;
/// un apprenant voit les sujets de ses cours et ses propres rendus.
class AssignmentsManagementScreen extends ConsumerWidget {
  const AssignmentsManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentRoleProvider);
    final canEdit = role == UserRole.teacher || role == UserRole.admin;
    final courseId = ref.watch(selectedCourseIdProvider);
    final courses = ref.watch(scopedCoursesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTopBar(
          title: 'Devoirs',
          subtitle: canEdit ? 'Publiez et corrigez les travaux de vos cours' : 'Les travaux demandés dans vos cours',
          actions: [
            if (canEdit)
              FilledButton.icon(
                onPressed: courseId == null ? null : () => _openEditor(context, ref, courseId: courseId),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nouveau devoir'),
              ),
          ],
        ),
        const Padding(padding: EdgeInsets.fromLTRB(28, 18, 28, 0), child: Align(alignment: Alignment.centerLeft, child: _CoursePicker())),
        Expanded(
          child: courses.when(
            loading: () => const Padding(padding: EdgeInsets.all(28), child: CardGridSkeleton(count: 3)),
            error: (e, _) => DataErrorView(error: e, onRetry: () => ref.invalidate(scopedCoursesProvider)),
            data: (_) {
              if (courseId == null) {
                return const DataEmptyView(
                  icon: Icons.task_outlined,
                  message: 'Aucun cours dans votre périmètre : les devoirs s\'affichent par cours.',
                );
              }
              final assignments = ref.watch(_assignmentsOfCourseProvider(courseId));
              return assignments.when(
                loading: () => const Padding(padding: EdgeInsets.all(28), child: CardGridSkeleton(count: 3)),
                error: (e, _) => DataErrorView(error: e, onRetry: () => ref.invalidate(_assignmentsOfCourseProvider(courseId))),
                data: (items) {
                  if (items.isEmpty) {
                    return DataEmptyView(
                      icon: Icons.task_outlined,
                      message: canEdit
                          ? 'Aucun devoir pour ce cours. Créez le premier avec « Nouveau devoir ».'
                          : 'Aucun devoir publié pour ce cours.',
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(28),
                    itemCount: items.length,
                    itemBuilder: (context, i) => CascadeIn(
                      index: i,
                      child: _AssignmentCard(
                        assignment: items[i],
                        canEdit: canEdit,
                        onEdit: () => _openEditor(context, ref, courseId: courseId, existing: items[i]),
                        onDelete: () => _delete(context, ref, items[i]),
                        onSubmissions: () => _openSubmissions(context, items[i]),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _openEditor(BuildContext context, WidgetRef ref, {required String courseId, AcademicAssignment? existing}) async {
    final courses = ref.read(scopedCoursesProvider).valueOrNull ?? const <AcademicCourse>[];
    final course = courses.where((c) => c.id == courseId).firstOrNull;
    if (course == null) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _AssignmentEditorDialog(course: course, existing: existing),
    );
    if (saved == true) ref.invalidate(_assignmentsOfCourseProvider(courseId));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, AcademicAssignment assignment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce devoir ?'),
        content: Text('« ${assignment.title} » disparaîtra pour tous les étudiants du cours.'),
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
      await ref.read(assignmentsApiProvider).delete(assignment.id);
      ref.invalidate(_assignmentsOfCourseProvider(assignment.courseId));
      if (context.mounted) showFeedback(context, message: 'Devoir supprimé.');
    } on AppwriteException catch (e) {
      if (context.mounted) {
        showFeedback(
          context,
          message: 'Suppression refusée.',
          detail: e.code == 401 ? 'Seul l\'auteur du devoir peut le supprimer.' : e.message,
          success: false,
        );
      }
    }
  }

  void _openSubmissions(BuildContext context, AcademicAssignment assignment) {
    Navigator.of(context).push(softRoute(_SubmissionsScreen(assignment: assignment)));
  }
}

class _AssignmentCard extends StatelessWidget {
  final AcademicAssignment assignment;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSubmissions;

  const _AssignmentCard({
    required this.assignment,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
    required this.onSubmissions,
  });

  @override
  Widget build(BuildContext context) {
    final due = DateTime.tryParse(assignment.dueDate);
    final overdue = due != null && due.isBefore(DateTime.now());
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (overdue ? AppColors.textMuted : AppColors.primaryBlue).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.task_outlined, color: overdue ? AppColors.textMuted : AppColors.primaryBlue),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(assignment.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.h3),
                const SizedBox(height: 4),
                Text(
                  [
                    assignment.courseCode,
                    if (due != null) 'À rendre le ${_formatDateTime(due)}',
                    if (assignment.status != null && assignment.status!.isNotEmpty) assignment.status!,
                  ].join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(color: overdue ? AppColors.danger : null),
                ),
                if ((assignment.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(assignment.description!, maxLines: 3, overflow: TextOverflow.ellipsis, style: AppTextStyles.body),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (canEdit)
            Wrap(
              spacing: 2,
              children: [
                IconButton(tooltip: 'Rendus et correction', onPressed: onSubmissions, icon: const Icon(Icons.fact_check_outlined, size: 20)),
                IconButton(tooltip: 'Modifier', onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 20)),
                IconButton(tooltip: 'Supprimer', onPressed: onDelete, icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.textMuted)),
              ],
            ),
        ],
      ),
    );
  }
}

class _AssignmentEditorDialog extends ConsumerStatefulWidget {
  final AcademicCourse course;
  final AcademicAssignment? existing;
  const _AssignmentEditorDialog({required this.course, this.existing});

  @override
  ConsumerState<_AssignmentEditorDialog> createState() => _AssignmentEditorDialogState();
}

class _AssignmentEditorDialogState extends ConsumerState<_AssignmentEditorDialog> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _description = TextEditingController(text: widget.existing?.description ?? '');
  late final _maxScore = TextEditingController(text: '20');
  late DateTime _due = DateTime.tryParse(widget.existing?.dueDate ?? '') ??
      DateTime.now().add(const Duration(days: 7)).copyWith(hour: 23, minute: 59);
  String _type = 'DEVOIR';
  bool _allowLate = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _maxScore.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _due,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_due));
    setState(() => _due = DateTime(date.year, date.month, date.day, time?.hour ?? 23, time?.minute ?? 59));
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Le titre est requis.');
      return;
    }
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final draft = AssignmentDraft(
      courseId: widget.course.id,
      courseCode: widget.course.code,
      title: _title.text,
      description: _description.text,
      dueDate: _due,
      type: _type,
      maxScore: double.tryParse(_maxScore.text.replaceAll(',', '.')) ?? 20,
      allowLate: _allowLate,
    );
    try {
      final api = ref.read(assignmentsApiProvider);
      if (widget.existing == null) {
        await api.create(draft, teacherId: user.id, teacherName: user.name);
      } else {
        final data = draft.toData(teacherId: user.id, teacherName: user.name)..remove('publishedAt')..remove('status');
        await api.update(widget.existing!.id, data);
      }
      if (!mounted) return;
      showFeedback(context, message: widget.existing == null ? 'Devoir publié.' : 'Devoir mis à jour.');
      Navigator.pop(context, true);
    } on AppwriteException catch (e) {
      setState(() {
        _busy = false;
        _error = e.code == 401
            ? 'Appwrite refuse l\'écriture : seul l\'auteur du devoir peut le modifier.'
            : (e.message ?? 'Enregistrement impossible.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Nouveau devoir · ${widget.course.code}' : 'Modifier le devoir'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(controller: _title, autofocus: true, decoration: const InputDecoration(labelText: 'Titre')),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Consignes', alignLabelWithHint: true),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _type,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: const [
                        DropdownMenuItem(value: 'DEVOIR', child: Text('Devoir')),
                        DropdownMenuItem(value: 'TP', child: Text('Travaux pratiques')),
                        DropdownMenuItem(value: 'PROJET', child: Text('Projet')),
                        DropdownMenuItem(value: 'QUIZ', child: Text('Quiz')),
                      ],
                      onChanged: (v) => setState(() => _type = v ?? 'DEVOIR'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: _maxScore,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Barème'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(10),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date limite', prefixIcon: Icon(Icons.event_outlined, size: 19)),
                  child: Text(_formatDateTime(_due)),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Accepter les rendus en retard', style: TextStyle(fontSize: 13.5)),
                value: _allowLate,
                onChanged: (v) => setState(() => _allowLate = v),
              ),
              if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('Annuler')),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(widget.existing == null ? 'Publier' : 'Enregistrer'),
        ),
      ],
    );
  }
}

/// Rendus d'un devoir et correction.
class _SubmissionsScreen extends ConsumerWidget {
  final AcademicAssignment assignment;
  const _SubmissionsScreen({required this.assignment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submissions = ref.watch(_submissionsProvider(assignment.id));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Rendus · ${assignment.title}', overflow: TextOverflow.ellipsis),
        backgroundColor: AppColors.cardWhite,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: submissions.when(
        loading: () => const Padding(padding: EdgeInsets.all(28), child: TableSkeleton()),
        error: (e, _) => DataErrorView(error: e, onRetry: () => ref.invalidate(_submissionsProvider(assignment.id))),
        data: (items) {
          if (items.isEmpty) {
            return const DataEmptyView(icon: Icons.inbox_outlined, message: 'Aucun rendu pour l\'instant.');
          }
          return ListView.builder(
            padding: const EdgeInsets.all(28),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final s = items[i];
              return CascadeIn(
                index: i,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.cardWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.inputBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.studentName.isEmpty ? s.studentId : s.studentName, style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(
                              [
                                if (s.submittedAt != null) 'Rendu le ${_formatDateTime(s.submittedAt!)}',
                                s.status,
                                if (s.score != null) '${s.score} / ${assignment.title.isEmpty ? 20 : 20}',
                              ].join('  ·  '),
                              style: AppTextStyles.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (s.fileId.isNotEmpty)
                        IconButton(
                          tooltip: 'Ouvrir le fichier',
                          onPressed: () => launchUrl(Uri.parse(ref.read(appwriteServiceProvider).fileViewUrl(s.fileId))),
                          icon: const Icon(Icons.attach_file, size: 20),
                        ),
                      FilledButton.tonal(
                        onPressed: () => _grade(context, ref, s),
                        child: Text(s.score == null ? 'Noter' : 'Modifier la note'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _grade(BuildContext context, WidgetRef ref, SubmissionInfo submission) async {
    final scoreController = TextEditingController(text: submission.score?.toString() ?? '');
    final feedbackController = TextEditingController(text: submission.feedback);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Noter ${submission.studentName}'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: scoreController, autofocus: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Note')),
              const SizedBox(height: 12),
              TextField(controller: feedbackController, maxLines: 3, decoration: const InputDecoration(labelText: 'Commentaire')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final score = double.tryParse(scoreController.text.replaceAll(',', '.'));
    if (score == null) {
      showFeedback(context, message: 'Note invalide.', success: false);
      return;
    }
    try {
      await ref.read(assignmentsApiProvider).gradeSubmission(submission.id, score: score, feedback: feedbackController.text);
      ref.invalidate(_submissionsProvider(assignment.id));
      if (context.mounted) showFeedback(context, message: 'Note enregistrée.');
    } on AppwriteException catch (e) {
      if (context.mounted) {
        showFeedback(
          context,
          message: 'Correction refusée par Appwrite.',
          detail: e.code == 401
              ? 'Le rendu appartient à l\'étudiant ; la correction doit passer par un service serveur (à signaler).'
              : e.message,
          success: false,
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Notes
// ---------------------------------------------------------------------------

final _rosterProvider = FutureProvider.family<GradeRoster, String>((ref, courseId) {
  return ref.watch(gradesApiProvider).roster(courseId);
});

final _myGradesProvider = FutureProvider<List<AcademicGrade>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  final all = await ref.watch(academicRepositoryProvider).getAllGrades();
  return all.where((g) => g.studentId == user.id).toList();
});

/// Saisie des notes par l'enseignant (grille étudiants × évaluations, via
/// `/academic-grades`) ; un apprenant voit son propre relevé.
class GradesManagementScreen extends ConsumerWidget {
  const GradesManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentRoleProvider);
    final canEdit = role == UserRole.teacher || role == UserRole.admin;
    if (!canEdit) return const _MyGradesView();

    final courseId = ref.watch(selectedCourseIdProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTopBar(
          title: 'Notes',
          subtitle: 'Saisie et publication des évaluations de vos cours',
          actions: [
            if (courseId != null)
              FilledButton.icon(
                onPressed: () => _addEvaluation(context, ref, courseId),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nouvelle évaluation'),
              ),
          ],
        ),
        const Padding(padding: EdgeInsets.fromLTRB(28, 18, 28, 0), child: Align(alignment: Alignment.centerLeft, child: _CoursePicker())),
        Expanded(
          child: courseId == null
              ? const DataEmptyView(icon: Icons.grade_outlined, message: 'Aucun cours dans votre périmètre.')
              : ref.watch(_rosterProvider(courseId)).when(
                  loading: () => const Padding(padding: EdgeInsets.all(28), child: TableSkeleton(rows: 8)),
                  error: (e, _) => DataErrorView(error: e, onRetry: () => ref.invalidate(_rosterProvider(courseId))),
                  data: (roster) => _GradeGrid(roster: roster),
                ),
        ),
      ],
    );
  }

  Future<void> _addEvaluation(BuildContext context, WidgetRef ref, String courseId) async {
    final title = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nouvelle évaluation'),
        content: SizedBox(
          width: 360,
          child: TextField(
            controller: title,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Intitulé (CC1, TP, Examen…)'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Ajouter')),
        ],
      ),
    );
    if (ok != true || title.text.trim().isEmpty) return;
    ref.read(_pendingEvaluationsProvider(courseId).notifier).update((s) => {...s, title.text.trim()});
  }
}

/// Colonnes ajoutées mais encore vides : elles n'existent côté serveur qu'à
/// la première note saisie.
final _pendingEvaluationsProvider = StateProvider.family<Set<String>, String>((ref, _) => <String>{});

class _GradeGrid extends ConsumerWidget {
  final GradeRoster roster;
  const _GradeGrid({required this.roster});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(_pendingEvaluationsProvider(roster.courseId));
    final titles = [...roster.evaluationTitles, ...pending.where((p) => !roster.evaluationTitles.contains(p))];
    if (roster.students.isEmpty) {
      return const DataEmptyView(icon: Icons.people_outline, message: 'Aucun apprenant inscrit à ce cours.');
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary, fontSize: 12),
            columns: [
              const DataColumn(label: Text('Apprenant')),
              for (final t in titles) DataColumn(label: Text(t)),
              const DataColumn(label: Text('Moyenne')),
            ],
            rows: [
              for (var i = 0; i < roster.students.length; i++)
                DataRow(cells: [
                  DataCell(Text('${roster.students[i].name}${roster.students[i].matricule.isNotEmpty ? ' · ${roster.students[i].matricule}' : ''}')),
                  for (final t in titles)
                    DataCell(
                      _GradeCell(grade: roster.gradeOf(roster.students[i].userId, t)),
                      onTap: () => _edit(context, ref, roster.students[i], t, roster.gradeOf(roster.students[i].userId, t)),
                    ),
                  DataCell(Text(_average(roster.students[i].userId), style: const TextStyle(fontWeight: FontWeight.w700))),
                ]),
            ],
          ),
        ),
      ),
    );
  }

  String _average(String studentId) {
    final grades = roster.grades.where((g) => g.studentId == studentId).toList();
    if (grades.isEmpty) return '—';
    var weighted = 0.0;
    var coefficients = 0.0;
    for (final g in grades) {
      weighted += (g.score / g.maxScore) * 20 * g.coefficient;
      coefficients += g.coefficient;
    }
    return (weighted / coefficients).toStringAsFixed(2);
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, RosterStudent student, String title, AcademicGrade? existing) async {
    final score = TextEditingController(text: existing == null ? '' : existing.score.toStringAsFixed(0));
    final max = TextEditingController(text: existing == null ? '20' : existing.maxScore.toStringAsFixed(0));
    final coefficient = TextEditingController(text: existing == null ? '1' : existing.coefficient.toStringAsFixed(0));
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$title · ${student.name}'),
        content: SizedBox(
          width: 360,
          child: Row(
            children: [
              Expanded(child: TextField(controller: score, autofocus: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Note'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: max, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Sur'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: coefficient, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Coef.'))),
            ],
          ),
        ),
        actions: [
          if (existing != null)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'delete'),
              child: const Text('Supprimer', style: TextStyle(color: AppColors.danger)),
            ),
          TextButton(onPressed: () => Navigator.pop(dialogContext, null), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, 'save'), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (action == null || !context.mounted) return;
    final api = ref.read(gradesApiProvider);
    try {
      if (action == 'delete' && existing != null) {
        await api.delete(courseId: roster.courseId, studentId: student.userId, gradeId: existing.id);
        if (context.mounted) showFeedback(context, message: 'Note supprimée.');
      } else {
        final value = int.tryParse(score.text.trim());
        final maxValue = int.tryParse(max.text.trim()) ?? 20;
        if (value == null || value < 0 || value > maxValue) {
          if (context.mounted) showFeedback(context, message: 'Note invalide (entier entre 0 et $maxValue).', success: false);
          return;
        }
        await api.upsert(
          courseId: roster.courseId,
          studentId: student.userId,
          evaluationTitle: title,
          score: value,
          maxScore: maxValue,
          coefficient: int.tryParse(coefficient.text.trim()) ?? 1,
        );
        if (context.mounted) showFeedback(context, message: 'Note enregistrée pour ${student.name}.');
      }
      ref.invalidate(_rosterProvider(roster.courseId));
    } on ApiException catch (e) {
      if (context.mounted) showFeedback(context, message: 'Refusé par le serveur.', detail: e.message, success: false);
    }
  }
}

class _GradeCell extends StatelessWidget {
  final AcademicGrade? grade;
  const _GradeCell({this.grade});

  @override
  Widget build(BuildContext context) {
    if (grade == null) {
      return const Text('—', style: TextStyle(color: AppColors.textMuted));
    }
    final ratio = grade!.score / grade!.maxScore;
    final color = ratio >= 0.5 ? AppColors.success : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(6)),
      child: Text(
        '${grade!.score.toStringAsFixed(grade!.score.truncateToDouble() == grade!.score ? 0 : 1)}/${grade!.maxScore.toStringAsFixed(0)}',
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12.5),
      ),
    );
  }
}

class _MyGradesView extends ConsumerWidget {
  const _MyGradesView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grades = ref.watch(_myGradesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppTopBar(title: 'Mes notes', subtitle: 'Vos résultats, par cours et par évaluation'),
        Expanded(
          child: grades.when(
            loading: () => const Padding(padding: EdgeInsets.all(28), child: TableSkeleton()),
            error: (e, _) => DataErrorView(error: e, onRetry: () => ref.invalidate(_myGradesProvider)),
            data: (items) {
              if (items.isEmpty) {
                return const DataEmptyView(icon: Icons.grade_outlined, message: 'Aucune note publiée pour l\'instant.');
              }
              final byCourse = <String, List<AcademicGrade>>{};
              for (final g in items) {
                byCourse.putIfAbsent(g.courseCode, () => []).add(g);
              }
              final codes = byCourse.keys.toList()..sort();
              return ListView.builder(
                padding: const EdgeInsets.all(28),
                itemCount: codes.length,
                itemBuilder: (context, i) {
                  final list = byCourse[codes[i]]!;
                  return CascadeIn(
                    index: i,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.cardWhite,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.inputBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(codes[i], style: AppTextStyles.h3),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final g in list)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.inputFill,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(g.evaluationTitle, style: AppTextStyles.bodySmall),
                                      const SizedBox(height: 2),
                                      _GradeCell(grade: g),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Bibliothèque
// ---------------------------------------------------------------------------

class LibraryItem {
  final String id;
  final String title;
  final String course;
  final String type;
  final String category;
  final String size;
  final String description;
  final String fileId;
  const LibraryItem({
    required this.id,
    required this.title,
    this.course = '',
    this.type = '',
    this.category = '',
    this.size = '',
    this.description = '',
    this.fileId = '',
  });
}

final libraryProvider = FutureProvider<List<LibraryItem>>((ref) async {
  final service = ref.watch(appwriteServiceProvider);
  final response = await service.databases.listDocuments(
    databaseId: service.databaseId,
    collectionId: 'academic_library',
    queries: [Query.orderDesc('\$createdAt'), Query.limit(200)],
  );
  return response.documents.map((d) {
    final data = d.data;
    return LibraryItem(
      id: d.$id,
      title: data['title'] as String? ?? '',
      course: data['course'] as String? ?? '',
      type: data['type'] as String? ?? '',
      category: data['category'] as String? ?? '',
      size: data['size'] as String? ?? '',
      description: data['description'] as String? ?? '',
      fileId: data['fileId'] as String? ?? '',
    );
  }).toList();
});

/// Bibliothèque numérique : documents de `academic_library`, fichiers dans
/// le bucket `uniflow_assets`. Enseignants et administration téléversent.
class LibraryManagementScreen extends ConsumerWidget {
  const LibraryManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(libraryProvider);
    final role = ref.watch(currentRoleProvider);
    final canUpload = role == UserRole.teacher || role == UserRole.admin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTopBar(
          title: 'Bibliothèque',
          subtitle: 'Supports de cours et ressources partagées',
          actions: [
            if (canUpload)
              FilledButton.icon(
                onPressed: () => _upload(context, ref),
                icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                label: const Text('Téléverser'),
              ),
          ],
        ),
        Expanded(
          child: items.when(
            loading: () => const Padding(padding: EdgeInsets.all(28), child: CardGridSkeleton()),
            error: (e, _) => DataErrorView(error: e, onRetry: () => ref.invalidate(libraryProvider)),
            data: (list) {
              if (list.isEmpty) {
                return const DataEmptyView(icon: Icons.library_books_outlined, message: 'Aucune ressource pour l\'instant.');
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (var i = 0; i < list.length; i++)
                      CascadeIn(
                        index: i,
                        child: _LibraryCard(
                          item: list[i],
                          onOpen: list[i].fileId.isEmpty
                              ? null
                              : () => launchUrl(Uri.parse(ref.read(appwriteServiceProvider).fileViewUrl(list[i].fileId))),
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

  Future<void> _upload(BuildContext context, WidgetRef ref) async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Documents', extensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', 'txt', 'zip', 'png', 'jpg', 'jpeg']),
      ],
    );
    if (file == null || !context.mounted) return;
    final courses = ref.read(scopedCoursesProvider).valueOrNull ?? const <AcademicCourse>[];
    final title = TextEditingController(text: file.name.split('.').first);
    final description = TextEditingController();
    String? courseId = courses.isEmpty ? null : courses.first.id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('Téléverser une ressource'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Titre')),
                const SizedBox(height: 12),
                if (courses.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: courseId,
                    decoration: const InputDecoration(labelText: 'Cours'),
                    items: [for (final c in courses) DropdownMenuItem(value: c.id, child: Text('${c.code} · ${c.name}', overflow: TextOverflow.ellipsis))],
                    onChanged: (v) => setState(() => courseId = v),
                  ),
                const SizedBox(height: 12),
                TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerLeft, child: Text(file.name, style: AppTextStyles.bodySmall)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Téléverser')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final service = ref.read(appwriteServiceProvider);
    final user = ref.read(currentUserProvider);
    final course = courses.where((c) => c.id == courseId).firstOrNull;
    try {
      final length = await file.length();
      final created = await service.storage.createFile(
        bucketId: service.chatFilesBucketId,
        fileId: ID.unique(),
        file: InputFile.fromPath(path: file.path, filename: file.name),
        permissions: [Permission.read(Role.users())],
      );
      await service.databases.createDocument(
        databaseId: service.databaseId,
        collectionId: 'academic_library',
        documentId: ID.unique(),
        data: {
          'title': title.text.trim(),
          'courseId': course?.id ?? '',
          'course': course == null ? '' : '${course.code} · ${course.name}',
          'type': file.name.contains('.') ? file.name.split('.').last.toUpperCase() : '',
          'category': 'Support de cours',
          'size': _humanSize(length),
          'description': description.text.trim(),
          'fileId': created.$id,
        },
        permissions: [
          Permission.read(Role.users()),
          if (user != null) Permission.update(Role.user(user.id)),
          if (user != null) Permission.delete(Role.user(user.id)),
        ],
      );
      ref.invalidate(libraryProvider);
      if (context.mounted) showFeedback(context, message: 'Ressource publiée.', detail: file.name);
    } on AppwriteException catch (e) {
      if (context.mounted) showFeedback(context, message: 'Téléversement refusé.', detail: e.message, success: false);
    }
  }

  static String _humanSize(int bytes) {
    if (bytes < 1024) return '$bytes o';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} Ko';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }
}

class _LibraryCard extends StatelessWidget {
  final LibraryItem item;
  final VoidCallback? onOpen;
  const _LibraryCard({required this.item, this.onOpen});

  IconData get _icon => switch (item.type.toUpperCase()) {
        'PDF' => Icons.picture_as_pdf_outlined,
        'PPT' || 'PPTX' => Icons.slideshow_outlined,
        'XLS' || 'XLSX' => Icons.table_chart_outlined,
        'PNG' || 'JPG' || 'JPEG' => Icons.image_outlined,
        'ZIP' => Icons.folder_zip_outlined,
        _ => Icons.description_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(14),
      child: Container(
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
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: AppColors.primary50, borderRadius: BorderRadius.circular(10)),
                  child: Icon(_icon, color: AppColors.primaryBlue, size: 22),
                ),
                const Spacer(),
                if (item.type.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(999)),
                    child: Text(item.type.toUpperCase(), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.h3),
            const SizedBox(height: 4),
            Text(
              [if (item.course.isNotEmpty) item.course, if (item.size.isNotEmpty) item.size].join('  ·  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall,
            ),
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.body),
            ],
            if (onOpen != null) ...[
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(Icons.open_in_new, size: 14, color: AppColors.primaryBlue),
                  SizedBox(width: 6),
                  Text('Ouvrir', style: TextStyle(fontSize: 12.5, color: AppColors.primaryBlue, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
