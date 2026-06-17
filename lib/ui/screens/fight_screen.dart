import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../fight/fight_data.dart';
import '../../fight/fight_game.dart';

/// Full fighting-game experience: mode select → char select → fight → result.
class FightScreen extends StatefulWidget {
  const FightScreen({super.key});

  @override
  State<FightScreen> createState() => _FightScreenState();
}

class _FightScreenState extends State<FightScreen> {
  _ScreenPhase _phase = _ScreenPhase.modeSelect;
  GameMode _gameMode = GameMode.vsBot;
  CharacterData _p1Char = CharacterData.shadow;
  CharacterData _p2Char = CharacterData.blaze;
  bool _selectingP2 = false;
  FightGame? _game;
  String _resultMsg = '';

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  void _startFight() {
    final FightGame game = FightGame(
      gameMode: _gameMode,
      p1Character: _p1Char,
      p2Character: _p2Char,
      onMatchEnd: (bool p1Won, String name) {
        if (!mounted) return;
        setState(() {
          _resultMsg = p1Won ? '$name WINS!' : '$name WINS!';
          _phase = _ScreenPhase.result;
        });
      },
    );
    setState(() {
      _game = game;
      _phase = _ScreenPhase.fighting;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF04040E),
      body: switch (_phase) {
        _ScreenPhase.modeSelect => _ModeSelectPage(
            onSelect: (GameMode m) => setState(() {
                  _gameMode = m;
                  _selectingP2 = false;
                  _phase = _ScreenPhase.charSelect;
                }),
            onBack: () => Navigator.pop(context),
          ),
        _ScreenPhase.charSelect => _CharSelectPage(
            title: _selectingP2
                ? 'PLAYER 2 — CHOOSE FIGHTER'
                : (_gameMode == GameMode.vsPlayer
                    ? 'PLAYER 1 — CHOOSE FIGHTER'
                    : 'CHOOSE YOUR FIGHTER'),
            p1Selected: _p1Char,
            onSelect: (CharacterData c) {
              if (!_selectingP2) {
                setState(() {
                  _p1Char = c;
                  if (_gameMode == GameMode.vsPlayer) {
                    _selectingP2 = true;
                    _p2Char = CharacterData.all
                        .firstWhere((CharacterData d) => d.id != c.id);
                  } else {
                    // Bot picks different char
                    _p2Char = CharacterData.all
                        .firstWhere((CharacterData d) => d.id != c.id);
                    _startFight();
                  }
                });
              } else {
                setState(() {
                  _p2Char = c;
                  _startFight();
                });
              }
            },
            onBack: () {
              if (_selectingP2) {
                setState(() => _selectingP2 = false);
              } else {
                setState(() => _phase = _ScreenPhase.modeSelect);
              }
            },
          ),
        _ScreenPhase.fighting => _FightView(
            game: _game!,
            gameMode: _gameMode,
          ),
        _ScreenPhase.result => _ResultPage(
            message: _resultMsg,
            onPlayAgain: () => setState(() {
                  _game = null;
                  _selectingP2 = false;
                  _phase = _ScreenPhase.charSelect;
                }),
            onMenu: () => Navigator.pop(context),
          ),
      },
    );
  }
}

enum _ScreenPhase { modeSelect, charSelect, fighting, result }

// ─── Mode Select ──────────────────────────────────────────────────────────

