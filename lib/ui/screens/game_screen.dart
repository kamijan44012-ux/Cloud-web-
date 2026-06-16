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
          _warpBanner(),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Pause + compact health, stacked on the left.
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                GestureDetector(
                  onTap: () {
                    _game.pause();
                    _showPause();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(Icons.pause, size: 20, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                _healthBar(),
              ],
            ),
            const Spacer(),
            // Score + wave, compact pills on the right.
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                ValueListenableBuilder<int>(
                  valueListenable: _game.score,
                  builder: (_, int s, __) => _badge('$s', Colors.black.withOpacity(0.4),
                      icon: Icons.star, iconColor: Palette.hudYellow),
                ),
                const SizedBox(height: 6),
                ValueListenableBuilder<int>(
                  valueListenable: _game.wave,
                  builder: (_, int w, __) => _badge('WAVE $w', Palette.nebulaPink.withOpacity(0.85)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Compact, modern health capsule: heart icon + slim gradient bar + percent.
  Widget _healthBar() {
    return ValueListenableBuilder<double>(
      valueListenable: _game.healthFraction,
      builder: (_, double hp, __) {
        final Color fill = hp > 0.5
            ? Palette.hudGreen
            : (hp > 0.25 ? Palette.hudYellow : Palette.hudRed);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.38),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.favorite, color: fill, size: 15),
              const SizedBox(width: 6),
              Stack(
                alignment: Alignment.centerLeft,
                children: <Widget>[
                  Container(
                    width: 96,
                    height: 7,
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 96 * hp.clamp(0.0, 1.0),
                    height: 7,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[fill.withOpacity(0.7), fill],
                      ),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: <BoxShadow>[BoxShadow(color: fill.withOpacity(0.6), blurRadius: 5)],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 32,
                child: Text('${(hp * 100).round()}%',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Big centered banner shown during warps / boss intros.
  Widget _warpBanner() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 70),
          child: ValueListenableBuilder<String>(
            valueListenable: _game.banner,
            builder: (_, String text, __) => AnimatedOpacity(
              opacity: text.isEmpty ? 0 : 1,
              duration: const Duration(milliseconds: 250),
              child: Center(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 2,
                    shadows: <Shadow>[
                      const Shadow(color: Palette.hudBlue, blurRadius: 18),
                      Shadow(color: Colors.black.withOpacity(0.6), blurRadius: 4),
                    ],
                  ),
                ),
              ),
            ),
          ),
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

  Widget _badge(String text, Color color, {IconData? icon, Color? iconColor}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 14, color: iconColor ?? Colors.white),
              const SizedBox(width: 4),
            ],
            Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
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
