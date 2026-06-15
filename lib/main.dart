import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'config/game_config.dart';
import 'services/ads_service.dart';
import 'services/audio_service.dart';
import 'services/cloud_save_service.dart';
import 'services/firebase_service.dart';
import 'services/iap_service.dart';
import 'systems/achievement_system.dart';
import 'systems/battle_pass.dart';
import 'systems/mission_system.dart';
import 'systems/player_controller.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait-only space shooter.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Boot the offline-first save + meta systems first so the UI can render
  // immediately even if the network is slow or absent.
  final PlayerController player = await PlayerController.boot();
  final BattlePassSystem battlePass = BattlePassSystem(player);
  final MissionSystem missions = MissionSystem(player, battlePass);
  final AchievementSystem achievements = AchievementSystem(player);

  // Sync ad-removal flag immediately.
  AdsService.instance.adsRemoved = player.adsRemoved;

  // Initialise online + device services in the background; never block boot.
  _initServices(player);

  runApp(
    MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<PlayerController>.value(value: player),
        ChangeNotifierProvider<BattlePassSystem>.value(value: battlePass),
        ChangeNotifierProvider<MissionSystem>.value(value: missions),
        ChangeNotifierProvider<AchievementSystem>.value(value: achievements),
      ],
      child: const ChickenHunterApp(),
    ),
  );
}

Future<void> _initServices(PlayerController player) async {
  if (GameConfig.enableAudio) AudioService.instance.init();
  if (GameConfig.enableFirebase) {
    await FirebaseService.instance.init();
    await CloudSaveService.instance.signInAnonymously();
    // Pull cloud save and merge if newer.
    final cloud = await CloudSaveService.instance.pull();
    if (cloud != null) player.mergeFromCloud(cloud);
  }
  if (GameConfig.enableAds) AdsService.instance.init();
  if (GameConfig.enableIap) {
    IapService.instance.onPurchaseGranted = (String id) => _grantPurchase(player, id);
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
