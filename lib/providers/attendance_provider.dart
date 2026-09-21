import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/conference/attendance_store.dart';
import '../services/conference/conference_attendance.dart';
import '../services/conference/conference_models.dart';
import '../services/conference/conference_paths.dart';
import '../services/conference/livekit_webhook.dart';

/// Où les feuilles de présence sont conservées sur ce poste.
///
/// Remplacé par un magasin en mémoire dans les tests et l'écran de mise en
/// page, pour ne rien écrire dans le dossier de l'utilisateur.
final attendanceStoreProvider = Provider<AttendanceStore>(
  (ref) => FileAttendanceStore(attendanceDirectory()),
);

/// Feuille de présence de la réunion en cours, `null` hors réunion.
final liveAttendanceProvider =
    NotifierProvider<LiveAttendanceController, ConferenceAttendance?>(
  LiveAttendanceController.new,
);

/// Feuilles des réunions terminées, la plus récente d'abord.
///
/// Une feuille laissée ouverte par un arrêt brutal de l'application (pas de
/// `endedAt`, mais ce n'est pas la réunion en cours) est close à sa dernière
/// activité et réécrite : ses participants « encore connectés » cumuleraient
/// sinon des jours de présence à chaque relecture.
final pastAttendancesProvider =
    FutureProvider<List<ConferenceAttendance>>((ref) async {
  final store = ref.watch(attendanceStoreProvider);
  final liveId = ref.watch(liveAttendanceProvider)?.conferenceId;
  final sheets = await store.list();
  final result = <ConferenceAttendance>[];
  for (final sheet in sheets) {
    if (sheet.conferenceId == liveId) continue;
    if (sheet.isClosed) {
      result.add(sheet);
      continue;
    }
    final repaired = sheet.close(at: sheet.lastActivityAt);
    await store.save(repaired);
    result.add(repaired);
  }
  return result;
});

/// Tient la feuille de présence de la réunion hébergée par ce poste.
///
/// Les événements arrivent de deux sources indépendantes — l'API de jonction
/// (tickets) et le serveur média (webhooks) — sur des isolates HTTP ; le
/// contrôleur est le point unique qui les applique dans l'ordre reçu et
/// persiste le résultat après chacun, pour que la feuille survive à un arrêt
/// brutal de l'application.
class LiveAttendanceController extends Notifier<ConferenceAttendance?> {
  late AttendanceStore _store;
  ConferenceAttendance? _pendingWrite;
  Future<void>? _flushing;

  @override
  ConferenceAttendance? build() {
    // Le magasin est résolu ici et gardé : à la destruction du conteneur, il
    // n'est plus permis de lire un provider, et c'est justement le moment où
    // la feuille encore ouverte doit être écrite.
    _store = ref.read(attendanceStoreProvider);
    // Le provider n'est pas `autoDispose` : la feuille vit tant que la
    // réunion dure, quel que soit l'écran affiché. À la fermeture de
    // l'application, on clôt ce qui reste ouvert — au mieux, l'écriture peut
    // ne pas aboutir ; la liste des réunions passées répare alors la feuille.
    ref.onDispose(() {
      final sheet = state;
      if (sheet != null && !sheet.isClosed) {
        unawaited(_store.save(sheet.close(at: DateTime.now())));
      }
    });
    return null;
  }

  /// Ouvre la feuille de [conference] : à partir de là, tickets et webhooks
  /// de cette salle sont enregistrés.
  void open(HostedConference conference, {String? scheduleId, DateTime? at}) {
    final sheet = ConferenceAttendance(
      conferenceId: conference.id,
      title: conference.name,
      hostId: conference.hostId,
      hostName: conference.hostName,
      startedAt: at ?? conference.createdAt,
      scheduleId: scheduleId,
    );
    state = sheet;
    _persist(sheet);
  }

  /// L'API de jonction a délivré un ticket.
  void recordTicket(IssuedTicket ticket) {
    final sheet = state;
    if (sheet == null || sheet.conferenceId != ticket.roomId) return;
    if (_isHost(sheet, ticket.identity)) return;
    _update(sheet.recordTicket(
      identity: ticket.identity,
      displayName: ticket.displayName,
      userId: ticket.userId,
      at: ticket.issuedAt,
    ));
  }

  /// Le serveur média a signalé une arrivée ou un départ.
  void recordWebhook(LiveKitWebhookEvent event) {
    final sheet = state;
    if (sheet == null || !event.concernsParticipant) return;
    if (event.roomName != sheet.conferenceId) return;
    final identity = event.participantIdentity!;
    if (_isHost(sheet, identity)) return;
    switch (event.type) {
      case LiveKitWebhookEventType.participantJoined:
        _update(sheet.recordJoin(
          identity: identity,
          displayName: event.participantName,
          at: event.createdAt,
        ));
      case LiveKitWebhookEventType.participantLeft:
        _update(sheet.recordLeave(identity: identity, at: event.createdAt));
      default:
        break;
    }
  }

  /// Change le seuil de présence de la réunion en cours.
  void setPresenceThreshold(double threshold) {
    final sheet = state;
    if (sheet == null) return;
    _update(sheet.withPresenceThreshold(threshold));
  }

  /// Rattache la réunion à une séance d'emploi du temps.
  void attachSchedule(String? scheduleId) {
    final sheet = state;
    if (sheet == null) return;
    _update(sheet.withSchedule(scheduleId));
  }

  /// Clôt la feuille : les connexions ouvertes s'arrêtent et la feuille passe
  /// dans les réunions terminées.
  ///
  /// L'état ne devient `null` qu'une fois l'écriture terminée : c'est ce
  /// passage à `null` qui fait recalculer la liste des réunions passées
  /// (elle observe ce provider), et elle doit trouver le fichier écrit.
  Future<void> close({DateTime? at}) async {
    final sheet = state;
    if (sheet == null) return;
    final closed = sheet.close(at: at ?? DateTime.now());
    state = closed;
    _persist(closed);
    await _flushing;
    if (identical(state, closed)) state = null;
  }

  /// L'hôte n'est pas un participant dont on relève la présence : il est là
  /// par définition, et le compter fausserait « présents / invités ».
  static bool _isHost(ConferenceAttendance sheet, String identity) =>
      sheet.hostId.isNotEmpty && identity == sheet.hostId;

  void _update(ConferenceAttendance next) {
    state = next;
    _persist(next);
  }

  /// Écritures sérialisées, la dernière l'emporte : deux événements rapprochés
  /// écriraient sinon le même fichier temporaire en parallèle et l'un des
  /// deux finirait tronqué.
  void _persist(ConferenceAttendance sheet) {
    _pendingWrite = sheet;
    _flushing ??= _flush();
  }

  Future<void> _flush() async {
    while (_pendingWrite != null) {
      final next = _pendingWrite!;
      _pendingWrite = null;
      await _store.save(next);
    }
    _flushing = null;
  }
}
