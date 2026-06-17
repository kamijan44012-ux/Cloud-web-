import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/palette.dart';
import '../../game/pvp_game.dart';
import '../../systems/player_controller.dart';

/// Flutter shell that hosts [PvpGame] and overlays the PvP HUD:
///  • Opponent health bar at the top.
///  • My health bar at the bottom-left.
///  • Quit button at the bottom-right.
///  • Win/Lose overlay at the end (with +100 coins on victory).
class PvpGameScreen extends StatefulWidget {
  const PvpGameScreen({
    super.key,
    required this.roomCode,
    required this.isHost,
    required this.opponentName,
    required this.opponentShipId,
    this.wagerAmount = 0,
  });

  final String roomCode;
  final bool isHost;
  final String opponentName;
  final String opponentShipId;
  /// Coins each player wagered. Winner receives wagerAmount * 2.
  final int wagerAmount;

  @override
  State<PvpGameScreen> createState() => _PvpGameScreenState();
}

class _PvpGameScreenState extends State<PvpGameScreen> {
  late final PvpGame _game;
  PvpOutcome? _outcome;

  // Countdown state: 5 → 4 → 3 → 2 → 1 → 0 (FIGHT!)
  int _countdownValue = 5;
  bool _showCountdown = true;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    final PlayerController player = context.read<PlayerController>();
    _game = PvpGame(
      player: player,
      roomCode: widget.roomCode,
      isHost: widget.isHost,
      opponentName: widget.opponentName,
      opponentShipId: widget.opponentShipId,
      onMatchOver: (PvpOutcome outcome) {
        if (!mounted) return;
        if (outcome == PvpOutcome.win) {
          final int prize = widget.wagerAmount > 0 ? widget.wagerAmount * 2 : 100;
          context.read<PlayerController>().addCoins(prize);
        }
        setState(() => _outcome = outcome);
      },
    );
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
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
        // Unfreeze game — both players start playing simultaneously
        _game.frozen.value = false;
        // Show FIGHT! overlay for 1.5 s then hide it
        Future<void>.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) setState(() => _showCountdown = false);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          GameWidget<PvpGame>(
            game: _game,
            loadingBuilder: (_) => const ColoredBox(
              color: Palette.spaceTop,
              child: Center(
                child: CircularProgressIndicator(color: Palette.hudYellow),
              ),
            ),
          ),
          _banner(),
          _opponentHud(),
          _myHud(),
          if (_outcome != null) _resultOverlay(),
          if (_showCountdown) _countdownOverlay(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Countdown overlay (shown before match starts)
  // ---------------------------------------------------------------------------

  Widget _countdownOverlay() {
    final bool isFight = _countdownValue <= 0;
    final String text = isFight ? 'FIGHT!' : '$_countdownValue';
    final Color color = isFight ? Palette.hudYellow : Colors.white;

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
              fontSize: isFight ? 72 : 110,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 4,
              shadows: <Shadow>[
                Shadow(
                  color: color.withOpacity(0.85),
                  blurRadius: 40,
                ),
                const Shadow(color: Colors.black87, blurRadius: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HUD widgets
  // ---------------------------------------------------------------------------

  Widget _banner() => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 56),
            child: ValueListenableBuilder<String>(
              valueListenable: _game.banner,
              builder: (_, String text, __) => AnimatedOpacity(
                opacity: text.isEmpty ? 0 : 1,
                duration: const Duration(milliseconds: 250),
                child: Center(
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2,
                      shadows: <Shadow>[
                        Shadow(color: Palette.hudYellow, blurRadius: 20),
                        Shadow(color: Colors.black54, blurRadius: 4),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _opponentHud() => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _healthBar(
              label: widget.opponentName,
              notifier: _game.opponentHealthFraction,
              color: Palette.hudRed,
            ),
          ),
        ),
      );

  Widget _myHud() => Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                _healthBar(
                  label: 'YOU',
                  notifier: _game.myHealthFraction,
                  color: Palette.hudGreen,
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _confirmQuit,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(Icons.close,
                        color: Colors.white70, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _healthBar({
    required String label,
    required ValueNotifier<double> notifier,
    required Color color,
  }) =>
      ValueListenableBuilder<double>(
        valueListenable: notifier,
        builder: (_, double hp, __) => Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70)),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.favorite, color: color, size: 13),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 110,
                    height: 7,
                    child: Stack(children: <Widget>[
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: hp.clamp(0.0, 1.0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: <Color>[color.withOpacity(0.7), color],
                            ),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                  color: color.withOpacity(0.5),
                                  blurRadius: 4),
                            ],
                          ),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 6),
                  Text('${(hp * 100).round()}%',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      );

  // ---------------------------------------------------------------------------
  // Result overlay
  // ---------------------------------------------------------------------------

  Widget _resultOverlay() {
    final bool won = _outcome == PvpOutcome.win;
    return Container(
      color: Colors.black.withOpacity(0.72),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Palette.spaceBottom,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: won ? Palette.hudYellow : Palette.hudRed, width: 2),
            boxShadow: <BoxShadow>[
              BoxShadow(
                  color: (won ? Palette.hudYellow : Palette.hudRed)
                      .withOpacity(0.4),
                  blurRadius: 32),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                won ? '🏆  VICTORY!' : '💀  DEFEATED',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: won ? Palette.hudYellow : Palette.hudRed,
                ),
              ),
              const SizedBox(height: 16),
              if (won) ...<Widget>[
                Text(
                  '+${widget.wagerAmount > 0 ? widget.wagerAmount * 2 : 100} COINS',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Palette.coin,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Added to your wallet!',
                  style: TextStyle(color: Colors.white60, fontSize: 14),
                ),
              ] else
                const Text(
                  'Better luck next time!',
                  style: TextStyle(color: Colors.white60, fontSize: 15),
                ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        won ? Palette.hudYellow : Palette.hudBlue,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back to Menu',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmQuit() {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: Palette.spaceBottom,
        title: const Text('Quit Match?'),
        content:
            const Text('Your opponent will be declared the winner.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Continue'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Quit',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
