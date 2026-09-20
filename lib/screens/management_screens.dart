import 'package:appwrite/appwrite.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/statistics_models.dart';
import '../providers/analytics_provider.dart';
import '../providers/conference_provider.dart';
import '../services/conference/conference_host_state.dart';
import '../services/conference/conference_models.dart';
import '../services/profile_photo_service.dart';
import '../theme/app_theme.dart';
import '../utils/avatar.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/stat_card.dart';
import '../widgets/status_badge.dart';
import '../widgets/user_avatar.dart';
import '../providers/appwrite_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/preferences_provider.dart';
import '../widgets/motion.dart';
import 'session_flow.dart';

/// Console d'hébergement des visioconférences.
///
/// Le poste qui ouvre une salle en devient le serveur : il lance un serveur
/// média local, ouvre une API de jonction qui signe les jetons d'accès, et
/// publie l'adresse de la salle dans l'annuaire pour que les participants
/// distants la retrouvent. Aucun serveur central n'intervient.
///
/// Trois états sont possibles et l'écran les distingue nettement : le service
/// n'est pas démarré, il démarre ou tourne, ou bien il ne peut pas démarrer
/// (binaire absent, pas de réseau) — dans ce dernier cas la marche à suivre
/// est affichée au lieu d'un message d'erreur sec.
class ConferencesScreen extends ConsumerStatefulWidget {
  const ConferencesScreen({super.key});

  @override
  ConsumerState<ConferencesScreen> createState() => _ConferencesScreenState();
}

class _ConferencesScreenState extends ConsumerState<ConferencesScreen> {
  /// Vrai pendant l'appel au démarrage, pour éviter un double démarrage si
  /// l'utilisateur clique deux fois.
  bool _working = false;

