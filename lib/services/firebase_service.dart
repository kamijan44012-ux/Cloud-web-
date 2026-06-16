import 'package:flutter/foundation.dart';

import '../config/game_config.dart';
import '../firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

/// Thin wrapper around Firebase init, Analytics and Remote Config. All calls
/// are null-safe no-ops when Firebase is disabled or fails to initialise so a
/// missing config never crashes the game.
class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  bool _ready = false;
  FirebaseAnalytics? _analytics;
  FirebaseRemoteConfig? _remoteConfig;

  bool get isReady => _ready;
  FirebaseAnalytics? get analytics => _analytics;

  Future<void> init() async {
    if (!GameConfig.enableFirebase) return;
    try {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
      // Core is up: Auth and Firestore are usable from here on. This is the
      // signal AuthService uses to decide between Firebase and local fallback.
      _ready = true;
      _analytics = FirebaseAnalytics.instance;
    } catch (e) {
      // Fails if Firebase secrets not added to GitHub. App runs offline and
      // AuthService falls back to on-device accounts.
      debugPrint('Firebase init skipped: $e');
      return;
    }
    // Remote Config is optional live-ops tuning; never let it block auth.
    try {
      await _initRemoteConfig();
    } catch (e) {
      debugPrint('Remote Config skipped: $e');
    }
  }

  Future<void> _initRemoteConfig() async {
    _remoteConfig = FirebaseRemoteConfig.instance;
    await _remoteConfig!.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(hours: 1),
    ));
    await _remoteConfig!.setDefaults(<String, dynamic>{
      'enemy_health_multiplier': 1.0,
      'coin_drop_multiplier': 1.0,
      'event_name': 'none',
      'gem_sale_percent': 0,
    });
    await _remoteConfig!.fetchAndActivate();
  }

  double remoteDouble(String key, double fallback) =>
      _remoteConfig?.getDouble(key) ?? fallback;
  String remoteString(String key, String fallback) {
    final String? v = _remoteConfig?.getString(key);
    return (v == null || v.isEmpty) ? fallback : v;
  }

  Future<void> logEvent(String name, [Map<String, Object>? params]) async {
    if (!_ready) return;
    await _analytics?.logEvent(name: name, parameters: params);
  }
}
