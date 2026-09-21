import 'package:appwrite/appwrite.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_info.dart';
import '../models/appwrite_models.dart';
import '../models/statistics_models.dart';
import '../providers/analytics_provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/conference_provider.dart';
import '../services/conference/conference_client.dart';
import '../services/conference/conference_host_state.dart';
import '../services/conference/conference_models.dart';
import 'conference_attendance_panel.dart';
import 'conference_room_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/profile_photo_service.dart';
import '../theme/app_theme.dart';
import '../utils/avatar.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/data_state_view.dart';
import '../widgets/stat_card.dart';
import '../ui/app_button.dart';
import '../ui/app_data_table.dart';
import '../ui/status_badge.dart';
import '../ui/toast.dart';
import '../widgets/user_avatar.dart';
import '../providers/appwrite_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/preferences_provider.dart';
import '../widgets/motion.dart';
import '../widgets/uni_icons.dart';
import '../widgets/uni/archlord_mascot.dart';
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
    final attendance = ref.watch(liveAttendanceProvider);
    // La carte « Présence » remplace « Participants max » pendant la réunion :
    // la capacité est une constante, le nombre de connectés est ce que l'hôte
    // regarde.
    final attendanceSummary = attendance?.summaryAt(DateTime.now());

    return _ManagementPage(
      title: 'Gestion des conférences',
      subtitle:
          'Hébergez une séance : ce poste devient le serveur de la réunion',
      action: host.isRunning ? null : 'Nouvelle conférence',
      icon: UniIcons.add(UniIconStyle.bold),
      onAction: _working ? null : _createConference,
      stats: [
        if (host.isRunning) ...[
          _Metric('État', host.status.label, 'Serveur embarqué',
              UniIcons.hardDrives(UniIcons.defaultStyle)),
          _Metric('Code réunion', host.conference!.code, 'À communiquer',
              UniIcons.key()),
          _Metric('Adresse locale', host.localIp ?? '—', 'Réseau de l\'hôte',
              UniIcons.network(UniIcons.defaultStyle)),
          if (attendanceSummary != null)
            _Metric(
                'Présence',
                '${attendanceSummary.connectedNow} en ligne',
                '${attendanceSummary.present} présents / '
                    '${attendanceSummary.invited} invités',
                UniIcons.checks())
          else
            _Metric('Participants max', '${host.conference!.maxParticipants}',
                'Capacité de la salle', UniIcons.team()),
        ],
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (host.binaryHint != null)
            _InfoPanel(
              icon: UniIcons.terminalWindow(UniIcons.defaultStyle),
              title: 'Serveur média absent',
              message: host.binaryHint!,
            )
          else if (host.status == HostState.failed)
            _InfoPanel(
              icon: UniIcons.warningCircle(UniIcons.defaultStyle),
              title: 'Le service de réunion n\'a pas démarré',
              message: host.error ?? 'Cause inconnue.',
            )
          else if (host.isRunning)
            _RunningConferencePanel(
              host: host,
              onStop: _stopConference,
              onEnableInternet: _enableInternetMode,
              onOpenRoom: _working ? null : _openHostRoom,
            )
          else ...[
            const _ArchlordNote(
              text: 'Le serveur de réunion tourne sur ce poste : aucun '
                  'Internet requis, les participants se connectent en réseau '
                  'local.',
            ),
            const SizedBox(height: 16),
            _InfoPanel(
              icon: UniIcons.video(),
              title: 'Aucune réunion en cours',
              message: 'Démarrez une réunion pour que ce poste en devienne le '
                  'serveur : les participants s\'y connecteront directement, '
                  'sans passer par une machine centrale. Le serveur média doit '
                  'être installé sur cette machine.',
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              AppButton.secondary(
                label: 'Rejoindre une réunion',
                icon: UniIcons.signIn(UniIconStyle.bold),
                onPressed: _working ? null : () => _joinConference(),
              ),
              if (!host.isRunning)
                AppButton.ghost(
                  label: 'Vérifier la présence du serveur média',
                  icon: UniIcons.checkCircle(UniIconStyle.bold),
                  onPressed: _working ? null : _checkBinary,
                ),
            ],
          ),
          const SizedBox(height: 26),
          const _Panel(title: 'Présence', child: AttendancePanel()),
          const SizedBox(height: 26),
          _DiscoveredConferences(
            conferences: activeAsync,
            onRefresh: () => ref.invalidate(activeConferencesProvider),
            onJoin: _working
                ? null
                : (item) =>
                    _joinConference(apiUrl: item.apiUrl, name: item.name),
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
      if (!started) {
        _notify('La réunion n\'a pas pu être ouverte.', success: false);
        return;
      }
      _notify('Réunion ouverte : vous entrez dans la salle.');
      // Créer une réunion doit mener dans la salle, pas sur un panneau
      // d'état : l'hôte y trouve son lien d'invitation et voit arriver les
      // participants.
      await _openHostRoom();
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  /// Entre dans la salle de la réunion hébergée par ce poste.
  Future<void> _openHostRoom() async {
    final controller = ref.read(conferenceHostProvider.notifier);
    final host = ref.read(conferenceHostProvider);
    final user = ref.read(currentUserProvider);
    final conference = host.conference;
    final displayName = user?.name ?? conference?.hostName ?? 'Hôte';
    final ticket = conference == null
        ? null
        : controller.hostTicket(
            identity: user?.id ?? conference.hostId,
            displayName: displayName,
          );
    if (ticket == null || conference == null) {
      _notify('La salle n\'est pas prête : la réunion n\'est pas en cours.',
          success: false);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConferenceRoomScreen(
          ticket: ticket,
          displayName: displayName,
          hosted: conference,
          onEndMeeting: () => ref.read(conferenceHostProvider.notifier).stop(),
        ),
      ),
    );
  }

  /// Rejoint la réunion d'un autre poste : adresse (ou lien) de l'hôte + code.
  Future<void> _joinConference({String? apiUrl, String? name}) async {
    final request = await showDialog<_JoinRequest>(
      context: context,
      builder: (dialogContext) =>
          _JoinConferenceDialog(initialAddress: apiUrl, roomName: name),
    );
    if (request == null || !mounted) return;

    final user = ref.read(currentUserProvider);
    setState(() => _working = true);
    try {
      final ticket = await const ConferenceClient().join(
        apiUrl: request.apiUrl,
        code: request.code,
        identity: user?.id ?? 'invite-${DateTime.now().millisecondsSinceEpoch}',
        displayName: user?.name ?? 'Participant',
        userId: user?.id,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ConferenceRoomScreen(
            ticket: ticket,
            displayName: user?.name ?? 'Participant',
          ),
        ),
      );
    } on ConferenceException catch (error) {
      if (mounted) _notify(error.message, success: false);
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
    _notify(
        ok
            ? 'Adresse publique publiée : les participants distants peuvent rejoindre.'
            : 'L\'adresse publique n\'a pas pu être publiée.',
        success: ok);
  }

  Future<void> _checkBinary() async {
    setState(() => _working = true);
    try {
      final available =
          await ref.read(conferenceHostProvider.notifier).isBinaryAvailable();
      if (!mounted) return;
      _notify(
          available
              ? 'Le serveur média est installé sur cette machine.'
              : 'Serveur média introuvable : suivez les indications ci-dessus.',
          success: available);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  /// Toast du design system plutôt qu'un `SnackBar` : en bas à gauche d'une
  /// fenêtre de bureau, la barre passait inaperçue et ne distinguait pas un
  /// échec (« serveur introuvable ») d'un succès.
  void _notify(String message, {bool success = true}) {
    if (success) {
      Toast.success(context, message);
    } else {
      Toast.error(context, message);
    }
  }
}

/// Archlord, seul, qui souligne un point précis de l'écran. Réservé aux pages
/// sans tableau dense : sur une liste, une mascotte détournerait l'attention.
class _ArchlordNote extends StatelessWidget {
  final String text;
  const _ArchlordNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ArchlordMascot(
        pose: ArchlordPose.explain,
        size: 96,
        speaking: true,
        bubble: Text(text),
      ),
    );
  }
}

/// Détail de la réunion en cours : code, adresses, actions de l'hôte.
class _RunningConferencePanel extends StatelessWidget {
  final ConferenceHostState host;
  final Future<void> Function() onStop;
  final Future<void> Function() onEnableInternet;
  final Future<void> Function()? onOpenRoom;

  const _RunningConferencePanel({
    required this.host,
    required this.onStop,
    required this.onEnableInternet,
    required this.onOpenRoom,
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
          // `Wrap` : trois pastilles côte à côte débordaient d'un panneau
          // étroit ; elles passent à la ligne au besoin.
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              const StatusBadge(
                  label: 'En écoute', tone: BadgeTone.success, dot: true),
              StatusBadge(
                label: conference.mode.label,
                tone: isInternet ? BadgeTone.primary : BadgeTone.purple,
              ),
              if (host.published)
                const StatusBadge(label: 'Publiée', tone: BadgeTone.success)
              else
                const StatusBadge(
                    label: 'Non publiée', tone: BadgeTone.warning),
            ],
          ),
          const SizedBox(height: 18),

          LayoutBuilder(
            builder: (context, constraints) {
              final fields = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Le code est l'information que l'hôte dicte : il est mis
                  // en avant.
                  _CopyField(
                    label: 'Code de la réunion',
                    value: conference.code,
                    emphasize: true,
                  ),
                  // Le lien navigateur porte l'adresse de CE poste sur le
                  // réseau : c'est lui que l'on projette ou que l'on envoie.
                  _CopyField(
                    label: 'Lien participant (navigateur, même réseau)',
                    value: conference.participantLink,
                  ),
                  _CopyField(
                      label: 'Adresse pour l\'application de bureau',
                      value: conference.apiUrl),
                  _CopyField(
                    label: 'Serveur média (adresse effective)',
                    value: conference.effectiveServerUrl,
                  ),
                  if (conference.publicUrl != null &&
                      conference.publicUrl!.isNotEmpty)
                    _CopyField(
                        label: 'Adresse publique',
                        value: conference.publicUrl!),
                ],
              );
              final qr = _InviteQr(link: conference.participantLink);
              if (constraints.maxWidth < 720) {
                return Column(
                    children: [fields, const SizedBox(height: 12), qr]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: fields),
                  const SizedBox(width: 20),
                  qr,
                ],
              );
            },
          ),

          const SizedBox(height: 16),
          const Text(
            'Les participants scannent le QR ou ouvrent le lien depuis un '
            'navigateur du même réseau, ou saisissent l\'adresse et le code '
            'dans leur application de bureau. Le secret de signature des '
            'jetons ne quitte jamais cette machine.',
            style: TextStyle(
                fontSize: 12.5, color: AppColors.textMuted, height: 1.5),
          ),
          const SizedBox(height: 20),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              AppButton(
                label: 'Ouvrir la salle',
                icon: UniIcons.video(UniIconStyle.bold),
                onPressed: onOpenRoom,
              ),
              if (!isInternet)
                AppButton.secondary(
                  label: 'Exposer sur internet',
                  icon: UniIcons.globe(UniIconStyle.bold),
                  onPressed: onEnableInternet,
                ),
              AppButton.danger(
                label: 'Terminer la réunion',
                icon: UniIcons.stopCircle(UniIconStyle.bold),
                onPressed: onStop,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// QR du lien participant, encadré de blanc : un QR sur fond gris se lit mal
/// à travers une caméra de téléphone.
class _InviteQr extends StatelessWidget {
  final String link;
  const _InviteQr({required this.link});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.inputBorder),
          ),
          child: QrImageView(
            data: link,
            version: QrVersions.auto,
            size: 150,
            gapless: true,
            eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square, color: AppColors.primaryBlue),
            dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF111827)),
          ),
        ),
        const SizedBox(height: 6),
        const Text('Scanner pour rejoindre',
            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
      ],
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
              Toast.success(context, '« $value » copié.');
            },
            icon: PhosphorIcon(UniIcons.copy(UniIconStyle.bold),
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
  final void Function(DiscoveredConference item)? onJoin;

  const _DiscoveredConferences({
    required this.conferences,
    required this.onRefresh,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Réunions disponibles',
      child: conferences.when(
        loading: () => const DataLoadingView(
            label: 'Recherche des réunions…', compact: true),
        error: (error, _) => DataErrorView(
          title: 'L\'annuaire des réunions est injoignable',
          error: error,
          compact: true,
          onRetry: onRefresh,
        ),
        data: (items) {
          if (items.isEmpty) {
            return const DataEmptyView(
              compact: true,
              message:
                  'Aucune réunion publiée pour le moment. Une réunion apparaît '
                  'ici quand son hôte l\'a ouverte ; l\'annuaire s\'appuie sur '
                  'la collection Appwrite « conference_rooms ».',
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
                      IconTile(
                        icon: UniIcons.video(),
                        color: AppColors.primaryBlue,
                        size: 36,
                        variant: IconTileVariant.soft,
                        semanticLabel: 'Conférence',
                      ),
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
                      if (item.apiUrl.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        AppButton.secondary(
                          label: 'Rejoindre',
                          icon: UniIcons.signIn(UniIconStyle.bold),
                          onPressed:
                              onJoin == null ? null : () => onJoin!(item),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              const Text(
                '« Rejoindre » demande le code de la réunion, puis la jonction '
                'se fait directement auprès de l\'hôte, sur son réseau.',
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
        AppButton.secondary(
          label: 'Annuler',
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton(label: 'Ouvrir', onPressed: _submit),
      ],
    );
  }

  void _submit() {
    final value = _controller.text.trim();
    Navigator.of(context).pop(value.isEmpty ? 'Réunion sans titre' : value);
  }
}

/// Ce que l'utilisateur a saisi pour rejoindre : l'adresse de l'API de
/// l'hôte (déjà extraite d'un lien d'invitation si c'en était un) et le code.
class _JoinRequest {
  final String apiUrl;
  final String code;
  const _JoinRequest({required this.apiUrl, required this.code});
}

/// Demande l'adresse de l'hôte (ou son lien d'invitation) et le code.
class _JoinConferenceDialog extends StatefulWidget {
  final String? initialAddress;
  final String? roomName;
  const _JoinConferenceDialog({this.initialAddress, this.roomName});

  @override
  State<_JoinConferenceDialog> createState() => _JoinConferenceDialogState();
}

class _JoinConferenceDialogState extends State<_JoinConferenceDialog> {
  late final TextEditingController _address =
      TextEditingController(text: widget.initialAddress ?? '');
  final TextEditingController _code = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locked = (widget.initialAddress ?? '').isNotEmpty;
    return AlertDialog(
      title: Text(widget.roomName == null
          ? 'Rejoindre une réunion'
          : 'Rejoindre « ${widget.roomName} »'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _address,
              autofocus: !locked,
              readOnly: locked,
              decoration: const InputDecoration(
                labelText: 'Adresse de l\'hôte ou lien d\'invitation',
                hintText: 'Ex. http://192.168.1.10:8090/join/K7M2QP',
              ),
              onChanged: (_) => _prefillCodeFromLink(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _code,
              autofocus: locked,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Code de la réunion',
                hintText: 'Ex. K7M2QP',
                errorText: _error,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            const Text(
              'L\'adresse est celle affichée chez l\'hôte (« Adresse pour '
              'l\'application de bureau ») ; un lien d\'invitation collé ici '
              'remplit le code tout seul.',
              style: TextStyle(
                  fontSize: 12.5, color: AppColors.textMuted, height: 1.4),
            ),
          ],
        ),
      ),
      actions: [
        AppButton.secondary(
          label: 'Annuler',
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton(label: 'Rejoindre', onPressed: _submit),
      ],
    );
  }

  void _prefillCodeFromLink() {
    final parsed = ConferenceInviteLink.parse(_address.text);
    if (parsed?.code != null && _code.text.trim().isEmpty) {
      _code.text = parsed!.code!;
    }
  }

  void _submit() {
    final parsed = ConferenceInviteLink.parse(_address.text);
    final code = (_code.text.trim().isEmpty ? parsed?.code : _code.text.trim())
        ?.toUpperCase();
    if (parsed == null) {
      setState(() => _error = 'Adresse illisible : attendu http://IP:port.');
      return;
    }
    if (code == null || code.isEmpty) {
      setState(() => _error = 'Le code de la réunion est requis.');
      return;
    }
    Navigator.of(context).pop(_JoinRequest(apiUrl: parsed.apiUrl, code: code));
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
        AppButton.secondary(
          label: 'Annuler',
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton(label: 'Publier', onPressed: _submit),
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
        loading: () => const DataLoadingView(label: 'Calcul des statistiques…'),
        error: (error, _) => DataErrorView(
          title: 'Statistiques indisponibles',
          error: error,
          onRetry: () => ref.invalidate(gradeStatsProvider),
        ),
        data: (stats) {
          if (stats == null) {
            return DataEmptyView(
              icon: UniIcons.statistics(),
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
                      hint: 'toutes matières',
                      icon: UniIcons.grades(),
                      iconBackground: AppColors.primaryBlue,
                      index: 0,
                    ),
                  ),
                  SizedBox(
                    width: 210,
                    child: StatCard(
                      label: 'Moyenne générale',
                      value: stats.averageLabel,
                      hint: 'pondérée par coefficient',
                      icon: UniIcons.star(),
                      iconBackground: AppColors.warning,
                      index: 1,
                    ),
                  ),
                  SizedBox(
                    width: 210,
                    child: StatCard(
                      label: 'Taux de réussite',
                      value: stats.successRateLabel,
                      hint: 'notes ≥ 10/20',
                      icon: UniIcons.grades(),
                      iconBackground: AppColors.teal,
                      index: 2,
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
          AppButton.secondary(
              label: 'Annuler',
              onPressed: () => Navigator.pop(dialogContext, false)),
          AppButton(
              label: 'Changer',
              onPressed: () => Navigator.pop(dialogContext, true)),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _settingsPanels(context, currentUser, prefs, hasPhoto),
          const SizedBox(height: 18),
          const AboutPanel(),
        ],
      ),
    );
  }

  Widget _settingsPanels(BuildContext context, UniFlowUser? currentUser,
      AppPreferences prefs, bool hasPhoto) {
    return _ResponsivePanels(
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
                  subtitle: 'Conserver la session d\'une ouverture à l\'autre',
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
                  onChanged:
                      ref.read(preferencesProvider.notifier).setCompactSidebar,
                ),
                _SettingRow(
                  title: 'Thème sombre',
                  subtitle: 'Fond bleu nuit, comme le web en mode sombre',
                  value: prefs.darkMode,
                  onChanged: ref.read(preferencesProvider.notifier).setDarkMode,
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
                AppButton.secondary(
                  label: 'Changer le mot de passe',
                  icon: UniIcons.lockKey(UniIconStyle.bold),
                  onPressed: currentUser == null
                      ? null
                      : () => _changePassword(context),
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
                  initials:
                      currentUser == null ? '?' : initialsOf(currentUser.name),
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
                  AppButton.secondary(
                    label: hasPhoto ? 'Changer la photo' : 'Ajouter une photo',
                    icon: UniIcons.camera(UniIconStyle.bold),
                    loading: _uploading,
                    onPressed: _pickAndUpload,
                  ),
                  if (hasPhoto)
                    AppButton.ghost(
                      label: 'Retirer',
                      icon: UniIcons.delete(UniIconStyle.bold),
                      onPressed: _uploading ? null : _removePhoto,
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
                  style: const TextStyle(color: AppColors.danger, fontSize: 12),
                ),
              ],
            ],
            const SizedBox(height: 26),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                // Déconnexion en secondaire : c'est une action ordinaire.
                // Le rouge plein est réservé à la suppression du compte,
                // la seule irréversible ; avant, les deux étaient rouges et
                // se confondaient.
                AppButton.secondary(
                  label: 'Se déconnecter',
                  icon: UniIcons.signOut(UniIconStyle.bold),
                  onPressed: () => signOutToLogin(context, ref),
                ),
                if (currentUser != null)
                  AppButton.danger(
                    key: const Key('delete-account-open'),
                    label: 'Supprimer mon compte',
                    icon: UniIcons.trashSimple(UniIconStyle.bold),
                    onPressed: () => showDeleteAccountFlow(context, ref),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// « À propos » : version, éditeur, et la scène du poing entre Archlord et
/// Uni. Ajouté aux Paramètres (2026-09-21) : l'application n'indiquait nulle
/// part sa version ni qui la fait.
class AboutPanel extends StatelessWidget {
  const AboutPanel({super.key});

  /// Sous cette largeur, la scène passe au-dessus du texte : côte à côte, le
  /// texte n'aurait plus qu'une colonne de quelques mots.
  static const double _sideBySideMinWidth = 640;

  static const String _logoAsset = 'assets/logos/kernel_forge.webp';

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'À propos',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sideBySide = constraints.maxWidth >= _sideBySideMinWidth;
          const scene = ArchlordUniFistBump(size: 150);
          final text = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Image.asset(
                    _logoAsset,
                    width: 36,
                    height: 36,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) => PhosphorIcon(
                        UniIcons.code(UniIconStyle.bold),
                        size: 28,
                        color: AppColors.primaryBlue),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${AppInfo.name} · version ${AppInfo.version}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Édité par ${AppInfo.publisher} — Université de Yaoundé I',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(AppInfo.publisherPitch, style: AppTextStyles.body),
              const SizedBox(height: AppSpacing.md),
              const ArchlordMascot(
                pose: ArchlordPose.thumbs,
                size: 72,
                still: true,
                bubble: Text('UniFlow est notre premier produit. '
                    'Merci de le faire vivre avec nous.'),
              ),
            ],
          );
          if (!sideBySide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: scene),
                const SizedBox(height: AppSpacing.lg),
                text,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              scene,
              const SizedBox(width: AppSpacing.xxl),
              Expanded(child: text),
            ],
          );
        },
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
    // L'en-tête est hors du défilement et sans marge, comme sur les autres
    // écrans (annuaire, emploi du temps) : posé dans la zone défilante avec
    // 30 px de marge, il apparaissait comme une carte blanche encadrée, à
    // 30 px du bord, alors que partout ailleurs il court d'un bord à l'autre.
    // Le `Scaffold` imbriqué a disparu : la coquille en fournit déjà un.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTopBar(
          title: title,
          subtitle: subtitle,
          actions: [
            if (action != null)
              AppButton(
                label: action!,
                icon: icon ?? UniIcons.arrowRight(UniIconStyle.bold),
                onPressed: onAction,
              ),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.page),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (stats.isNotEmpty) ...[
                  LayoutBuilder(
                    builder: (context, constraints) {
                      // Sur une fenêtre plus étroite que la largeur nominale
                      // d'une carte, celle-ci se réduit au lieu de dépasser.
                      final width = constraints.maxWidth < _cardWidth
                          ? constraints.maxWidth
                          : _cardWidth;
                      return Wrap(
                        spacing: AppSpacing.lg,
                        runSpacing: AppSpacing.lg,
                        children: [
                          for (var i = 0; i < stats.length; i++)
                            SizedBox(
                              width: width,
                              child: StatCard(
                                label: stats[i].label,
                                value: stats[i].value,
                                hint: stats[i].detail,
                                icon: stats[i].icon,
                                iconBackground: _palette[i % _palette.length],
                                index: i,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
                child,
              ],
            ),
          ),
        ),
      ],
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

/// Tableau de synthèse des statistiques : première colonne libellée (souple),
/// les suivantes sont des nombres alignés à droite. C'était un `DataTable`
/// Material, seul tableau de l'application à avoir cet aspect.
class _DataTableCard extends StatelessWidget {
  final String title;
  final List<String> columns;
  final List<List<String>> rows;
  const _DataTableCard(
      {required this.title, required this.columns, required this.rows});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: title,
      child: AppDataTable<List<String>>(
        columns: [
          for (var i = 0; i < columns.length; i++)
            AppColumn(
              columns[i],
              flex: i == 0 ? 3 : 1,
              align: i == 0 ? TextAlign.left : TextAlign.right,
            ),
        ],
        rows: rows,
        rowHeight: 40,
        minWidth: 72.0 * columns.length + 160,
        cells: (row, _) => [
          for (var i = 0; i < columns.length; i++)
            Text(
              i < row.length ? row[i] : '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: i == 0 ? FontWeight.w600 : FontWeight.w400,
                color: i == 0 ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    PhosphorIcon(UniIcons.videoOff(),
                        color: Colors.white54, size: 48),
                    const SizedBox(height: 12),
                    const Text('Flux sécurisé LAN uniquement',
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
  Widget build(BuildContext context) => _ManagementPage(
        title: 'Structure Académique',
        subtitle: 'Gérez les facultés, départements et niveaux',
        stats: const [],
        child: DataEmptyView(
          icon: UniIcons.treeStructure(UniIcons.defaultStyle),
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
  Widget build(BuildContext context) => _ManagementPage(
        title: 'Gestion des Paiements',
        subtitle: 'Suivi des abonnements et frais de scolarité',
        // Pas de recettes affichées : aucun flux de paiement n'alimente
        // l'application, un montant en dur donnerait une fausse vue des finances.
        stats: const [],
        child: DataEmptyView(
          icon: UniIcons.wallet(),
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
            IconTile(
              icon: icon,
              color: AppColors.textSecondary,
              size: 56,
              variant: IconTileVariant.soft,
              semanticLabel: title,
            ),
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
