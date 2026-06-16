import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'config/game_config.dart';
import 'services/ads_service.dart';
import 'services/audio_service.dart';
import 'services/auth_service.dart';
import 'services/firebase_service.dart';
import 'services/iap_service.dart';
import 'services/profile_service.dart';
import 'services/referral_service.dart';
import 'systems/achievement_system.dart';
import 'systems/battle_pass.dart';
import 'systems/mission_system.dart';
import 'systems/player_controller.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Boot local save so the UI can render immediately.
  final PlayerController player = await PlayerController.boot();
  final BattlePassSystem battlePass = BattlePassSystem(player);
  final MissionSystem missions = MissionSystem(player, battlePass);
  final AchievementSystem achievements = AchievementSystem(player);

  AdsService.instance.adsRemoved = player.adsRemoved;

  // Firebase must be initialized before the auth gate renders.
  if (GameConfig.enableFirebase) {
    await FirebaseService.instance.init();
  }

  // Wire up auth (Firebase when configured, on-device fallback otherwise) so
  // every player can register and sign in, even without Firebase secrets.
  await AuthService.instance.init();

  // Load the locally-saved avatar/profile preference.
  await ProfileService.instance.load();

  // Capture an invite code from the URL (#ref=CODE) before the UI renders.
  try {
    final String fragment = Uri.base.fragment;
    if (fragment.startsWith('ref=')) {
      ReferralService.instance.pendingRefCode =
          fragment.substring(4).trim().toUpperCase();
    }
  } catch (_) {}

  // Non-blocking background services.
  _initBackgroundServices(player);

  runApp(
    MultiProvider(
      providers: <ChangeNotifierProvider<dynamic>>[
        ChangeNotifierProvider<PlayerController>.value(value: player),
        ChangeNotifierProvider<BattlePassSystem>.value(value: battlePass),
        ChangeNotifierProvider<MissionSystem>.value(value: missions),
        ChangeNotifierProvider<AchievementSystem>.value(value: achievements),
      ],
      child: const ChickenHunterApp(),
    ),
  );
}

Future<void> _initBackgroundServices(PlayerController player) async {
  if (GameConfig.enableAudio) AudioService.instance.init();
  if (GameConfig.enableAds) AdsService.instance.init();
  if (GameConfig.enableIap) {
    IapService.instance.onPurchaseGranted =
        (String id) => _grantPurchase(player, id);
    IapService.instance.init();
  }
}

void _grantPurchase(PlayerController player, String productId) {
  switch (productId) {
    case GameConfig.iapRemoveAds:
      player.grantRemoveAds();
      AdsService.instance.adsRemoved = true;
      break;
    case GameConfig.iapGems500:
      player.addGems(500);
      break;
    case GameConfig.iapGems1200:
      player.addGems(1200);
      break;
    case GameConfig.iapGems3000:
      player.addGems(3000);
      break;
    case GameConfig.iapBattlePass:
      player.grantBattlePassPremium();
      break;
    case GameConfig.iapStarterPack:
      player.addGems(300);
      player.addCoins(5000);
      break;
  }
}
