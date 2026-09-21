/// Feuille de présence d'une réunion hébergée par ce poste.
///
/// Modèle pur, sans Flutter ni Appwrite : il se nourrit des événements du
/// serveur média (participant connecté / déconnecté, reçus par webhook) et
/// des tickets délivrés par l'API de jonction, et se persiste en JSON sur le
/// poste. Toutes les opérations renvoient une nouvelle instance : l'écran se
/// reconstruit d'un état cohérent, et un test rejoue une séquence
/// d'événements sans horloge réelle.
library;

/// Verdict de présence d'un participant.
enum AttendanceStatus {
  /// Durée cumulée au moins égale au seuil de la réunion.
  present('Présent'),

  /// S'est connecté, mais pas assez longtemps.
  partial('Partiel'),

  /// Invité (ticket délivré) ou attendu, jamais connecté.
  absent('Absent');

  final String label;
  const AttendanceStatus(this.label);
}

/// Une connexion d'un participant : de son arrivée à son départ.
///
/// Un participant qui perd le réseau et revient a plusieurs connexions ; la
/// présence est la somme de leurs durées, pas l'écart entre la première
/// arrivée et le dernier départ — sinon une coupure d'une heure compterait
/// comme du temps de cours.
class AttendanceSession {
  final DateTime joinedAt;

  /// `null` tant que le participant est connecté.
  final DateTime? leftAt;

  const AttendanceSession({required this.joinedAt, this.leftAt});

  bool get isOpen => leftAt == null;

  /// Durée à l'instant [now] ; une connexion ouverte court jusqu'à [now].
  Duration durationAt(DateTime now) {
    final end = leftAt ?? now;
    final elapsed = end.difference(joinedAt);
    // Les événements du serveur média arrivent parfois dans le désordre
    // (le départ peut être horodaté avant l'arrivée de quelques
    // millisecondes) : une durée négative ne doit jamais retrancher du temps.
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  AttendanceSession close(DateTime at) => AttendanceSession(
        joinedAt: joinedAt,
        leftAt: at.isBefore(joinedAt) ? joinedAt : at,
      );

  Map<String, dynamic> toJson() => {
        'joinedAt': joinedAt.toUtc().toIso8601String(),
        if (leftAt != null) 'leftAt': leftAt!.toUtc().toIso8601String(),
      };

  static AttendanceSession? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final joinedAt = _parseDate(raw['joinedAt']);
    if (joinedAt == null) return null;
    return AttendanceSession(
        joinedAt: joinedAt, leftAt: _parseDate(raw['leftAt']));
  }
}

/// Un participant de la feuille : son identité LiveKit, ce qu'on sait de lui
/// et ses connexions successives.
class AttendanceEntry {
  /// Identité LiveKit (le `sub` du jeton) : c'est la clé du participant, le
  /// nom affiché pouvant être vide ou dupliqué.
  final String identity;
  final String displayName;

  /// Identifiant du compte Appwrite, quand le ticket de jonction l'a fourni.
  final String? userId;

  /// Instant où l'API de jonction lui a délivré un ticket ; `null` s'il est
  /// arrivé sans passer par elle (l'hôte, par exemple).
  final DateTime? invitedAt;

  final List<AttendanceSession> sessions;

  const AttendanceEntry({
    required this.identity,
    this.displayName = '',
    this.userId,
    this.invitedAt,
    this.sessions = const [],
  });

  /// Nom à afficher : le nom déclaré, sinon l'identité technique.
  String get label => displayName.trim().isEmpty ? identity : displayName;

  bool get isConnected => sessions.any((session) => session.isOpen);

  /// Vrai dès qu'une connexion a eu lieu, même brève.
  bool get hasConnected => sessions.isNotEmpty;

  int get connectionCount => sessions.length;

  /// Première arrivée, `null` s'il ne s'est jamais connecté.
  DateTime? get firstJoinedAt =>
      sessions.isEmpty ? null : sessions.first.joinedAt;

  /// Dernier départ ; `null` s'il est encore connecté ou jamais venu.
  DateTime? get lastLeftAt {
    if (sessions.isEmpty || isConnected) return null;
    DateTime? last;
    for (final session in sessions) {
      final left = session.leftAt!;
      if (last == null || left.isAfter(last)) last = left;
    }
    return last;
  }