class _ModeSelectPage extends StatelessWidget {
  const _ModeSelectPage({required this.onSelect, required this.onBack});
  final void Function(GameMode) onSelect;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        const _StarBg(),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _GlowText('CHOOSE MODE', 32, Colors.white),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _BigButton(
                    icon: Icons.person,
                    label: 'VS BOT',
                    subtitle: 'Fight the AI',
                    color: const Color(0xFF00CCFF),
                    onTap: () => onSelect(GameMode.vsBot),
                  ),
                  const SizedBox(width: 32),
                  _BigButton(
                    icon: Icons.people,
                    label: 'VS PLAYER',
                    subtitle: 'Local 2-player',
                    color: const Color(0xFFFF6600),
                    onTap: () => onSelect(GameMode.vsPlayer),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              TextButton(
                onPressed: onBack,
                child: const Text('← BACK',
                    style: TextStyle(color: Colors.white54, fontSize: 14)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Character Select ─────────────────────────────────────────────────────

class _CharSelectPage extends StatefulWidget {
  const _CharSelectPage({
    required this.title,
    required this.p1Selected,
    required this.onSelect,
    required this.onBack,
  });
  final String title;
  final CharacterData p1Selected;
  final void Function(CharacterData) onSelect;
  final VoidCallback onBack;

  @override
  State<_CharSelectPage> createState() => _CharSelectPageState();
}

class _CharSelectPageState extends State<_CharSelectPage>
    with SingleTickerProviderStateMixin {
  int _highlighted = 0;
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        const _StarBg(),
        Column(
          children: <Widget>[
            const SizedBox(height: 24),
            _GlowText(widget.title, 20, Colors.white),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(CharacterData.all.length, (int i) {
                final CharacterData c = CharacterData.all[i];
                final bool selected = i == _highlighted;
                return GestureDetector(
                  onTap: () => setState(() => _highlighted = i),
                  child: AnimatedBuilder(
                    animation: _anim,
                    builder: (BuildContext ctx, _) {
                      final double glowR = selected
                          ? (1 + _anim.value * 0.3)
                          : 1.0;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        width: 140,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? c.accentColor
                                : c.accentColor.withOpacity(0.3),
                            width: selected ? 2.5 * glowR : 1.5,
                          ),
                          color: selected
                              ? c.bodyColor.withOpacity(0.9)
                              : const Color(0xFF0A0A18),
                          boxShadow: selected
                              ? <BoxShadow>[
                                  BoxShadow(
                                    color: c.glowColor.withOpacity(0.5 * glowR),
                                    blurRadius: 20 * glowR,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            _FighterPreview(character: c, animate: selected),
                            const SizedBox(height: 12),
                            Text(
                              c.name,
                              style: TextStyle(
                                color: c.accentColor,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              c.description,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    CharacterData.all[_highlighted].accentColor,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                    horizontal: 48, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () =>
                  widget.onSelect(CharacterData.all[_highlighted]),
              child: const Text('SELECT',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 3)),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: widget.onBack,
              child: const Text('← BACK',
                  style: TextStyle(color: Colors.white54, fontSize: 14)),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Fight View ───────────────────────────────────────────────────────────

class _FightView extends StatelessWidget {
  const _FightView({required this.game, required this.gameMode});
  final FightGame game;
  final GameMode gameMode;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints constraints) {
        final double w = constraints.maxWidth;
        final double h = constraints.maxHeight;
        final double gameH = h * 0.62;
        final double ctrlH = h - gameH;

        return Column(
          children: <Widget>[
            SizedBox(
              width: w,
              height: gameH,
              child: GameWidget(game: game),
            ),
            Expanded(
              child: gameMode == GameMode.vsBot
                  ? _P1Controls(game: game)
                  : _VsControls(game: game),
            ),
          ],
        );
      },
    );
  }
}

// ─── P1 Controls (vs bot) ─────────────────────────────────────────────────

class _P1Controls extends StatelessWidget {
  const _P1Controls({required this.game});
  final FightGame game;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF080810),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: <Widget>[
          // D-Pad
          _DPad(
            onLeft: (bool v) => game.p1.inputLeft = v,
            onRight: (bool v) => game.p1.inputRight = v,
            onUp: (bool v) => game.p1.inputJump = v,
            onDown: (bool v) => game.p1.inputCrouch = v,
            color: game.p1.characterData.accentColor,
          ),
          const Spacer(),
          // Block + Jump center
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _CtrlBtn(
                label: 'BLOCK',
                color: const Color(0xFF888888),
                onChanged: (bool v) => game.p1.inputBlock = v,
              ),
            ],
          ),
          const Spacer(),
          // Attack grid
          _AttackGrid(
            onLP: game.p1PunchLight,
            onHP: game.p1PunchHeavy,
            onLK: game.p1KickLight,
            onHK: game.p1KickHeavy,
            color: game.p1.characterData.accentColor,
          ),
        ],
      ),
    );
  }
}

// ─── VS Player Controls ───────────────────────────────────────────────────

class _VsControls extends StatelessWidget {
  const _VsControls({required this.game});
  final FightGame game;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF080810),
      child: Row(
        children: <Widget>[
          // P1 side
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: <Widget>[
                  _DPad(
                    onLeft: (bool v) => game.p1.inputLeft = v,
                    onRight: (bool v) => game.p1.inputRight = v,
                    onUp: (bool v) => game.p1.inputJump = v,
                    onDown: (bool v) => game.p1.inputCrouch = v,
                    color: game.p1.characterData.accentColor,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      _CtrlBtn(
                        label: 'BLK',
                        color: const Color(0xFF888888),
                        onChanged: (bool v) => game.p1.inputBlock = v,
                      ),
                    ],
                  ),
                  const Spacer(),
                  _AttackGrid(
                    onLP: game.p1PunchLight,
                    onHP: game.p1PunchHeavy,
                    onLK: game.p1KickLight,
                    onHK: game.p1KickHeavy,
                    color: game.p1.characterData.accentColor,
                  ),
                ],
              ),
            ),
          ),
          // Divider
          Container(width: 1, color: Colors.white12),
          // P2 side (mirrored)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: <Widget>[
                  _AttackGrid(
                    onLP: game.p2PunchLight,
                    onHP: game.p2PunchHeavy,
                    onLK: game.p2KickLight,
                    onHK: game.p2KickHeavy,
                    color: game.p2.characterData.accentColor,
                  ),
                  const Spacer(),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      _CtrlBtn(
                        label: 'BLK',
                        color: const Color(0xFF888888),
                        onChanged: (bool v) => game.p2.inputBlock = v,
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  _DPad(
                    onLeft: (bool v) => game.p2.inputLeft = v,
                    onRight: (bool v) => game.p2.inputRight = v,
                    onUp: (bool v) => game.p2.inputJump = v,
                    onDown: (bool v) => game.p2.inputCrouch = v,
                    color: game.p2.characterData.accentColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── D-Pad ────────────────────────────────────────────────────────────────

class _DPad extends StatelessWidget {
  const _DPad({
    required this.onLeft,
    required this.onRight,
    required this.onUp,
    required this.onDown,
    required this.color,
  });

  final void Function(bool) onLeft, onRight, onUp, onDown;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // Center fill
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle),
          ),
          // Up
          Positioned(
            top: 0,
            child: _DBtn(
                icon: Icons.keyboard_arrow_up,
                color: color,
                onChanged: onUp),
          ),
          // Down
          Positioned(
            bottom: 0,
            child: _DBtn(
                icon: Icons.keyboard_arrow_down,
                color: color,
                onChanged: onDown),
          ),
          // Left
          Positioned(
            left: 0,
            child: _DBtn(
                icon: Icons.keyboard_arrow_left,
                color: color,
                onChanged: onLeft),
          ),
          // Right
          Positioned(
            right: 0,
            child: _DBtn(
                icon: Icons.keyboard_arrow_right,
                color: color,
                onChanged: onRight),
          ),
        ],
      ),
    );
  }
}

