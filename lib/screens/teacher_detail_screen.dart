import '../models/app_destination.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/teacher.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/app_breadcrumb.dart';
import '../ui/status_badge.dart';
import 'messaging_screen.dart';

/// Page de détail d'un enseignant. Aucune maquette spécifique ne l'illustre,
/// donc cette page reprend la même structure que [StudentDetailScreen]
/// pour rester cohérente avec le reste de l'application.
class TeacherDetailScreen extends StatelessWidget {
  final Teacher teacher;

  const TeacherDetailScreen({super.key, required this.teacher});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          AppSidebar(
            selected: AppDestination.teachers,
            onSelect: (item) => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopBar(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _InfoCard(
                          title: 'Informations professionnelles',
                          rows: [
                            ('Email', teacher.email),
                            ('Téléphone', teacher.telephone),
                            ('Département', teacher.departement),
                            ('Spécialité', teacher.specialite),
                            ("Date d'embauche", teacher.dateEmbauche),
                            ('Cours actifs', teacher.coursActifs.toString()),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _HistoryCard(historique: teacher.historique),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Fil d'Ariane + carte profil (avatar, nom, statut, actions).
  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
      decoration: const BoxDecoration(color: AppColors.cardWhite),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppBreadcrumb(
            items: ['Enseignants', 'Pr. ${teacher.fullName}'],
            onRootTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                    color: teacher.avatarColor, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(
                  teacher.initials,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryBlue),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pr. ${teacher.fullName}',
                      style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(teacher.id, style: AppTextStyles.body),
                        const SizedBox(width: 8),
                        StatusBadge.fromStatus(teacher.statut),
                      ],
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  // TODO: ouvrir le formulaire d'édition de l'enseignant
                },
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Modifier'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.inputBorder),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () {
                  // La messagerie s'adresse par pseudo, pas par identifiant
                  // interne : on ouvre l'écran avec le nom de l'enseignant
                  // pré-rempli dans la recherche de contact, à charge pour
                  // l'administrateur de confirmer le bon interlocuteur.
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          MessagingScreen(initialQuery: teacher.fullName),
                    ),
                  );
                },
                icon: const Icon(Icons.mail_outline, size: 16),
                label: const Text('Envoyer un message'),
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 13)),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<(String, String)> rows;

  const _InfoCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.h2),
          const SizedBox(height: 18),
          for (int i = 0; i < rows.length; i += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      child: _FieldValue(label: rows[i].$1, value: rows[i].$2)),
                  if (i + 1 < rows.length)
                    Expanded(
                        child: _FieldValue(
                            label: rows[i + 1].$1, value: rows[i + 1].$2))
                  else
                    const Expanded(child: SizedBox()),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FieldValue extends StatelessWidget {
  final String label;
  final String value;

  const _FieldValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 0.3),
        ),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final List<TeacherHistoryEvent> historique;

  const _HistoryCard({required this.historique});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Historique', style: AppTextStyles.h2),
          const SizedBox(height: 16),
          if (historique.isEmpty)
            const Text(
              'Aucun événement enregistré pour cet enseignant. Cet historique '
              'se remplira quand une collection de journalisation sera ajoutée.',
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 13, height: 1.5),
            )
          else
            for (final event in historique)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: event.dotColor, shape: BoxShape.circle)),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 150,
                      child: Text(event.dateLabel,
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.textMuted)),
                    ),
                    Expanded(
                      child: Text(event.description,
                          style: const TextStyle(
                              fontSize: 13.5, color: AppColors.textPrimary)),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
