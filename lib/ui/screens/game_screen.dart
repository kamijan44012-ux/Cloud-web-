import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/palette.dart';
import '../../game/chicken_hunter_game.dart';
import '../../models/power_up_type.dart';
import '../../services/ads_service.dart';
import '../../systems/achievement_system.dart';
import '../../systems/battle_pass.dart';
import '../../systems/mission_system.dart';
import '../../systems/player_controller.dart';
import 'game_over_screen.dart';

/// Hosts the Flame [ChickenHunterGame] and layers the touch HUD on top:
/// score/wave readout, health bar, active-buff chips, the ultimate button, and
/// pause. All HUD widgets are driven by the game's ValueNotifiers so they
/// repaint independently of the engine's render loop.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final ChickenHunterGame _game;
  RunResult? _result;

  @override
  void initState() {
    super.initState();
    _game = ChickenHunterGame(
      player: context.read<PlayerController>(),
      missions: context.read<MissionSystem>(),
      achievements: context.read<AchievementSystem>(),
      battlePass: context.read<BattlePassSystem>(),
      onRunOver: (RunResult r) => setState(() => _result = r),
    );
  }

  void _revive() {
    AdsService.instance.showRewarded(onReward: () {
      setState(() => _result = null);
      _game.revivePlayer();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          GameWidget<ChickenHunterGame>(game: _game),
          _topHud(),
          _buffChips(),
          _ultimateButton(),
          if (_result != null) _gameOverOverlay(),
        ],
      ),
    );
  }

  Widget _topHud() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  onPressed: () {
                    _game.pause();
                    _showPause();
                  },
                  icon: const Icon(Icons.pause_circle, size: 32, color: Colors.white),
                ),
                const Spacer(),
                ValueListenableBuilder<int>(
                  valueListenable: _game.score,
                  builder: (_, int s, __) => Text(
                    'SCORE  $s',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
                const Spacer(),
                ValueListenableBuilder<int>(
                  valueListenable: _game.wave,
                  builder: (_, int w, __) => _badge('WAVE $w', Palette.nebulaPink),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Health bar.
            ValueListenableBuilder<double>(
              valueListenable: _game.healthFraction,
              builder: (_, double hp, __) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: hp,
                  minHeight: 12,
                  backgroundColor: Colors.black54,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    hp > 0.3 ? Palette.hudGreen : Palette.hudRed,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buffChips() {
    return Positioned(
      left: 12,
      bottom: 24,
      child: ValueListenableBuilder<Map<PowerUpType, double>>(
        valueListenable: _game.activeBuffs,
        builder: (_, Map<PowerUpType, double> buffs, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: buffs.entries.map((MapEntry<PowerUpType, double> e) {
            final PowerUpInfo info = PowerUpInfo.table[e.key]!;
            return Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: info.color.withOpacity(0.85),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${info.glyph} ${e.value.toStringAsFixed(1)}s',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _ultimateButton() {
    return Positioned(
      right: 16,
      bottom: 24,
      child: ValueListenableBuilder<double>(
        valueListenable: _game.nukeCharge,
        builder: (_, double charge, __) {
          final bool ready = charge >= 1.0;
          return GestureDetector(
            onTap: ready ? _game.triggerNuke : null,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ready ? Palette.hudRed : Colors.black54,
                border: Border.all(color: Palette.hudYellow, width: 3),
                boxShadow: ready
                    ? <BoxShadow>[BoxShadow(color: Palette.hudRed.withOpacity(0.7), blurRadius: 18)]
                    : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  SizedBox(
                    width: 70,
                    height: 70,
                    child: CircularProgressIndicator(
                      value: charge,
                      strokeWidth: 5,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(Palette.hudYellow),
                    ),
                  ),
                  const Text('☢', style: TextStyle(fontSize: 30)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
      );

  void _showPause() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: Palette.spaceBottom,
        title: const Text('Paused'),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _game.resume();
            },
            child: const Text('Resume'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Quit'),
          ),
        ],
      ),
    );
  }

  Widget _gameOverOverlay() {
    return GameOverOverlay(
      result: _result!,
      onRevive: AdsService.instance.isRewardedReady ? _revive : null,
      onRetry: () {
        AdsService.instance.maybeShowInterstitial();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(builder: (_) => const GameScreen()),
        );
      },
      onMenu: () {
        AdsService.instance.maybeShowInterstitial();
        Navigator.pop(context);
      },
    );
  }
}