class _DBtn extends StatefulWidget {
  const _DBtn({
    required this.icon,
    required this.color,
    required this.onChanged,
  });
  final IconData icon;
  final Color color;
  final void Function(bool) onChanged;

  @override
  State<_DBtn> createState() => _DBtnState();
}

class _DBtnState extends State<_DBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressed = true);
        widget.onChanged(true);
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onChanged(false);
      },
      onTapCancel: () {
        setState(() => _pressed = false);
        widget.onChanged(false);
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _pressed
              ? widget.color.withOpacity(0.6)
              : widget.color.withOpacity(0.18),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: widget.color.withOpacity(_pressed ? 1.0 : 0.5),
              width: 1.5),
        ),
        child: Icon(widget.icon, color: Colors.white70, size: 20),
      ),
    );
  }
}

// ─── Attack Grid ──────────────────────────────────────────────────────────

class _AttackGrid extends StatelessWidget {
  const _AttackGrid({
    required this.onLP,
    required this.onHP,
    required this.onLK,
    required this.onHK,
    required this.color,
  });
  final VoidCallback onLP, onHP, onLK, onHK;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Row(
          children: <Widget>[
            _AtkBtn(label: 'LP', color: color, onTap: onLP),
            const SizedBox(width: 6),
            _AtkBtn(label: 'HP', color: color.withRed(255), onTap: onHP),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            _AtkBtn(label: 'LK', color: color, onTap: onLK),
            const SizedBox(width: 6),
            _AtkBtn(label: 'HK', color: color.withRed(255), onTap: onHK),
          ],
        ),
      ],
    );
  }
}

class _AtkBtn extends StatefulWidget {
  const _AtkBtn({required this.label, required this.color, required this.onTap});
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_AtkBtn> createState() => _AtkBtnState();
}

class _AtkBtnState extends State<_AtkBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressed = true);
        widget.onTap();
      },
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _pressed
              ? widget.color.withOpacity(0.85)
              : widget.color.withOpacity(0.22),
          border: Border.all(
              color: widget.color.withOpacity(_pressed ? 1.0 : 0.6),
              width: 2),
          boxShadow: _pressed
              ? <BoxShadow>[
                  BoxShadow(
                    color: widget.color.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            widget.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Hold-to-press button (Block) ─────────────────────────────────────────

class _CtrlBtn extends StatefulWidget {
  const _CtrlBtn({required this.label, required this.color, required this.onChanged});
  final String label;
  final Color color;
  final void Function(bool) onChanged;

  @override
  State<_CtrlBtn> createState() => _CtrlBtnState();
}

class _CtrlBtnState extends State<_CtrlBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressed = true);
        widget.onChanged(true);
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onChanged(false);
      },
      onTapCancel: () {
        setState(() => _pressed = false);
        widget.onChanged(false);
      },
      child: Container(
        width: 52,
        height: 30,
        decoration: BoxDecoration(
          color: _pressed
              ? widget.color.withOpacity(0.6)
              : widget.color.withOpacity(0.18),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: widget.color.withOpacity(_pressed ? 1.0 : 0.5),
              width: 1.5),
        ),
        child: Center(
          child: Text(widget.label,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

// ─── Result Page ──────────────────────────────────────────────────────────

class _ResultPage extends StatelessWidget {
  const _ResultPage({
    required this.message,
    required this.onPlayAgain,
    required this.onMenu,
  });
  final String message;
  final VoidCallback onPlayAgain;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        const _StarBg(),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _GlowText(message, 36, const Color(0xFFFFEE44)),
              const SizedBox(height: 48),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00CCFF),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 14),
                ),
                onPressed: onPlayAgain,
                child: const Text('PLAY AGAIN',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2)),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: onMenu,
                child: const Text('MAIN MENU',
                    style: TextStyle(color: Colors.white54, fontSize: 14)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────

class _StarBg extends StatelessWidget {
  const _StarBg();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF04040E), Color(0xFF0A0A20)],
        ),
      ),
    );
  }
}

