import 'dart:async';

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
import '../widgets/virtual_joystick.dart';
import 'game_over_screen.dart';

/// Hosts the Flame [ChickenHunterGame] and layers the touch HUD on top.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.mobileMode = false});

  /// When true the game canvas is constrained to a phone-like portrait frame.
  final bool mobileMode;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final ChickenHunterGame _game;
  RunResult? _result;

  // Countdown state: 5 → 4 → 3 → 2 → 1 → 0 (GO!)
  int _countdownValue = 5;
  bool _showCountdown = true;
  Timer? _countdownTimer;

  final ValueNotifier<Offset> _joystickDir = ValueNotifier<Offset>(Offset.zero);

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
    _joystickDir.addListener(() => _game.joystickDir.value = _joystickDir.value);
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _joystickDir.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _countdownValue--);
      if (_countdownValue <= 0) {
        timer.cancel();
        _game.frozen.value = false;
        Future<void>.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) setState(() => _showCountdown = false);
        });
      }
    });
  }

  void _revive() {
    AdsService.instance.showRewarded(onReward: () {
      setState(() => _result = null);
      _game.revivePlayer();
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget gameContent = Stack(
      children: <Widget>[
        GameWidget<ChickenHunterGame>(
          game: _game,
          loadingBuilder: (_) => const ColoredBox(
            color: Palette.spaceTop,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  CircularProgressIndicator(color: Palette.hudGreen),
                  SizedBox(height: 16),
                  Text('Entering the chicken galaxy…',
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ),
        ),
        _warpBanner(),
        _topHud(),
        _buffChips(),
        _ultimateButton(),
        _joystickWidget(),
        if (_result != null) _gameOverOverlay(),
        if (_showCountdown) _countdownOverlay(),
      ],
    );

    if (widget.mobileMode) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: gameContent,
          ),
        ),
      );
    }
    return Scaffold(body: gameContent);
  }

  // ---------------------------------------------------------------------------
  // Countdown overlay
  // ---------------------------------------------------------------------------

  Widget _countdownOverlay() {
    final bool isGo = _countdownValue <= 0;
    final String text = isGo ? 'GO!' : '$_countdownValue';
    final Color color = isGo ? Palette.hudGreen : Colors.white;

    return Container(
      color: Colors.black.withOpacity(0.55),
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (Widget child, Animation<double> anim) =>
              ScaleTransition(
                scale: Tween<double>(begin: 1.6, end: 1.0).animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOut),
                ),
                child: FadeTransition(opacity: anim, child: child),
              ),
          child: Text(
            text,
            key: ValueKey<String>(text),
            style: TextStyle(
              fontSize: isGo ? 80 : 110,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 4,
              shadows: <Shadow>[
                Shadow(color: color.withOpacity(0.85), blurRadius: 40),
                const Shadow(color: Colors.black87, blurRadius: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Virtual joystick
  // ---------------------------------------------------------------------------

  Widget _joystickWidget() => Positioned(
        left: 16,
        bottom: 24,
        child: VirtualJoystick(direction: _joystickDir),
      );

  // ---------------------------------------------------------------------------
  // HUD widgets
  // ---------------------------------------------------------------------------

  Widget _topHud() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
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
                  builder: (_, int w, __) =>
                      _badge('WAVE $w', Palette.nebulaPink.withOpacity(0.85)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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
                      boxShadow: <BoxShadow>[
                        BoxShadow(color: fill.withOpacity(0.6), blurRadius: 5)
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 32,
                child: Text('${(hp * 100).round()}%',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

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
                      Shadow(
                          color: Colors.black.withOpacity(0.6), blurRadius: 4),
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
      left: 148, // offset right so it doesn't overlap the joystick
      bottom: 24,
      child: ValueListenableBuilder<Map<PowerUpType, double>>(
        valueListenable: _game.activeBuffs,
        builder: (_, Map<PowerUpType, double> buffs, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: buffs.entries.map((MapEntry<PowerUpType, double> e) {
            final PowerUpInfo info = PowerUpInfo.table[e.key]!;
            return Container(
              margin: const EdgeInsets.only(top: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                    ? <BoxShadow>[
                        BoxShadow(
                            color: Palette.hudRed.withOpacity(0.7),
                            blurRadius: 18)
                      ]
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
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Palette.hudYellow),
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

  Widget _badge(String text, Color color,
          {IconData? icon, Color? iconColor}) =>
      Container(
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
            Text(text,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13)),
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
          MaterialPageRoute<void>(
              builder: (_) => GameScreen(mobileMode: widget.mobileMode)),
        );
      },
      onMenu: () {
        AdsService.instance.maybeShowInterstitial();
        Navigator.pop(context);
      },
    );
  }
}
