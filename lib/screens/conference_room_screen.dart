import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:qr_flutter/qr_flutter.dart';

import '../providers/attendance_provider.dart';
import '../services/conference/conference_client.dart';
import '../services/conference/conference_models.dart';
import '../services/conference/conference_room_model.dart';
import '../theme/app_theme.dart';
import '../ui/app_button.dart';
import '../ui/toast.dart';

/// Ouvre et connecte une salle. Injectable : les tests rendent l'écran sans
/// serveur média en fournissant un connecteur qui n'aboutit pas ou échoue.
typedef RoomConnector = Future<lk.Room> Function(ConferenceTicket ticket);

Future<lk.Room> _connectLiveKit(ConferenceTicket ticket) async {
  final room = lk.Room(
    roomOptions: const lk.RoomOptions(
      adaptiveStream: true,
      dynacast: true,
      defaultCameraCaptureOptions: lk.CameraCaptureOptions(
        params: lk.VideoParametersPresets.h540_169,
      ),
      defaultAudioCaptureOptions: lk.AudioCaptureOptions(
        noiseSuppression: true,
        echoCancellation: true,
        autoGainControl: true,
      ),
    ),
  );
  try {
    await room.connect(ticket.serverUrl, ticket.token);
  } on Object {
    await room.dispose();
    rethrow;
  }
  return room;
}

/// La salle de réunion : vidéos, micro/caméra/partage d'écran, invitation
/// (lien réseau + QR) et présence. C'est ici que l'hôte arrive dès que sa
/// réunion est créée — auparavant la création ne menait qu'à un panneau
/// d'état, et il n'existait aucune salle dans l'application.
class ConferenceRoomScreen extends ConsumerStatefulWidget {
  final ConferenceTicket ticket;
  final String displayName;

  /// Réunion hébergée par ce poste, `null` quand on rejoint celle d'un autre.
  final HostedConference? hosted;

  /// Termine la réunion pour tout le monde (hôte seulement).
  final Future<void> Function()? onEndMeeting;

  final RoomConnector connector;

  const ConferenceRoomScreen({
    super.key,
    required this.ticket,
    required this.displayName,
    this.hosted,
    this.onEndMeeting,
    this.connector = _connectLiveKit,
  });

  bool get isHost => hosted != null;

  @override
  ConsumerState<ConferenceRoomScreen> createState() =>
      _ConferenceRoomScreenState();
}

enum _Phase { connecting, connected, failed, ended }

enum _SidePanel { none, invite, people }

