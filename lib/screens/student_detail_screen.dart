import '../models/app_destination.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/student.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/app_breadcrumb.dart';
import '../ui/status_badge.dart';
import '../widgets/simple_tab_bar.dart';
import 'messaging_screen.dart';

/// Page de détail d'un étudiant. Poussée par-dessus [MainShell] avec
/// [Navigator.push] car elle n'est pas un item de la sidebar mais une
/// sous-page de "Étudiants". Fidèle à la maquette "UniFlow Desktop Partie 1".
class StudentDetailScreen extends StatefulWidget {
  final Student student;

  const StudentDetailScreen({super.key, required this.student});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  int _selectedTab = 0;
  static const _tabs = [
    'Informations',
    'Parcours',
    'Présences',
    'Notes',
    'Emploi du temps',
    'Activité'
  ];

  @override
  Widget build(BuildContext context) {
    final student = widget.student;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          AppSidebar(
            selected: AppDestination.students,
            onSelect: (item) => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopBar(context, student),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SimpleTabBar(
                          tabs: _tabs,
                          selectedIndex: _selectedTab,
                          onTabSelected: (i) =>
                              setState(() => _selectedTab = i),
                        ),
                        const SizedBox(height: 20),
                        if (_selectedTab == 0) ...[
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _InfoCard(
                                    title: 'Informations personnelles',
                                    rows: [
                                      (
                                        'Date de naissance',
                                        student.dateNaissance
                                      ),
                                      ('Email', student.email),
                                      ('Téléphone', student.telephone),
                                      ('Adresse', student.adresse),
                                      ('Genre', student.genre),
                                      ('Nationalité', student.nationalite),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  child: _InfoCard(
                                    title: 'Informations académiques',
                                    rows: [
                                      ('Filière', student.filiere),
                                      ('Niveau', student.niveau),
                                      ('Semestre', student.semestre),
                                      ('Spécialité', student.specialite),
                                      ('Groupe', student.groupe),
                                      (
                                        'Date inscription',
                                        student.dateInscriptionLongue
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          _HistoryCard(historique: student.historique),
                        ] else
                          Container(
                            padding: const EdgeInsets.all(40),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.cardWhite,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.inputBorder),
                            ),
                            child: Text(
                              '${_tabs[_selectedTab]} — contenu à venir',
                              style:
                                  const TextStyle(color: AppColors.textMuted),
                            ),
                          ),
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

  /// Fil d'Ariane + carte profil (photo, nom, matricule, statut, actions),
  /// le tout affiché en haut de page comme sur la maquette.
  Widget _buildTopBar(BuildContext context, Student student) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
      decoration: const BoxDecoration(color: AppColors.cardWhite),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppBreadcrumb(
            items: ['Étudiants', student.fullName],
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
                    color: student.avatarColor, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(
                  student.initials,
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
                    Text(student.fullName,
                        style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(student.matricule, style: AppTextStyles.body),
                        const SizedBox(width: 8),
                        StatusBadge.fromStatus(student.statut),
                      ],
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  // TODO: ouvrir le formulaire d'édition de l'étudiant
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
              OutlinedButton.icon(
                onPressed: () {
                  // TODO: confirmer puis supprimer l'étudiant
                },
                icon: const Icon(Icons.delete_outline,
                    size: 16, color: AppColors.danger),
                label: const Text('Supprimer',
                    style: TextStyle(color: AppColors.danger)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFF6C6C6)),
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
                  // interne : on ouvre l'écran avec le nom de l'étudiant
                  // pré-rempli dans la recherche de contact, à charge pour
                  // l'administrateur de confirmer le bon interlocuteur.
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          MessagingScreen(initialQuery: student.fullName),
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

/// Carte d'information générique : titre + liste de paires (libellé, valeur).
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
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(row.$1, style: AppTextStyles.body),
                  Text(row.$2,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Carte "Historique" : timeline verticale des événements du dossier.
///
/// Aucune collection ne journalise aujourd'hui les événements de dossier :
/// la liste est donc vide et la carte le dit, plutôt que d'afficher une
/// chronologie inventée. Le sélecteur décoratif qui figurait ici a été
/// retiré — il suggérait des historiques multiples qui n'existent pas.
class _HistoryCard extends StatelessWidget {
  final List<StudentHistoryEvent> historique;

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Historique', style: AppTextStyles.h2),
          const SizedBox(height: 16),
          if (historique.isEmpty)
            const Text(
              'Aucun événement de dossier enregistré. Cet historique se '
              'remplira quand une collection de journalisation sera ajoutée.',
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
