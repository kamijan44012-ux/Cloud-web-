import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Global, build-time configuration for Chicken Hunter: Space War.
///
/// Anything that is a "knob" (IDs, feature flags, tunables that rarely change)
/// lives here. Live-ops tunables that you want to change without shipping an
/// update should instead be read from Firebase Remote Config — see
/// [services/firebase_service.dart].
class GameConfig {
  GameConfig._();

  static const String appName = 'Fight Arena';
  static const String version = '1.0.0';

  // ---------------------------------------------------------------------------
  // Feature flags. Flip these off to ship a leaner / offline build.
  //
  // AdMob (google_mobile_ads) and Play Billing (in_app_purchase) are mobile-only
  // plugins, so they are auto-disabled on web (e.g. the GitHub Pages demo build).
  // Firebase and audio work on web, so they stay on (and remain fail-soft).
  // ---------------------------------------------------------------------------
  static const bool enableFirebase = true;
  static const bool enableAds = !kIsWeb;
  static const bool enableIap = !kIsWeb;
  static const bool enableAudio = true;

  // ---------------------------------------------------------------------------
  // AdMob unit IDs. The values below are Google's official *test* IDs and are
  // safe to ship while developing. Replace with your real unit IDs before
  // release (and never click your own live ads).
  // ---------------------------------------------------------------------------
  static const String admobAppIdAndroid = 'ca-app-pub-3940256099942544~3347511713';
  static const String bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const String interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
  static const String rewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';

  // ---------------------------------------------------------------------------
  // In-app purchase product IDs (must match Play Console).
  // ---------------------------------------------------------------------------
  static const String iapRemoveAds = 'remove_ads';
  static const String iapGems500 = 'gems_500';
  static const String iapGems1200 = 'gems_1200';
  static const String iapGems3000 = 'gems_3000';
  static const String iapBattlePass = 'battle_pass_season';
  static const String iapStarterPack = 'starter_pack';

  static const List<String> iapProductIds = <String>[
    iapRemoveAds,
    iapGems500,
    iapGems1200,
    iapGems3000,
    iapBattlePass,
    iapStarterPack,
  ];

  // ---------------------------------------------------------------------------
  // Rendering / performance.
  // ---------------------------------------------------------------------------
  /// Target logical resolution the game is designed against. The viewport
  /// letterboxes to this so the game looks identical on every aspect ratio.
  static const Size designResolution = Size(540, 960);

  /// On low-end devices we reduce particle counts and star density.
  static int particleBudget = 120;
  static int starCount = 80;

  /// Auto-fire cadence (seconds between shots) before weapon upgrades.
  static const double baseFireInterval = 0.30;
}
