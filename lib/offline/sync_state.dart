import 'package:flutter_riverpod/flutter_riverpod.dart';

/// État de la synchronisation, affiché dans l'en-tête de la coquille.
enum SyncStatus { synced, syncing, offline, pending, error }

/// Photographie de l'état local-first : réseau, dernière synchronisation,
/// éléments en attente dans la file d'écritures, dernier rapport de rejeu.
class SyncState {
  final SyncStatus status;
  final DateTime? lastSyncAt;
  final int pendingWrites;
  final int conflicts;
  final String? message;

  const SyncState({
    this.status = SyncStatus.synced,
    this.lastSyncAt,
    this.pendingWrites = 0,
    this.conflicts = 0,
    this.message,
  });

  bool get isOffline => status == SyncStatus.offline;

  SyncState copyWith({
    SyncStatus? status,
    DateTime? lastSyncAt,
    int? pendingWrites,
    int? conflicts,
    String? message,
    bool clearMessage = false,
  }) =>
      SyncState(
        status: status ?? this.status,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        pendingWrites: pendingWrites ?? this.pendingWrites,
        conflicts: conflicts ?? this.conflicts,
        message: clearMessage ? null : (message ?? this.message),
      );

  /// Libellé court de l'indicateur d'en-tête.
  String get label {
    switch (status) {
      case SyncStatus.synced:
        return 'Synchronisé';
      case SyncStatus.syncing:
        return 'Synchronisation…';
      case SyncStatus.offline:
        return pendingWrites > 0
            ? 'Hors ligne · $pendingWrites en attente'
            : 'Hors ligne';
      case SyncStatus.pending:
        return '$pendingWrites en attente';
      case SyncStatus.error:
        return 'Erreur de synchronisation';
    }
  }

  /// « Dernière synchronisation à HH:MM », pour le bandeau hors ligne.
  String get lastSyncLabel {
    final at = lastSyncAt;
    if (at == null) return 'jamais synchronisé';
    final local = at.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    final today = DateTime.now();
    final sameDay = local.year == today.year &&
        local.month == today.month &&
        local.day == today.day;
    if (sameDay) return 'dernière synchronisation à $hh:$mm';
    final dd = local.day.toString().padLeft(2, '0');
    final mo = local.month.toString().padLeft(2, '0');
    return 'dernière synchronisation le $dd/$mo à $hh:$mm';
  }
}

/// État courant, piloté par le service de synchronisation (`lib/offline/`).
/// Défini ici, sans dépendance, pour que l'en-tête puisse l'afficher avant
/// même que le service soit démarré (écran de test, mode hors ligne).
final syncStateProvider = StateProvider<SyncState>((ref) => const SyncState());