  /// Durée cumulée de toutes les connexions à l'instant [now].
  Duration totalDuration(DateTime now) => sessions.fold(
        Duration.zero,
        (sum, session) => sum + session.durationAt(now),
      );

  AttendanceEntry copyWith({
    String? displayName,
    String? userId,
    DateTime? invitedAt,
    List<AttendanceSession>? sessions,
  }) =>
      AttendanceEntry(
        identity: identity,
        displayName: displayName ?? this.displayName,
        userId: userId ?? this.userId,
        invitedAt: invitedAt ?? this.invitedAt,
        sessions: sessions ?? this.sessions,
      );

  Map<String, dynamic> toJson() => {
        'identity': identity,
        'displayName': displayName,
        if (userId != null) 'userId': userId,
        if (invitedAt != null)
          'invitedAt': invitedAt!.toUtc().toIso8601String(),
        'sessions': [for (final session in sessions) session.toJson()],
      };

  static AttendanceEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final identity = raw['identity'];
    if (identity is! String || identity.isEmpty) return null;
    final sessionsRaw = raw['sessions'];
    return AttendanceEntry(
      identity: identity,
      displayName: (raw['displayName'] ?? '').toString(),
      userId: raw['userId'] is String ? raw['userId'] as String : null,
      invitedAt: _parseDate(raw['invitedAt']),
      sessions: [
        if (sessionsRaw is List)
          for (final item in sessionsRaw)
            if (AttendanceSession.fromJson(item) case final session?) session,
      ],
    );
  }
}

/// Décompte d'une feuille à un instant donné.
class AttendanceSummary {
  final int invited;
  final int connectedNow;
  final int present;
  final int partial;
  final int absent;
  final Duration meetingDuration;

  const AttendanceSummary({
    required this.invited,
    required this.connectedNow,
    required this.present,
    required this.partial,
    required this.absent,
    required this.meetingDuration,
  });
}

/// La feuille de présence d'une réunion.
class ConferenceAttendance {
  /// Seuil par défaut : la moitié de la durée de la réunion.
  static const double defaultPresenceThreshold = 0.5;

  /// Version du format JSON persisté, pour pouvoir le faire évoluer sans
  /// perdre les feuilles déjà écrites.
  static const int formatVersion = 1;

  /// Identifiant de la réunion (nom de la salle LiveKit).
  final String conferenceId;
  final String title;
  final String hostId;
  final String hostName;
  final DateTime startedAt;

  /// `null` tant que la réunion est en cours.
  final DateTime? endedAt;

  /// Part de la durée de la réunion à partir de laquelle un participant est
  /// compté présent (0,5 = la moitié).
  final double presenceThreshold;

  /// Séance d'emploi du temps (`academic_schedules`) à laquelle la réunion
  /// est rattachée, si l'hôte l'a indiqué.
  final String? scheduleId;

  /// Participants, dans l'ordre de première apparition.
  final List<AttendanceEntry> entries;

  const ConferenceAttendance({
    required this.conferenceId,
    required this.title,
    required this.hostId,
    required this.hostName,
    required this.startedAt,
    this.endedAt,
    this.presenceThreshold = defaultPresenceThreshold,
    this.scheduleId,
    this.entries = const [],
  });

  bool get isClosed => endedAt != null;