  @override
  Widget build(BuildContext context) {
    final host = ref.watch(conferenceHostProvider);
    final activeAsync = ref.watch(activeConferencesProvider);

    return _ManagementPage(
      title: 'Gestion des conférences',
      subtitle:
          'Hébergez une séance : ce poste devient le serveur de la réunion',
      action: host.isRunning ? null : 'Nouvelle conférence',
      icon: Icons.add,
      onAction: _working ? null : _createConference,
      stats: [
        if (host.isRunning) ...[
          _Metric('État', host.status.label, 'Serveur embarqué',
              Icons.dns_outlined),
          _Metric('Code réunion', host.conference!.code, 'À communiquer',
              Icons.key_outlined),
          _Metric('Adresse locale', host.localIp ?? '—', 'Réseau de l\'hôte',
              Icons.lan_outlined),
          _Metric('Participants max', '${host.conference!.maxParticipants}',
              'Capacité de la salle', Icons.groups_outlined),
        ],
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (host.binaryHint != null)
            _InfoPanel(
              icon: Icons.terminal_outlined,
              title: 'Serveur média absent',
              message: host.binaryHint!,
            )
          else if (host.status == HostState.failed)
            _InfoPanel(
              icon: Icons.error_outline,
              title: 'Le service de réunion n\'a pas démarré',
              message: host.error ?? 'Cause inconnue.',
            )
          else if (host.isRunning)
            _RunningConferencePanel(
              host: host,
              onStop: _stopConference,
              onEnableInternet: _enableInternetMode,
            )
          else
            const _InfoPanel(
              icon: Icons.videocam_outlined,
              title: 'Aucune réunion en cours',
              message: 'Démarrez une réunion pour que ce poste en devienne le '
                  'serveur : les participants s\'y connecteront directement, '
                  'sans passer par une machine centrale. Le serveur média doit '
                  'être installé sur cette machine.',
            ),
          if (!host.isRunning && !_working) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _checkBinary,
                icon: const Icon(Icons.check_circle_outline, size: 17),
                label: const Text('Vérifier la présence du serveur média'),
              ),
            ),
          ],
          const SizedBox(height: 26),
          _DiscoveredConferences(
            conferences: activeAsync,
            onRefresh: () => ref.invalidate(activeConferencesProvider),
          ),
        ],
      ),
    );
  }

  /// Demande un titre de réunion puis démarre le service.
  Future<void> _createConference() async {
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const _ConferenceNameDialog(),
    );
    if (name == null || !mounted) return;

    final user = ref.read(currentUserProvider);
    setState(() => _working = true);
    try {
      final started = await ref.read(conferenceHostProvider.notifier).start(
            name: name,
            hostId: user?.id ?? 'local',
            hostName: user?.name ?? 'Hôte local',
          );
      if (!mounted) return;
      _notify(
        started
            ? 'Réunion ouverte. Communiquez le code aux participants.'
            : 'La réunion n\'a pas pu être ouverte.',
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _stopConference() async {
    setState(() => _working = true);
    try {
      await ref.read(conferenceHostProvider.notifier).stop();
      if (!mounted) return;
      _notify('Réunion terminée.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  /// Bascule la réunion en mode internet après saisie d'une adresse publique.
  Future<void> _enableInternetMode() async {
    final url = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const _PublicUrlDialog(),
    );
    if (url == null || !mounted) return;

    final ok =
        await ref.read(conferenceHostProvider.notifier).enableInternetMode(url);
    if (!mounted) return;
    _notify(ok
        ? 'Adresse publique publiée : les participants distants peuvent rejoindre.'
        : 'L\'adresse publique n\'a pas pu être publiée.');
  }

  Future<void> _checkBinary() async {
    setState(() => _working = true);
    try {
      final available =
          await ref.read(conferenceHostProvider.notifier).isBinaryAvailable();
      if (!mounted) return;
      _notify(available
          ? 'Le serveur média est installé sur cette machine.'
          : 'Serveur média introuvable : suivez les indications ci-dessus.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Détail de la réunion en cours : code, adresses, actions de l'hôte.
class _RunningConferencePanel extends StatelessWidget {
  final ConferenceHostState host;
  final Future<void> Function() onStop;
  final Future<void> Function() onEnableInternet;

  const _RunningConferencePanel({
    required this.host,
    required this.onStop,
    required this.onEnableInternet,
  });

  @override
  Widget build(BuildContext context) {
    final conference = host.conference!;
    final isInternet = conference.mode == ConferenceMode.internet;

    return _Panel(
      title: conference.name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const StatusBadge(
                  label: 'EN ÉCOUTE', backgroundColor: Color(0xFFDFF5E4)),
              const SizedBox(width: 8),
              StatusBadge(
                label: conference.mode.label,
                backgroundColor: isInternet
                    ? const Color(0xFFDCEBFF)
                    : const Color(0xFFF1E4FF),
              ),
              const SizedBox(width: 8),
              if (host.published)
                const StatusBadge(
                    label: 'PUBLIÉE', backgroundColor: Color(0xFFDFF5E4))
              else
                const StatusBadge(
                    label: 'NON PUBLIÉE', backgroundColor: Color(0xFFFFF0DC)),
            ],
          ),
          const SizedBox(height: 18),

          // Le code est l'information que l'hôte dicte : il est mis en avant.
          _CopyField(
            label: 'Code de la réunion',
            value: conference.code,
            emphasize: true,
          ),
          _CopyField(label: 'API de jonction', value: conference.apiUrl),
          _CopyField(
            label: 'Serveur média (adresse effective)',
            value: conference.effectiveServerUrl,
          ),
          if (conference.publicUrl != null && conference.publicUrl!.isNotEmpty)
            _CopyField(label: 'Adresse publique', value: conference.publicUrl!),

          const SizedBox(height: 16),
          const Text(
            'Les participants rejoignent cette réunion depuis leur propre '
            'application en saisissant le code ci-dessus. Le secret de '
            'signature des jetons ne quitte jamais cette machine.',
            style: TextStyle(
                fontSize: 12.5, color: AppColors.textMuted, height: 1.5),
          ),
          const SizedBox(height: 20),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (!isInternet)
                OutlinedButton.icon(
                  onPressed: onEnableInternet,
                  icon: const Icon(Icons.public, size: 17),
                  label: const Text('Exposer sur internet'),
                ),
              ElevatedButton.icon(
                onPressed: onStop,
                icon: const Icon(Icons.stop_circle_outlined, size: 17),
                label: const Text('Terminer la réunion'),
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Champ en lecture seule avec bouton de copie.
class _CopyField extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _CopyField({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 220,
            child: Text(
              label,
              style:
                  const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: emphasize ? 20 : 13.5,
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: emphasize ? 3 : 0,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Copier',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('« $value » copié.')),
              );
            },
            icon: const Icon(Icons.copy_rounded,
                size: 17, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Réunions publiées dans l'annuaire, que ce poste peut rejoindre.
class _DiscoveredConferences extends StatelessWidget {
  final AsyncValue<List<DiscoveredConference>> conferences;
  final VoidCallback onRefresh;

  const _DiscoveredConferences({
    required this.conferences,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Réunions disponibles',
      child: conferences.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'L\'annuaire des réunions est injoignable : $error',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, size: 17),
              label: const Text('Réessayer'),
            ),
          ],
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Text(
              'Aucune réunion publiée pour le moment. Une réunion apparaît ici '
              'quand son hôte l\'a ouverte ; l\'annuaire s\'appuie sur la '
              'collection Appwrite « conference_rooms ».',
              style: TextStyle(
                  fontSize: 13, color: AppColors.textMuted, height: 1.5),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.videocam_outlined,
                          size: 20, color: AppColors.primaryBlue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item.hostName.isEmpty ? 'Hôte inconnu' : item.hostName} · '
                              '${item.mode.label} · ${item.serverUrl}',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${item.maxParticipants} places',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              const Text(
                'Pour rejoindre une réunion, saisissez son code dans votre '
                'propre application : la jonction se fait directement auprès '
                'de l\'hôte.',
                style: TextStyle(
                    fontSize: 12.5, color: AppColors.textMuted, height: 1.5),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Demande le titre de la réunion à ouvrir.
class _ConferenceNameDialog extends StatefulWidget {
  const _ConferenceNameDialog();

  @override
  State<_ConferenceNameDialog> createState() => _ConferenceNameDialogState();
}

class _ConferenceNameDialogState extends State<_ConferenceNameDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouvelle réunion'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Titre de la réunion',
              hintText: 'Ex. Cours de Réseaux — L3',
            ),
            onSubmitted: (value) => _submit(),
          ),
          const SizedBox(height: 12),
          const Text(
            'Ce poste deviendra le serveur de la réunion : gardez '
            'l\'application ouverte pendant toute la séance.',
            style: TextStyle(
                fontSize: 12.5, color: AppColors.textMuted, height: 1.4),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Ouvrir')),
      ],
    );
  }

  void _submit() {
    final value = _controller.text.trim();
    Navigator.of(context).pop(value.isEmpty ? 'Réunion sans titre' : value);
  }
}

/// Demande l'adresse publique à publier pour le mode internet.
class _PublicUrlDialog extends StatefulWidget {
  const _PublicUrlDialog();

  @override
  State<_PublicUrlDialog> createState() => _PublicUrlDialogState();
}

class _PublicUrlDialogState extends State<_PublicUrlDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Exposer la réunion sur internet'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Adresse publique du serveur média',
              hintText: 'wss://reunion.mon-domaine.codes',
            ),
            onSubmitted: (value) => _submit(),
          ),
          const SizedBox(height: 12),
          const Text(
            'Adresse par laquelle un participant hors du réseau local atteint '
            'ce serveur (tunnel ou redirection de port). Les participants déjà '
            'sur le réseau local continuent d\'utiliser l\'adresse locale.',
            style: TextStyle(
                fontSize: 12.5, color: AppColors.textMuted, height: 1.4),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Publier')),
      ],
    );
  }

  void _submit() {
    final value = _controller.text.trim();
    Navigator.of(context).pop(value.isEmpty ? null : value);
  }
}

// L'écran « Communications » statique (annonces codées en dur) a été remplacé
// par la messagerie réelle : voir lib/screens/messaging_screen.dart, branchée
// sur AppDestination.messaging dans main_shell.dart.

/// Statistiques académiques, calculées depuis les notes réellement saisies.
///
/// Les taux affichés sont dérivés de `academic_grades` : moyenne pondérée par
/// coefficient, part des notes au-dessus de 10/20, répartition par tranches.
/// Rien n'est estimé faute de données — l'écran le dit quand il n'y en a pas.
class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(gradeStatsProvider);

    return _ManagementPage(
      title: 'Tableau de bord Statistiques',
      subtitle: 'Analysez les performances académiques de votre établissement',
      stats: const [],
      child: statsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => _InfoPanel(
          icon: Icons.cloud_off_outlined,
          title: 'Statistiques indisponibles',
          message: '$error',
        ),
        data: (stats) {
          if (stats == null) {
            return const _InfoPanel(
              icon: Icons.query_stats_outlined,
              title: 'Aucune note saisie',
              message:
                  'Les statistiques se calculent à partir de la collection '
                  '« academic_grades ». Ajoutez des notes pour voir apparaître la '
                  'moyenne générale, le taux de réussite et la répartition.',
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  SizedBox(
                    width: 210,
                    child: StatCard(
                      label: 'Notes saisies',
                      value: '${stats.gradeCount}',
                      delta: 'Total',
                      icon: Icons.grade_outlined,
                      iconBackground: AppColors.primaryBlue,
                    ),
                  ),
                  SizedBox(
                    width: 210,
                    child: StatCard(
                      label: 'Moyenne générale',
                      value: stats.averageLabel,
                      delta: 'pondérée par coefficient',
                      icon: Icons.star_border,
                      iconBackground: const Color(0xFFF5A623),
                    ),
                  ),
                  SizedBox(
                    width: 210,
                    child: StatCard(
                      label: 'Taux de réussite',
                      value: stats.successRateLabel,
                      delta: 'notes ≥ 10/20',
                      icon: Icons.trending_up,
                      iconBackground: AppColors.teal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _ChartPanel(
                      title: 'Répartition des notes (/20)',
                      values: [for (final band in stats.bands) band.count],
                      labels: [for (final band in stats.bands) band.label],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: _topCoursesPanel(stats.topCourses)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _topCoursesPanel(List<CourseAverage> courses) {
    if (courses.isEmpty) {
      return const _Panel(
        title: 'Meilleures UE par moyenne',
        child:
            Text('Aucune UE notée pour le moment.', style: AppTextStyles.body),
      );
    }
    return _DataTableCard(
      title: 'Meilleures UE par moyenne',
      columns: const ['UE', 'Moyenne', 'Notes'],
      rows: [
        for (final course in courses)
          [course.courseCode, course.label, '${course.gradeCount}'],
      ],
    );
  }
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _uploading = false;
  String? _photoError;

  /// Ouvre le sélecteur de fichier natif, puis téléverse l'image choisie.
  ///
  /// `file_selector` est utilisé plutôt qu'`image_picker` : c'est le paquet
  /// soutenu par l'équipe Flutter sur Linux et Windows.
  Future<void> _pickAndUpload() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _photoError = null);

    const typeGroup = XTypeGroup(
      label: 'Images',
      extensions: avatarAllowedExtensions,
    );
    final XFile? picked = await openFile(acceptedTypeGroups: [typeGroup]);
    if (picked == null) return;

    final invalid = validateAvatarPath(picked.path);
    if (invalid != null) {
      setState(() => _photoError = invalid);
      return;
    }

    setState(() => _uploading = true);
    try {
      await ref.uploadAvatar(picked.path, user);
      if (!mounted) return;
      showFeedback(context, message: 'Photo de profil mise à jour.');
    } catch (error) {
      if (mounted) setState(() => _photoError = error.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _removePhoto() async {
    final user = ref.read(currentUserProvider);
    if (user == null ||
        user.avatarFileId == null ||
        user.avatarFileId!.isEmpty) {
      return;
    }

    setState(() {
      _uploading = true;
      _photoError = null;
    });
    try {
      await ref.removeAvatar(user);
    } catch (error) {
      if (mounted) setState(() => _photoError = error.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _changePassword(BuildContext context) async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Changer le mot de passe'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: current,
                  obscureText: true,
                  autofocus: true,
                  decoration:
                      const InputDecoration(labelText: 'Mot de passe actuel')),
              const SizedBox(height: 12),
              TextField(
                  controller: next,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'Nouveau mot de passe (8 min.)')),
              const SizedBox(height: 12),
              TextField(
                  controller: confirm,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirmer')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Changer')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    if (next.text.length < 8 || next.text != confirm.text) {
      showFeedback(context,
          message:
              'Nouveau mot de passe invalide ou différent de la confirmation.',
          success: false);
      return;
    }
    try {
      await ref
          .read(appwriteServiceProvider)
          .account
          .updatePassword(password: next.text, oldPassword: current.text);
      if (context.mounted) {
        showFeedback(context, message: 'Mot de passe changé.');
      }
    } on AppwriteException catch (e) {
      if (context.mounted) {
        showFeedback(
          context,
          message: 'Changement refusé.',
          detail: e.code == 401
              ? 'Le mot de passe actuel est incorrect.'
              : e.message,
          success: false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final prefs = ref.watch(preferencesProvider);
    final hasPhoto = currentUser?.avatarFileId != null &&
        currentUser!.avatarFileId!.isNotEmpty;

    return _ManagementPage(
      title: 'Paramètres',
      subtitle: 'Configurez votre espace UniFlow',
      stats: const [],
      child: _ResponsivePanels(
        left: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Panel(
              title: 'Préférences du poste',
              child: Column(
                children: [
                  _SettingRow(
                    title: 'Bandeaux de notification',
                    subtitle:
                        'Afficher un bandeau à l\'arrivée d\'une notification',
                    value: prefs.notificationBanners,
                    onChanged: ref
                        .read(preferencesProvider.notifier)
                        .setNotificationBanners,
                  ),
                  _SettingRow(
                    title: 'Rester connecté',
                    subtitle:
                        'Conserver la session d\'une ouverture à l\'autre',
                    value: prefs.keepSession,
                    onChanged:
                        ref.read(preferencesProvider.notifier).setKeepSession,
                  ),
                  _SettingRow(
                    title: 'Réduire les animations',
                    subtitle: 'Cascades et transitions désactivées',
                    value: prefs.reduceMotion,
                    onChanged:
                        ref.read(preferencesProvider.notifier).setReduceMotion,
                  ),
                  _SettingRow(
                    title: 'Barre latérale compacte',
                    subtitle: 'Icônes seules au démarrage',
                    value: prefs.compactSidebar,
                    onChanged: ref
                        .read(preferencesProvider.notifier)
                        .setCompactSidebar,
                  ),
                  _SettingRow(
                    title: 'Thème sombre',
                    subtitle: 'Fond bleu nuit, comme le web en mode sombre',
                    value: prefs.darkMode,
                    onChanged:
                        ref.read(preferencesProvider.notifier).setDarkMode,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _Panel(
              title: 'Sécurité',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      'Changez votre mot de passe ; la session reste ouverte.',
                      style: AppTextStyles.body),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: currentUser == null
                        ? null
                        : () => _changePassword(context),
                    icon: const Icon(Icons.lock_reset_outlined, size: 18),
                    label: const Text('Changer le mot de passe'),
                  ),
                ],
              ),
            ),
          ],
        ),
        right: _Panel(
          title: 'Profil utilisateur',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PhotoAvatar(
                    initials: currentUser == null
                        ? '?'
                        : initialsOf(currentUser.name),
                    avatarFileId: currentUser?.avatarFileId,
                    uploading: _uploading,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentUser?.name ?? 'Utilisateur non connecté',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        // Le pseudo identifie le compte ; l'email ne
                        // sert que de repli tant que le backfill n'a pas
                        // couvert tous les documents.
                        Text(
                          currentUser == null
                              ? '---'
                              : (currentUser.username == null ||
                                      currentUser.username!.isEmpty
                                  ? currentUser.email
                                  : '@${currentUser.username} · ${currentUser.email}'),
                          style: AppTextStyles.body,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Rôle : ${currentUser?.role ?? '---'} · Type de compte : ${currentUser?.accountType ?? '---'}',
                          style: AppTextStyles.body,
                        ),
                        if (currentUser?.university != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Université : ${currentUser!.university}',
                            style: AppTextStyles.body,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (currentUser != null) ...[
                const SizedBox(height: 16),
                // `Wrap` et non `Row` : dans une fenêtre étroite les
                // deux panneaux tiennent encore côte à côte, et le
                // panneau « Profil » ne dispose plus que de 135 px.
                // « Ajouter une photo » et « Retirer » en réclament 300
                // à eux deux — la `Row` débordait de 166 px (236 px en
                // texte agrandi). Ici le second bouton descend.
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _uploading ? null : _pickAndUpload,
                      icon: const Icon(Icons.photo_camera_outlined, size: 17),
                      label: Text(
                          hasPhoto ? 'Changer la photo' : 'Ajouter une photo'),
                    ),
                    if (hasPhoto)
                      TextButton(
                        onPressed: _uploading ? null : _removePhoto,
                        child: const Text('Retirer',
                            style: TextStyle(color: Colors.red)),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'JPEG, PNG ou WebP · 5 Mo maximum',
                  style: AppTextStyles.body.copyWith(fontSize: 11.5),
                ),
                if (_photoError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _photoError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ],
              const SizedBox(height: 26),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => signOutToLogin(context, ref),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Se déconnecter'),
                  ),
                  if (currentUser != null)
                    OutlinedButton.icon(
                      key: const Key('delete-account-open'),
                      onPressed: () => showDeleteAccountFlow(context, ref),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red)),
                      icon: const Icon(Icons.delete_forever_outlined, size: 18),
                      label: const Text('Supprimer mon compte'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// L'avatar du profil, surmonté d'un voile pendant le téléversement pour que
/// l'attente soit visible sans masquer l'image en cours de remplacement.
class _PhotoAvatar extends StatelessWidget {
  final String initials;
  final String? avatarFileId;
  final bool uploading;

  const _PhotoAvatar({
    required this.initials,
    required this.avatarFileId,
    required this.uploading,
  });

  static const double _size = 72;

  @override
  Widget build(BuildContext context) {
    final avatar = InitialsAvatar(
      initials: initials,
      avatarFileId: avatarFileId,
      size: _size,
    );
    if (!uploading) return avatar;

    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          avatar,
          Container(
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SettingRow(
      {required this.title,
      required this.subtitle,
      required this.value,
      required this.onChanged});
  // Le `Material` transparent évite l'assertion « ListTile background color
  // or ink splashes may be invisible » : le panneau parent est un `Container`
  // coloré, et le test de mise en page échouait sur les dix variantes Réglages.
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle),
          value: value,
          activeThumbColor: AppColors.primaryBlue,
          onChanged: onChanged,
        ),
      );
}

/// Charpente commune à toutes les pages de gestion : en-tête (titre,
/// sous-titre, action optionnelle), rangée de métriques, puis contenu.
class _ManagementPage extends StatelessWidget {
  final String title, subtitle;
  final String? action;
  final IconData? icon;
  final VoidCallback? onAction;
  final List<_Metric> stats;
  final Widget child;

  const _ManagementPage({
    required this.title,
    required this.subtitle,
    required this.stats,
    required this.child,
    this.action,
    this.icon,
    this.onAction,
  });

  /// Couleurs des pastilles de métriques, prises dans la palette de marque.
  ///
  /// Toutes les cartes étaient auparavant du même bleu, ce qui rendait la
  /// rangée monotone ; les alterner donne l'aspect coloré des tableaux de bord
  /// du web.
  static const List<Color> _palette = [
    AppColors.primaryBlue,
    AppColors.teal,
    AppColors.purple,
    AppColors.warning,
  ];

  /// Largeur nominale d'une carte de métrique.
  static const double _cardWidth = 210;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(30, 24, 30, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTopBar(
                title: title,
                subtitle: subtitle,
                actions: [
                  if (action != null)
                    ElevatedButton.icon(
                      onPressed: onAction,
                      icon: Icon(icon ?? Icons.arrow_forward, size: 16),
                      label: Text(action!),
                    ),
                ],
              ),
              if (stats.isNotEmpty) ...[
                const SizedBox(height: 22),
                LayoutBuilder(
                  builder: (context, constraints) {
                    // Sur une fenêtre plus étroite que la largeur nominale
                    // d'une carte, celle-ci se réduit au lieu de dépasser.
                    final width = constraints.maxWidth < _cardWidth
                        ? constraints.maxWidth
                        : _cardWidth;
                    return Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        for (var i = 0; i < stats.length; i++)
                          SizedBox(
                            width: width,
                            child: StatCard(
                              label: stats[i].label,
                              value: stats[i].value,
                              delta: stats[i].detail,
                              icon: stats[i].icon,
                              iconBackground: _palette[i % _palette.length],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
              const SizedBox(height: 22),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric {
  final String label, value, detail;
  final IconData icon;
  const _Metric(this.label, this.value, this.detail, this.icon);
}

/// Deux panneaux côte à côte tant que la fenêtre le permet, empilés sinon.
///
/// Les deux panneaux de la page Paramètres étaient dans une `Row` à
/// `Expanded` : à 420 px de large il ne restait à chacun que 135 px de contenu,
/// et les rangées internes débordaient (166 px en texte normal, 236 px en texte
/// agrandi). Sous [_minWidth], l'empilement rend à chaque panneau la largeur
/// entière — les réglages restent lisibles au lieu d'être comprimés.
///
/// `Flexible` n'est pas utilisé dans le sens vertical : la page est dans un
/// `SingleChildScrollView`, où la hauteur est non bornée, et un enfant
/// flexible y provoque « RenderFlex children have non-zero flex but incoming
/// height constraints are unbounded ». Empilé, chaque panneau prend donc sa
/// hauteur naturelle ; côte à côte, `Expanded` partage la largeur en deux.
class _ResponsivePanels extends StatelessWidget {
  static const double _minWidth = 720;

  final Widget left;
  final Widget right;

  const _ResponsivePanels({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < _minWidth;

        return Flex(
          direction: stacked ? Axis.vertical : Axis.horizontal,
          crossAxisAlignment:
              stacked ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
          children: [
            if (stacked) left else Expanded(child: left),
            const SizedBox(width: 18, height: 18),
            if (stacked) right else Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final Widget child;
  const _Panel({required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.inputBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: AppTextStyles.h2.copyWith(fontSize: 16)),
        const SizedBox(height: 14),
        child
      ]));
}

class _DataTableCard extends StatelessWidget {
  final String title;
  final List<String> columns;
  final List<List<String>> rows;
  const _DataTableCard(
      {required this.title, required this.columns, required this.rows});
  @override
  Widget build(BuildContext context) => _Panel(
      title: title,
      child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
              headingTextStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  fontSize: 12),
              dataTextStyle:
                  const TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
              columns: columns.map((c) => DataColumn(label: Text(c))).toList(),
              rows: rows
                  .map((r) =>
                      DataRow(cells: r.map((v) => DataCell(Text(v))).toList()))
                  .toList())));
}

/// Histogramme vertical. La hauteur des barres est mise à l'échelle du plus
/// grand effectif : sans cette normalisation, un effectif de quelques centaines
/// ferait déborder le cadre.
class _ChartPanel extends StatelessWidget {
  final String title;
  final List<int> values;

  /// Libellés sous les barres ; à défaut, « S1 », « S2 »…
  final List<String> labels;

  const _ChartPanel(
      {required this.title, required this.values, this.labels = const []});

  static const double _barAreaHeight = 150;

  @override
  Widget build(BuildContext context) {
    final maxValue =
        values.isEmpty ? 0 : values.reduce((a, b) => a > b ? a : b);

    return _Panel(
      title: title,
      child: SizedBox(
        height: 210,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (int i = 0; i < values.length; i++)
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('${values[i]}',
                      style: AppTextStyles.body.copyWith(fontSize: 11.5)),
                  const SizedBox(height: 6),
                  Container(
                    width: 30,
                    // Une barre de hauteur nulle resterait invisible : on garde
                    // 2 px pour matérialiser la tranche même sans effectif.
                    height: maxValue == 0
                        ? 2
                        : (values[i] / maxValue) * _barAreaHeight,
                    decoration: BoxDecoration(
                      color: i.isEven ? AppColors.primaryBlue : AppColors.teal,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    i < labels.length ? labels[i] : 'S${i + 1}',
                    style: AppTextStyles.body.copyWith(fontSize: 11),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class SentinelleManagementScreen extends StatelessWidget {
  const SentinelleManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ManagementPage(
      title: 'UniFlow Sentinelle',
      subtitle: 'Surveillance IoT et Pré-diagnostic santé (Edge AI)',
      // Aucun indicateur chiffré : il n'existe pas encore de collection
      // d'événements Sentinelle côté Appwrite. Annoncer « 4 kiosques actifs »
      // sans source reviendrait à inventer l'état du parc.
      stats: const [],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _Panel(
              title: 'Moniteur Vigie - Flux Vidéo local',
              child: Container(
                height: 250,
                decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.videocam_off, color: Colors.white54, size: 48),
                    SizedBox(height: 12),
                    Text('Flux sécurisé LAN uniquement',
                        style: TextStyle(color: Colors.white54)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          const Expanded(
            child: _Panel(
              title: 'Journal d\'événements Sentinelle',
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Aucun événement enregistré. Le journal se remplira avec les '
                  'remontées des kiosques Sentinelle.',
                  style: AppTextStyles.body,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// La page « Équipe KERNEL FORGE » vivait ici avec quatre membres figés, contre
// neuf sur le web. Elle est désormais dans `teams_screen.dart` et lit la
// collection `team_members` du serveur, comme le web et le mobile — une seule
// liste pour les trois clients.

class StructureManagementScreen extends StatelessWidget {
  const StructureManagementScreen({super.key});
  @override
  Widget build(BuildContext context) => const _ManagementPage(
        title: 'Structure Académique',
        subtitle: 'Gérez les facultés, départements et niveaux',
        stats: [],
        child: _InfoPanel(
          icon: Icons.account_tree_outlined,
          title: 'Structure non configurée',
          message: 'Les facultés, départements et niveaux ne sont pas encore '
              'modélisés côté Appwrite : la hiérarchie s\'affichera ici dès que la '
              'collection correspondante existera.',
        ),
      );
}

class PaymentsManagementScreen extends StatelessWidget {
  const PaymentsManagementScreen({super.key});
  @override
  Widget build(BuildContext context) => const _ManagementPage(
        title: 'Gestion des Paiements',
        subtitle: 'Suivi des abonnements et frais de scolarité',
        // Pas de recettes affichées : aucun flux de paiement n'alimente
        // l'application, un montant en dur donnerait une fausse vue des finances.
        stats: [],
        child: _InfoPanel(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Aucun paiement enregistré',
          message:
              'Le suivi des frais de scolarité s\'affichera ici lorsque les '
              'transactions seront enregistrées dans Appwrite. Aucun montant n\'est '
              'estimé en attendant.',
        ),
      );
}

/// État vide générique : icône, titre, explication de ce qui manque.
///
/// Utilisé partout où une page n'a pas encore de source de données, pour que
/// l'absence d'information soit lisible plutôt que comblée par des exemples.
class _InfoPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _InfoPanel(
      {required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Column(
          children: [
            Icon(icon, size: 44, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textMuted, height: 1.5),
              ),
            ),
          ],
        ),
      );
}
