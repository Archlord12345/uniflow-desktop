import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/motion.dart';

/// Préférences locales du poste, persistées avec `shared_preferences`.
///
/// L'écran Paramètres affichait trois interrupteurs figés (« Notifications
/// système », « Mode hors connexion »…) sans effet : ils sont remplacés par
/// des réglages réellement lus par l'application.
class AppPreferences {
  /// Afficher un bandeau à l'arrivée d'une notification non lue.
  final bool notificationBanners;

  /// Garder la session Appwrite d'une ouverture à l'autre.
  final bool keepSession;

  /// Réduire les animations (cascades, transitions) : accessibilité et
  /// machines modestes.
  final bool reduceMotion;

  /// Barre latérale repliée au démarrage.
  final bool compactSidebar;

  const AppPreferences({
    this.notificationBanners = true,
    this.keepSession = true,
    this.reduceMotion = false,
    this.compactSidebar = false,
  });

  AppPreferences copyWith({
    bool? notificationBanners,
    bool? keepSession,
    bool? reduceMotion,
    bool? compactSidebar,
  }) =>
      AppPreferences(
        notificationBanners: notificationBanners ?? this.notificationBanners,
        keepSession: keepSession ?? this.keepSession,
        reduceMotion: reduceMotion ?? this.reduceMotion,
        compactSidebar: compactSidebar ?? this.compactSidebar,
      );
}

class PreferencesNotifier extends StateNotifier<AppPreferences> {
  PreferencesNotifier() : super(const AppPreferences()) {
    _load();
  }

  static const _kBanners = 'prefs.notificationBanners';
  static const _kKeepSession = 'prefs.keepSession';
  static const _kReduceMotion = 'prefs.reduceMotion';
  static const _kCompactSidebar = 'prefs.compactSidebar';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = AppPreferences(
        notificationBanners: prefs.getBool(_kBanners) ?? true,
        keepSession: prefs.getBool(_kKeepSession) ?? true,
        reduceMotion: prefs.getBool(_kReduceMotion) ?? false,
        compactSidebar: prefs.getBool(_kCompactSidebar) ?? false,
      );
      motionReduced.value = state.reduceMotion;
    } catch (_) {
      // Stockage local indisponible (tests, profil verrouillé) : valeurs par
      // défaut, l'application reste utilisable.
    }
  }

  Future<void> _set(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {}
  }

  void setNotificationBanners(bool value) {
    state = state.copyWith(notificationBanners: value);
    _set(_kBanners, value);
  }

  void setKeepSession(bool value) {
    state = state.copyWith(keepSession: value);
    _set(_kKeepSession, value);
  }

  void setReduceMotion(bool value) {
    state = state.copyWith(reduceMotion: value);
    motionReduced.value = value;
    _set(_kReduceMotion, value);
  }

  void setCompactSidebar(bool value) {
    state = state.copyWith(compactSidebar: value);
    _set(_kCompactSidebar, value);
  }
}

final preferencesProvider =
    StateNotifierProvider<PreferencesNotifier, AppPreferences>((ref) {
  return PreferencesNotifier();
});