class _ConferenceRoomScreenState extends ConsumerState<ConferenceRoomScreen> {
  _Phase _phase = _Phase.connecting;
  String? _error;
  String? _mediaNote;
  lk.Room? _room;
  lk.EventsListener<lk.RoomEvent>? _events;
  _SidePanel _panel = _SidePanel.invite;
  String? _pinned;
  bool _leaving = false;
  late final DateTime _openedAt = DateTime.now();
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    // L'invitation s'ouvre d'elle-même chez l'hôte : c'est la première chose
    // qu'il montre à la salle. Un invité voit la vidéo en plein.
    _panel = widget.isHost ? _SidePanel.invite : _SidePanel.none;
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    unawaited(_connect());
  }

  Future<void> _connect() async {
    setState(() {
      _phase = _Phase.connecting;
      _error = null;
    });
    try {
      final room = await widget.connector(widget.ticket);
      if (!mounted) {
        await room.dispose();
        return;
      }
      _room = room;
      room.addListener(_onRoomChanged);
      _events = room.createListener()
        ..on<lk.RoomDisconnectedEvent>((event) {
          if (!mounted) return;
          setState(() {
            _phase = _Phase.ended;
            _error = disconnectReasonLabel(event.reason?.name);
          });
        });
      setState(() => _phase = _Phase.connected);
      await _enableMedia(room);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.failed;
        _error = error is ConferenceException
            ? error.message
            : 'Connexion au serveur média impossible : $error';
      });
    }
  }

  /// Micro puis caméra, chacun à part : un poste sans caméra doit pouvoir
  /// parler, et un poste sans micro doit pouvoir montrer sa caméra.
  Future<void> _enableMedia(lk.Room room) async {
    final local = room.localParticipant;
    if (local == null) return;
    final notes = <String>[];
    try {
      await local.setMicrophoneEnabled(true);
    } on Object {
      notes.add('micro indisponible');
    }
    try {
      await local.setCameraEnabled(true);
    } on Object {
      notes.add('caméra indisponible');
    }
    if (!mounted) return;
    setState(() {
      _mediaNote = notes.isEmpty
          ? null
          : 'Vous participez sans ${notes.join(' ni ')} : vérifiez les '
              'périphériques et les autorisations du système.';
    });
  }

  void _onRoomChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _clock?.cancel();
    _events?.dispose();
    final room = _room;
    if (room != null) {
      room.removeListener(_onRoomChanged);
      unawaited(room.disconnect().then((_) => room.dispose()));
    }
    super.dispose();
  }

  // ---------------------------------------------------------------- actions

  Future<void> _toggleMic() async {
    final local = _room?.localParticipant;
    if (local == null) return;
    try {
      await local.setMicrophoneEnabled(!local.isMicrophoneEnabled());
    } on Object catch (error) {
      if (mounted) Toast.error(context, 'Micro : $error');
    }
  }

  Future<void> _toggleCamera() async {
    final local = _room?.localParticipant;
    if (local == null) return;
    try {
      await local.setCameraEnabled(!local.isCameraEnabled());
    } on Object catch (error) {
      if (mounted) Toast.error(context, 'Caméra : $error');
    }
  }

  Future<void> _toggleScreenShare() async {
    final local = _room?.localParticipant;
    if (local == null) return;
    try {
      await local.setScreenShareEnabled(!local.isScreenShareEnabled());
    } on Object catch (error) {
      if (mounted) {
        Toast.error(context, 'Partage d\'écran impossible', detail: '$error');
      }
    }
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    final room = _room;
    _room = null;
    if (room != null) {
      room.removeListener(_onRoomChanged);
      _events?.dispose();
      _events = null;
      try {
        await room.disconnect();
      } on Object {
        // Déjà déconnecté : on quitte quand même l'écran.
      }
      await room.dispose();
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _endForEveryone() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Terminer la réunion ?'),
        content: const Text(
          'Tous les participants seront déconnectés et la feuille de présence '
          'sera close. Vous pourrez l\'exporter depuis l\'écran Conférences.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Terminer pour tous'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.onEndMeeting?.call();
    await _leave();
  }

  void _copy(String value, String what) {
    Clipboard.setData(ClipboardData(text: value));
    Toast.success(context, '$what copié.');
  }

  // ------------------------------------------------------------------ tiles

  List<_LiveTile> _tiles() {
    final room = _room;
    if (room == null) {
      return [
        _LiveTile(
          model: RoomTile(
              identity: 'moi', name: widget.displayName, isLocal: true),
        ),
      ];
    }
    final out = <_LiveTile>[];
    final local = room.localParticipant;
    if (local != null) out.add(_LiveTile.of(local, isLocal: true));
    for (final participant in room.remoteParticipants.values) {
      out.add(_LiveTile.of(participant));
    }
    final ordered = orderTiles([for (final t in out) t.model]);
    return [
      for (final model in ordered)
        out.firstWhere((t) => t.model.identity == model.identity),
    ];
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final tiles = _tiles();
    final stage =
        stageIdentity([for (final t in tiles) t.model], pinned: _pinned);
    final elapsed = DateTime.now().difference(_openedAt);
    final wide = MediaQuery.sizeOf(context).width >= 980;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: Column(
        children: [
          _TopBar(
            title: widget.ticket.roomName.isEmpty
                ? 'Réunion UniFlow'
                : widget.ticket.roomName,
            code: widget.hosted?.code,
            isHost: widget.isHost,
            phase: _phase,
            participants: participantCountLabel(tiles.length),
            elapsed: elapsed,
            onCopyCode: widget.hosted == null
                ? null
                : () => _copy(widget.hosted!.code, 'Code'),
          ),
          if (_mediaNote != null)
            _Banner(
                icon: Icons.warning_amber_rounded,
                color: AppColors.warning,
                text: _mediaNote!),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _buildStage(tiles, stage),
                  ),
                ),
                if (_panel != _SidePanel.none)
                  SizedBox(
                    width: wide ? 340 : 300,
                    child: _panel == _SidePanel.invite
                        ? _InvitePanel(
                            hosted: widget.hosted,
                            ticket: widget.ticket,
                            onCopy: _copy,
                            onClose: () =>
                                setState(() => _panel = _SidePanel.none),
                          )
                        : _PeoplePanel(
                            tiles: [for (final t in tiles) t.model],
                            isHost: widget.isHost,
                            pinned: _pinned,
                            onPin: (identity) => setState(() => _pinned =
                                _pinned == identity ? null : identity),
                            onClose: () =>
                                setState(() => _panel = _SidePanel.none),
                          ),
                  ),
              ],
            ),
          ),
          _ControlBar(
            room: _room,
            phase: _phase,
            isHost: widget.isHost,
            panel: _panel,
            onMic: _toggleMic,
            onCamera: _toggleCamera,
            onScreen: _toggleScreenShare,
            onInvite: () => setState(() => _panel = _panel == _SidePanel.invite
                ? _SidePanel.none
                : _SidePanel.invite),
            onPeople: () => setState(() => _panel = _panel == _SidePanel.people
                ? _SidePanel.none
                : _SidePanel.people),
            onLeave: _leave,
            onEnd: widget.isHost ? _endForEveryone : null,
            onRetry: _phase == _Phase.failed ? _connect : null,
          ),
        ],
      ),
    );
  }

  Widget _buildStage(List<_LiveTile> tiles, String? stage) {
    switch (_phase) {
      case _Phase.connecting:
        return const _CenterMessage(
          icon: Icons.sensors,
          title: 'Connexion à la salle…',
          message:
              'Le poste se connecte au serveur média. Sur un réseau local, cela prend une seconde.',
          spinner: true,
        );
      case _Phase.failed:
        return _CenterMessage(
          icon: Icons.videocam_off_outlined,
          title: 'La salle n\'a pas pu être rejointe',
          message: _error ?? 'Cause inconnue.',
          tone: AppColors.danger,
        );
      case _Phase.ended:
        return _CenterMessage(
          icon: Icons.call_end_rounded,
          title: 'Réunion terminée',
          message: _error ?? 'La connexion a été fermée.',
        );
      case _Phase.connected:
        break;
    }

    if (stage != null) {
      final main = tiles.firstWhere((t) => t.model.identity == stage);
      final others = tiles.where((t) => t.model.identity != stage).toList();
      return Column(
        children: [
          Expanded(
            child: _TileView(
              tile: main,
              preferScreen: true,
              pinned: _pinned == stage,
              onTap: () => setState(() => _pinned = null),
            ),
          ),
          if (others.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 128,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: others.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) => AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _TileView(
                    tile: others[i],
                    compact: true,
                    onTap: () =>
                        setState(() => _pinned = others[i].model.identity),
                  ),
                ),
              ),
            ),
          ],
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = gridColumns(tiles.length, constraints.maxWidth);
        final rows = (tiles.length / columns).ceil();
        final tileWidth = (constraints.maxWidth - (columns - 1) * 10) / columns;
        final tileHeight = (constraints.maxHeight - (rows - 1) * 10) / rows;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          runAlignment: WrapAlignment.center,
          children: [
            for (final tile in tiles)
              SizedBox(
                width: tileWidth,
                height: tileHeight,
                child: _TileView(
                  tile: tile,
                  onTap: tiles.length > 1
                      ? () => setState(() => _pinned = tile.model.identity)
                      : null,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Vignette : l'état pur + les pistes vidéo du SDK, si la salle est connectée.
class _LiveTile {
  final RoomTile model;
  final lk.VideoTrack? camera;
  final lk.VideoTrack? screen;
  final bool isLocalCamera;

  const _LiveTile({
    required this.model,
    this.camera,
    this.screen,
    this.isLocalCamera = false,
  });

  factory _LiveTile.of(lk.Participant participant, {bool isLocal = false}) {
    lk.VideoTrack? camera;
    lk.VideoTrack? screen;
    for (final publication in participant.videoTrackPublications) {
      final track = publication.track;
      if (track is! lk.VideoTrack || publication.muted) continue;
      if (publication.source == lk.TrackSource.screenShareVideo) {
        screen ??= track;
      } else if (publication.source == lk.TrackSource.camera) {
        camera ??= track;
      }
    }
    return _LiveTile(
      model: RoomTile(
        identity: participant.identity,
        name: participant.name,
        isLocal: isLocal,
        isSpeaking: participant.isSpeaking,
        micOn: participant.isMicrophoneEnabled(),
        cameraOn: camera != null,
        sharingScreen: screen != null,
      ),
      camera: camera,
      screen: screen,
      isLocalCamera: isLocal,
    );
  }
}

class _TileView extends StatelessWidget {
  final _LiveTile tile;
  final bool compact;
  final bool preferScreen;
  final bool pinned;
  final VoidCallback? onTap;

  const _TileView({
    required this.tile,
    this.compact = false,
    this.preferScreen = false,
    this.pinned = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final track = preferScreen
        ? (tile.screen ?? tile.camera)
        : (tile.camera ?? tile.screen);
    final showingScreen = track != null && identical(track, tile.screen);
    final border = tile.model.isSpeaking
        ? AppColors.success
        : pinned
            ? AppColors.primaryBlue
            : Colors.white.withValues(alpha: 0.08);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: const Color(0xFF16213A),
          borderRadius: BorderRadius.circular(compact ? 12 : 18),
          border: Border.all(
              color: border, width: tile.model.isSpeaking ? 2.5 : 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (track != null)
              lk.VideoTrackRenderer(
                track,
                fit: showingScreen
                    ? lk.VideoViewFit.contain
                    : lk.VideoViewFit.cover,
                mirrorMode: tile.isLocalCamera && !showingScreen
                    ? lk.VideoViewMirrorMode.mirror
                    : lk.VideoViewMirrorMode.off,
              )
            else
              Center(
                child: Container(
                  width: compact ? 44 : 84,
                  height: compact ? 44 : 84,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.primaryBlue, AppColors.purple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    tile.model.initials,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 16 : 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            tile.model.micOn
                                ? Icons.mic_rounded
                                : Icons.mic_off_rounded,
                            size: 14,
                            color: tile.model.micOn
                                ? Colors.white
                                : const Color(0xFFFCA5A5),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              tile.model.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: compact ? 11 : 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (showingScreen) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.teal.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text('Écran partagé',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ],
              ),
            ),
            if (pinned)
              const Positioned(
                top: 10,
                right: 10,
                child: Icon(Icons.push_pin_rounded,
                    size: 16, color: Colors.white70),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final String? code;
  final bool isHost;
  final _Phase phase;
  final String participants;
  final Duration elapsed;
  final VoidCallback? onCopyCode;

  const _TopBar({
    required this.title,
    required this.code,
    required this.isHost,
    required this.phase,
    required this.participants,
    required this.elapsed,
    required this.onCopyCode,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = elapsed.inMinutes;
    final duration = minutes < 60
        ? '$minutes min'
        : '${elapsed.inHours} h ${(minutes % 60).toString().padLeft(2, '0')}';
    final (dotColor, stateLabel) = switch (phase) {
      _Phase.connecting => (AppColors.warning, 'Connexion…'),
      _Phase.connected => (AppColors.success, 'En direct'),
      _Phase.failed => (AppColors.danger, 'Hors salle'),
      _Phase.ended => (AppColors.textMuted, 'Terminée'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Row(
        children: [
          const Icon(Icons.videocam_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  '${isHost ? 'Vous êtes l\'hôte · ' : ''}$participants · $duration',
                  style:
                      const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration:
                        BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                const SizedBox(width: 7),
                Text(stateLabel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (code != null) ...[
            const SizedBox(width: 10),
            Tooltip(
              message: 'Copier le code',
              child: InkWell(
                onTap: onCopyCode,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.key_rounded,
                          size: 15, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(code!,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.5)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _Banner({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      color: color.withValues(alpha: 0.16),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      color: color,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _CenterMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final bool spinner;
  final Color tone;

  const _CenterMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.spinner = false,
    this.tone = AppColors.primaryBlue,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (spinner)
              const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                      strokeWidth: 3, color: Colors.white))
            else
              Icon(icon, size: 48, color: tone),
            const SizedBox(height: 18),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF94A3B8), fontSize: 13.5, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

/// Invitation : code, lien navigateur `http://<IP>:<port>/join/<CODE>` et son
/// QR, adresse de l'API pour une autre application de bureau.
class _InvitePanel extends StatelessWidget {
  final HostedConference? hosted;
  final ConferenceTicket ticket;
  final void Function(String value, String what) onCopy;
  final VoidCallback onClose;

  const _InvitePanel({
    required this.hosted,
    required this.ticket,
    required this.onCopy,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final conference = hosted;
    return _SideCard(
      title: 'Inviter des participants',
      onClose: onClose,
      child: conference == null
          ? const Text(
              'Seul l\'hôte dispose du lien d\'invitation. Demandez-lui le code de la réunion.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            )
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                const _SideLabel('Code de la réunion'),
                _CopyRow(
                  value: conference.code,
                  big: true,
                  onCopy: () => onCopy(conference.code, 'Code'),
                ),
                const SizedBox(height: 16),
                const _SideLabel('Lien pour un navigateur (même réseau)'),
                _CopyRow(
                  value: conference.participantLink,
                  onCopy: () => onCopy(conference.participantLink, 'Lien'),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.inputBorder),
                    ),
                    child: QrImageView(
                      data: conference.participantLink,
                      version: QrVersions.auto,
                      size: 176,
                      gapless: true,
                      eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: AppColors.primaryBlue),
                      dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFF111827)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Les participants scannent ce QR ou ouvrent le lien depuis un téléphone ou un ordinateur connecté au même réseau : aucune application n\'est nécessaire.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.textMuted, fontSize: 12, height: 1.5),
                ),
                const SizedBox(height: 16),
                const _SideLabel('Depuis l\'application de bureau UniFlow'),
                _CopyRow(
                  value: conference.apiUrl,
                  onCopy: () => onCopy(conference.apiUrl, 'Adresse'),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Conférences → « Rejoindre une réunion », puis cette adresse et le code.',
                  style: TextStyle(
                      color: AppColors.textMuted, fontSize: 12, height: 1.5),
                ),
                if (conference.publicUrl != null &&
                    conference.publicUrl!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const _SideLabel('Adresse publique (internet)'),
                  _CopyRow(
                    value: conference.publicUrl!,
                    onCopy: () =>
                        onCopy(conference.publicUrl!, 'Adresse publique'),
                  ),
                ],
              ],
            ),
    );
  }
}

class _PeoplePanel extends ConsumerWidget {
  final List<RoomTile> tiles;
  final bool isHost;
  final String? pinned;
  final ValueChanged<String> onPin;
  final VoidCallback onClose;

  const _PeoplePanel({
    required this.tiles,
    required this.isHost,
    required this.pinned,
    required this.onPin,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendance = isHost ? ref.watch(liveAttendanceProvider) : null;
    final summary = attendance?.summaryAt(DateTime.now());
    return _SideCard(
      title: participantCountLabel(tiles.length),
      onClose: onClose,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          if (summary != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.inputBorder),
              ),
              child: Row(
                children: [
                  _MiniStat(
                      'En ligne', '${summary.connectedNow}', AppColors.success),
                  _MiniStat(
                      'Présents', '${summary.present}', AppColors.primaryBlue),
                  _MiniStat(
                      'Invités', '${summary.invited}', AppColors.textSecondary),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'La feuille de présence se remplit à chaque arrivée et départ ; export PDF/Excel depuis l\'écran Conférences.',
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 11.5, height: 1.5),
            ),
            const SizedBox(height: 12),
          ],
          for (final tile in tiles)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.12),
                child: Text(tile.initials,
                    style: const TextStyle(
                        color: AppColors.primaryBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ),
              title: Text(tile.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              subtitle: Text(
                [
                  if (tile.sharingScreen) 'partage son écran',
                  if (tile.isSpeaking) 'parle',
                ].join(' · '),
                style:
                    const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tile.micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                      size: 16,
                      color:
                          tile.micOn ? AppColors.success : AppColors.textMuted),
                  const SizedBox(width: 6),
                  Icon(
                      tile.cameraOn
                          ? Icons.videocam_rounded
                          : Icons.videocam_off_rounded,
                      size: 16,
                      color: tile.cameraOn
                          ? AppColors.success
                          : AppColors.textMuted),
                  IconButton(
                    tooltip: pinned == tile.identity
                        ? 'Désépingler'
                        : 'Mettre en avant',
                    onPressed: () => onPin(tile.identity),
                    icon: Icon(
                      pinned == tile.identity
                          ? Icons.push_pin_rounded
                          : Icons.push_pin_outlined,
                      size: 16,
                      color: pinned == tile.identity
                          ? AppColors.primaryBlue
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 20, fontWeight: FontWeight.w800)),
          Text(label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}

class _SideCard extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback onClose;
  const _SideCard(
      {required this.title, required this.child, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 12, 12, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
              ),
              IconButton(
                tooltip: 'Fermer le volet',
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded,
                    size: 18, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _SideLabel extends StatelessWidget {
  final String text;
  const _SideLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.3)),
    );
  }
}

class _CopyRow extends StatelessWidget {
  final String value;
  final bool big;
  final VoidCallback onCopy;
  const _CopyRow({required this.value, this.big = false, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              value,
              maxLines: big ? 1 : 2,
              style: TextStyle(
                fontSize: big ? 24 : 12.5,
                fontWeight: big ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: big ? 4 : 0,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Copier',
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded,
                size: 16, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ControlBar extends StatelessWidget {
  final lk.Room? room;
  final _Phase phase;
  final bool isHost;
  final _SidePanel panel;
  final Future<void> Function() onMic;
  final Future<void> Function() onCamera;
  final Future<void> Function() onScreen;
  final VoidCallback onInvite;
  final VoidCallback onPeople;
  final Future<void> Function() onLeave;
  final Future<void> Function()? onEnd;
  final Future<void> Function()? onRetry;

  const _ControlBar({
    required this.room,
    required this.phase,
    required this.isHost,
    required this.panel,
    required this.onMic,
    required this.onCamera,
    required this.onScreen,
    required this.onInvite,
    required this.onPeople,
    required this.onLeave,
    required this.onEnd,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final local = room?.localParticipant;
    final live = phase == _Phase.connected && local != null;
    final micOn = live && local.isMicrophoneEnabled();
    final camOn = live && local.isCameraEnabled();
    final sharing = live && local.isScreenShareEnabled();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: [
          _RoundControl(
            icon: micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
            label: micOn ? 'Couper le micro' : 'Activer le micro',
            active: micOn,
            enabled: live,
            onPressed: onMic,
          ),
          _RoundControl(
            icon: camOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
            label: camOn ? 'Couper la caméra' : 'Activer la caméra',
            active: camOn,
            enabled: live,
            onPressed: onCamera,
          ),
          _RoundControl(
            icon: sharing
                ? Icons.stop_screen_share_rounded
                : Icons.screen_share_rounded,
            label: sharing ? 'Arrêter le partage' : 'Partager l\'écran',
            active: sharing,
            enabled: live,
            accent: AppColors.teal,
            onPressed: onScreen,
          ),
          const SizedBox(width: 6),
          _RoundControl(
            icon: Icons.person_add_alt_1_rounded,
            label: 'Inviter',
            active: panel == _SidePanel.invite,
            enabled: true,
            onPressed: () async => onInvite(),
          ),
          _RoundControl(
            icon: Icons.people_alt_rounded,
            label: 'Participants',
            active: panel == _SidePanel.people,
            enabled: true,
            onPressed: () async => onPeople(),
          ),
          const SizedBox(width: 6),
          if (onRetry != null)
            AppButton.secondary(
              label: 'Réessayer',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          if (isHost && onEnd != null)
            AppButton.danger(
              label: 'Terminer pour tous',
              icon: Icons.stop_circle_outlined,
              onPressed: onEnd,
            ),
          AppButton(
            label: isHost ? 'Quitter la salle' : 'Quitter',
            icon: Icons.call_end_rounded,
            variant:
                isHost ? AppButtonVariant.secondary : AppButtonVariant.danger,
            onPressed: onLeave,
          ),
        ],
      ),
    );
  }
}

class _RoundControl extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool enabled;
  final Color accent;
  final Future<void> Function() onPressed;

  const _RoundControl({
    required this.icon,
    required this.label,
    required this.active,
    required this.enabled,
    required this.onPressed,
    this.accent = AppColors.primaryBlue,
  });

  @override
  Widget build(BuildContext context) {
    final background = !enabled
        ? Colors.white.withValues(alpha: 0.05)
        : active
            ? accent
            : Colors.white.withValues(alpha: 0.10);
    final foreground = !enabled ? Colors.white38 : Colors.white;
    return Tooltip(
      message: label,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? () => onPressed() : null,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(icon, color: foreground, size: 21),
          ),
        ),
      ),
    );
  }
}