  /// Durée de la réunion à l'instant [now] (jusqu'à sa fin si elle est close).
  Duration durationAt(DateTime now) {
    final end = endedAt ?? now;
    final elapsed = end.difference(startedAt);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  /// Durée de connexion exigée pour être compté présent.
  Duration requiredPresenceAt(DateTime now) =>
      durationAt(now) * presenceThreshold;

  /// Dernier instant dont la feuille a connaissance : début, ticket, arrivée
  /// ou départ le plus tardif.
  ///
  /// C'est la fin qu'on donne à une réunion dont l'application s'est arrêtée
  /// sans la clore (coupure de courant) : sinon ses participants « encore
  /// connectés » cumuleraient des jours de présence à la relecture.
  DateTime get lastActivityAt {
    var last = endedAt ?? startedAt;
    void consider(DateTime? instant) {
      if (instant != null && instant.isAfter(last)) last = instant;
    }

    for (final entry in entries) {
      consider(entry.invitedAt);
      for (final session in entry.sessions) {
        consider(session.joinedAt);
        consider(session.leftAt);
      }
    }
    return last;
  }

  /// Verdict d'un participant à l'instant [now].
  ///
  /// Pendant la réunion le verdict est provisoire : la durée exigée grandit
  /// avec la réunion, un participant « présent » à la dixième minute peut
  /// finir « partiel » s'il part à la vingtième.
  AttendanceStatus statusOf(AttendanceEntry entry, DateTime now) {
    if (!entry.hasConnected) return AttendanceStatus.absent;
    final total = entry.totalDuration(now);
    return total >= requiredPresenceAt(now)
        ? AttendanceStatus.present
        : AttendanceStatus.partial;
  }

  AttendanceEntry? entryFor(String identity) {
    for (final entry in entries) {
      if (entry.identity == identity) return entry;
    }
    return null;
  }

  int get invitedCount => entries.length;

  int connectedCount() => entries.where((entry) => entry.isConnected).length;

  int countWithStatus(AttendanceStatus status, DateTime now) =>
      entries.where((entry) => statusOf(entry, now) == status).length;

  AttendanceSummary summaryAt(DateTime now) => AttendanceSummary(
        invited: invitedCount,
        connectedNow: connectedCount(),
        present: countWithStatus(AttendanceStatus.present, now),
        partial: countWithStatus(AttendanceStatus.partial, now),
        absent: countWithStatus(AttendanceStatus.absent, now),
        meetingDuration: durationAt(now),
      );

  /// Participants triés pour l'affichage : connectés d'abord, puis ceux qui
  /// sont venus, puis les absents ; ordre alphabétique à l'intérieur.
  List<AttendanceEntry> sortedEntries() {
    final sorted = List<AttendanceEntry>.of(entries);
    int rank(AttendanceEntry entry) =>
        entry.isConnected ? 0 : (entry.hasConnected ? 1 : 2);
    sorted.sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      if (byRank != 0) return byRank;
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
    return sorted;
  }

  // --- Événements --------------------------------------------------------

  /// Un ticket de jonction a été délivré à [identity].
  ///
  /// Le participant figure dès lors sur la feuille : s'il ne se connecte
  /// jamais, il y restera « absent » — c'est ce qui distingue un invité qui
  /// n'est pas venu d'un inconnu.
  ConferenceAttendance recordTicket({
    required String identity,
    String displayName = '',
    String? userId,
    required DateTime at,
  }) {
    final existing = entryFor(identity);
    if (existing == null) {
      return _withEntries([
        ...entries,
        AttendanceEntry(
          identity: identity,
          displayName: displayName.trim(),
          userId: _cleanId(userId),
          invitedAt: at,
        ),
      ]);
    }
    // Un second ticket pour la même identité (page rechargée, nouvel
    // appareil) complète ce qu'on sait sans effacer l'historique.
    return _replace(existing.copyWith(
      displayName: existing.displayName.isEmpty ? displayName.trim() : null,
      userId: existing.userId ?? _cleanId(userId),
      invitedAt: existing.invitedAt ?? at,
    ));
  }

  /// Le serveur média signale l'arrivée de [identity].
  ConferenceAttendance recordJoin({
    required String identity,
    String displayName = '',
    required DateTime at,
  }) {
    final existing = entryFor(identity) ?? AttendanceEntry(identity: identity);
    // Une arrivée alors qu'une connexion est encore ouverte veut dire que le
    // départ précédent n'a pas été reçu : on le pose à l'instant de la
    // nouvelle arrivée plutôt que de compter deux connexions en parallèle.
    final sessions = [
      for (final session in existing.sessions)
        session.isOpen ? session.close(at) : session,
      AttendanceSession(joinedAt: at),
    ];
    final updated = existing.copyWith(
      displayName: displayName.trim().isEmpty ? null : displayName.trim(),
      sessions: sessions,
    );
    return entryFor(identity) == null
        ? _withEntries([...entries, updated])
        : _replace(updated);
  }

  /// Le serveur média signale le départ de [identity].
  ///
  /// Un départ sans arrivée connue est ignoré : rien à clore, et inventer
  /// une connexion fausserait la durée.
  ConferenceAttendance recordLeave({
    required String identity,
    required DateTime at,
  }) {
    final existing = entryFor(identity);
    if (existing == null || !existing.isConnected) return this;
    return _replace(existing.copyWith(sessions: [
      for (final session in existing.sessions)
        session.isOpen ? session.close(at) : session,
    ]));
  }

  /// Clôt la réunion : toutes les connexions ouvertes s'arrêtent à [at].
  ConferenceAttendance close({required DateTime at}) {
    final end = endedAt ?? (at.isBefore(startedAt) ? startedAt : at);
    return ConferenceAttendance(
      conferenceId: conferenceId,
      title: title,
      hostId: hostId,
      hostName: hostName,
      startedAt: startedAt,
      endedAt: end,
      presenceThreshold: presenceThreshold,
      scheduleId: scheduleId,
      entries: [
        for (final entry in entries)
          entry.copyWith(sessions: [
            for (final session in entry.sessions)
              session.isOpen ? session.close(end) : session,
          ]),
      ],
    );
  }

  /// Change le seuil de présence (borné entre 0 et 1).
  ConferenceAttendance withPresenceThreshold(double threshold) =>
      _copy(presenceThreshold: threshold.clamp(0.0, 1.0).toDouble());

  ConferenceAttendance withSchedule(String? scheduleId) =>
      _copy(scheduleId: scheduleId, clearSchedule: scheduleId == null);

  ConferenceAttendance _withEntries(List<AttendanceEntry> next) =>
      _copy(entries: next);

  ConferenceAttendance _replace(AttendanceEntry updated) => _withEntries([
        for (final entry in entries)
          entry.identity == updated.identity ? updated : entry,
      ]);

  ConferenceAttendance _copy({
    List<AttendanceEntry>? entries,
    double? presenceThreshold,
    String? scheduleId,
    bool clearSchedule = false,
  }) =>
      ConferenceAttendance(
        conferenceId: conferenceId,
        title: title,
        hostId: hostId,
        hostName: hostName,
        startedAt: startedAt,
        endedAt: endedAt,
        presenceThreshold: presenceThreshold ?? this.presenceThreshold,
        scheduleId: clearSchedule ? null : (scheduleId ?? this.scheduleId),
        entries: entries ?? this.entries,
      );

  static String? _cleanId(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  // --- Persistance -------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'version': formatVersion,
        'conferenceId': conferenceId,
        'title': title,
        'hostId': hostId,
        'hostName': hostName,
        'startedAt': startedAt.toUtc().toIso8601String(),
        if (endedAt != null) 'endedAt': endedAt!.toUtc().toIso8601String(),
        'presenceThreshold': presenceThreshold,
        if (scheduleId != null) 'scheduleId': scheduleId,
        'entries': [for (final entry in entries) entry.toJson()],
      };

  /// Relit une feuille. Renvoie `null` plutôt que de lever : un fichier
  /// tronqué (arrêt brutal pendant l'écriture) ne doit pas empêcher les
  /// autres feuilles de s'afficher.
  static ConferenceAttendance? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['conferenceId'];
    final startedAt = _parseDate(raw['startedAt']);
    if (id is! String || id.isEmpty || startedAt == null) return null;
    final threshold = raw['presenceThreshold'];
    final entriesRaw = raw['entries'];
    return ConferenceAttendance(
      conferenceId: id,
      title: (raw['title'] ?? 'Réunion').toString(),
      hostId: (raw['hostId'] ?? '').toString(),
      hostName: (raw['hostName'] ?? '').toString(),
      startedAt: startedAt,
      endedAt: _parseDate(raw['endedAt']),
      presenceThreshold: threshold is num
          ? threshold.toDouble().clamp(0.0, 1.0).toDouble()
          : defaultPresenceThreshold,
      scheduleId:
          raw['scheduleId'] is String ? raw['scheduleId'] as String : null,
      entries: [
        if (entriesRaw is List)
          for (final item in entriesRaw)
            if (AttendanceEntry.fromJson(item) case final entry?) entry,
      ],
    );
  }
}

/// Dates persistées en UTC, relues en heure locale : c'est l'heure locale
/// qui figure sur la feuille imprimée, quelle que soit la machine qui relit.
DateTime? _parseDate(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}