class _GlowText extends StatelessWidget {
  const _GlowText(this.text, this.size, this.color);
  final String text;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontWeight: FontWeight.w900,
        letterSpacing: 3,
        shadows: <Shadow>[
          Shadow(color: color.withOpacity(0.8), blurRadius: 16),
          const Shadow(color: Color(0xFF000000), blurRadius: 4),
        ],
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(12),
          color: color.withOpacity(0.12),
          boxShadow: <BoxShadow>[
            BoxShadow(color: color.withOpacity(0.3), blurRadius: 16, spreadRadius: 2),
          ],
        ),
        child: Column(
          children: <Widget>[
            Icon(icon, color: color, size: 40),
            const SizedBox(height: 10),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

/// Animated fighter silhouette for the char select screen.
class _FighterPreview extends StatefulWidget {
  const _FighterPreview({required this.character, required this.animate});
  final CharacterData character;
  final bool animate;

  @override
  State<_FighterPreview> createState() => _FighterPreviewState();
}

class _FighterPreviewState extends State<_FighterPreview>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (BuildContext ctx, _) {
        return CustomPaint(
          size: const Size(80, 120),
          painter: _FighterPainter(
            character: widget.character,
            animValue: _ctrl.value,
            active: widget.animate,
          ),
        );
      },
    );
  }
}

class _FighterPainter extends CustomPainter {
  _FighterPainter({
    required this.character,
    required this.animValue,
    required this.active,
  });
  final CharacterData character;
  final double animValue;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height);
    canvas.scale(0.65);

    final double bob = active ? (animValue - 0.5) * 4 : 0;
    final Color body = character.bodyColor;
    final Color accent = character.accentColor;

    // Simple idle pose preview
    final Paint lp = Paint()
      ..color = body
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    final Paint ap = Paint()
      ..color = accent
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    void limb(Offset a, Offset b, double w) {
      canvas.drawLine(a, b, Paint()..color = body..strokeWidth = w..strokeCap = StrokeCap.round);
      canvas.drawLine(a, b, Paint()..color = accent.withOpacity(0.6)..strokeWidth = 1.5..strokeCap = StrokeCap.round..style = PaintingStyle.stroke);
    }

    final double by = bob * 0.3;
    // Legs
    limb(Offset(-8, -82 + by), Offset(-16, -46), 14);
    limb(Offset(-16, -46), Offset(-22, -6), 12);
    limb(Offset(8, -82 + by), Offset(18, -44), 14);
    limb(Offset(18, -44), Offset(26, -4), 12);
    // Body
    final Path torso = Path()
      ..moveTo(-20, -116 + by)..lineTo(10, -116 + by)
      ..lineTo(8, -82 + by)..lineTo(-8, -82 + by)..close();
    canvas.drawPath(torso, lp..style = PaintingStyle.fill);
    canvas.drawPath(torso, ap);
    // Arms
    limb(Offset(-20, -116 + by), Offset(-22, -94 + by), 12);
    limb(Offset(-22, -94 + by), Offset(-12, -110 + by), 10);
    limb(Offset(10, -116 + by), Offset(24, -96 + by), 12);
    limb(Offset(24, -96 + by), Offset(32, -110 + by), 10);
    // Head
    canvas.drawCircle(Offset(-2, -140 + by), 18, lp..strokeWidth = 1..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(-2, -140 + by), 18, ap..strokeWidth = 2);
    // Visor
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(3, -140 + by), width: 18, height: 7),
        const Radius.circular(3),
      ),
      Paint()..color = accent.withOpacity(0.8),
    );
    // Glow
    canvas.drawCircle(
      Offset(-2, -140 + by),
      active ? 22 + animValue * 4 : 20,
      Paint()
        ..color = character.glowColor.withOpacity(active ? 0.25 : 0.1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  @override
  bool shouldRepaint(_FighterPainter old) =>
      old.animValue != animValue || old.active != active;
}
