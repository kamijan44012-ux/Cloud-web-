import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../fight_data.dart';
import '../fight_game.dart';

/// HUD overlay — health bars, timer, round counter, overlay messages.
class FightHud extends Component with HasGameReference<FightGame> {
  FightHud(this._game);

  final FightGame _game;
  double _msgPulse = 0;

  @override
  void update(double dt) {
    _msgPulse += dt * 4;
  }

  @override
  void render(Canvas canvas) {
    const double w = FightGame.gameWidth;

    _drawHealthBars(canvas, w);
    _drawTimer(canvas, w);
    _drawRoundDots(canvas, w);
    _drawOverlayMessage(canvas, w);
  }

  void _drawHealthBars(Canvas canvas, double w) {
    const double barW = 270;
    const double barH = 18;
    const double barY = 14;
    const double margin = 20;

    // P1 health bar (left, fills left→right)
    final double p1Pct =
        (_game.p1.health / _game.p1.characterData.maxHealth).clamp(0, 1);
    _drawBar(
      canvas,
      left: margin,
      top: barY,
      width: barW,
      height: barH,
      fillFraction: p1Pct,
      fillLeft: true,
      barColor: _healthColor(p1Pct),
      charColor: _game.p1.characterData.accentColor,
      name: _game.p1.characterData.name,
      nameLeft: true,
    );

    // P2 health bar (right, fills right→left)
    final double p2Pct =
        (_game.p2.health / _game.p2.characterData.maxHealth).clamp(0, 1);
    _drawBar(
      canvas,
      left: w - margin - barW,
      top: barY,
      width: barW,
      height: barH,
      fillFraction: p2Pct,
      fillLeft: false,
      barColor: _healthColor(p2Pct),
      charColor: _game.p2.characterData.accentColor,
      name: _game.p2.characterData.name,
      nameLeft: false,
    );
  }

  void _drawBar(
    Canvas canvas, {
    required double left,
    required double top,
    required double width,
    required double height,
    required double fillFraction,
    required bool fillLeft,
    required Color barColor,
    required Color charColor,
    required String name,
    required bool nameLeft,
  }) {
    final Rect bg = Rect.fromLTWH(left, top, width, height);

    // Background
    canvas.drawRRect(
      RRect.fromRectAndRadius(bg, const Radius.circular(4)),
      Paint()..color = const Color(0xAA000000),
    );

    // Health fill
    final double fillW = width * fillFraction;
    final Rect fill = fillLeft
        ? Rect.fromLTWH(left, top, fillW, height)
        : Rect.fromLTWH(left + width - fillW, top, fillW, height);

    if (fillW > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(fill, const Radius.circular(4)),
        Paint()
          ..shader = LinearGradient(
            begin: fillLeft ? Alignment.centerLeft : Alignment.centerRight,
            end: fillLeft ? Alignment.centerRight : Alignment.centerLeft,
            colors: <Color>[
              barColor,
              barColor.withOpacity(0.7),
            ],
          ).createShader(fill),
      );
    }

    // Glow
    canvas.drawRRect(
      RRect.fromRectAndRadius(bg, const Radius.circular(4)),
      Paint()
        ..color = charColor.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Character name
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: name,
        style: TextStyle(
          color: charColor,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          shadows: <Shadow>[
            Shadow(color: charColor.withOpacity(0.8), blurRadius: 6),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(
      canvas,
      Offset(
        nameLeft ? left : left + width - tp.width,
        top - 14,
      ),
    );
  }

  Color _healthColor(double pct) {
    if (pct > 0.5) return const Color(0xFF44DD44);
    if (pct > 0.25) return const Color(0xFFDDAA00);
    return const Color(0xFFDD2200);
  }

  void _drawTimer(Canvas canvas, double w) {
    final int secs = _game.roundTimer.ceil().clamp(0, 99);
    final bool urgent = secs <= 10 && _game.phase == FightPhase.fighting;
    final double pulse = urgent ? (0.8 + 0.2 * sin(_msgPulse)) : 1.0;

    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: secs.toString().padLeft(2, '0'),
        style: TextStyle(
          color: urgent ? const Color(0xFFFF4422) : Colors.white,
          fontSize: 28 * pulse,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
          shadows: <Shadow>[
            Shadow(
              color: (urgent ? Colors.red : Colors.blue).withOpacity(0.8),
              blurRadius: 10,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, Offset((w - tp.width) / 2, 8));
  }

  void _drawRoundDots(Canvas canvas, double w) {
    const double dotR = 7;
    const double dotY = 46;
    const double gap = 20;
    final double cx = w / 2;

    // P1 round wins (left side)
    for (int i = 0; i < 2; i++) {
      final double x = cx - gap - dotR - i * (dotR * 2 + 6);
      final bool won = _game.p1Wins > i;
      canvas.drawCircle(
        Offset(x, dotY),
        dotR,
        Paint()..color = won ? _game.p1.characterData.accentColor : const Color(0x33FFFFFF),
      );
      if (won) {
        canvas.drawCircle(
          Offset(x, dotY),
          dotR,
          Paint()
            ..color = _game.p1.characterData.glowColor.withOpacity(0.6)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
    }

    // P2 round wins (right side)
    for (int i = 0; i < 2; i++) {
      final double x = cx + gap + dotR + i * (dotR * 2 + 6);
      final bool won = _game.p2Wins > i;
      canvas.drawCircle(
        Offset(x, dotY),
        dotR,
        Paint()..color = won ? _game.p2.characterData.accentColor : const Color(0x33FFFFFF),
      );
      if (won) {
        canvas.drawCircle(
          Offset(x, dotY),
          dotR,
          Paint()
            ..color = _game.p2.characterData.glowColor.withOpacity(0.6)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
    }
  }

  void _drawOverlayMessage(Canvas canvas, double w) {
    String? msg;
    double fontSize = 52;
    Color color = Colors.white;

    switch (_game.phase) {
      case FightPhase.countdown:
        if (_game.countdownValue > 0) {
          msg = _game.countdownValue.toString();
          fontSize = 80;
          color = const Color(0xFFFFEE44);
        } else {
          msg = 'FIGHT!';
          fontSize = 68;
          color = const Color(0xFFFF4400);
        }
      case FightPhase.roundPause:
      case FightPhase.gameOver:
        msg = _game.roundMessage;
        fontSize = 46;
        color = _game.p1Wins > _game.p2Wins
            ? _game.p1.characterData.accentColor
            : _game.p2.characterData.accentColor;
      case FightPhase.fighting:
        break;
    }

    if (msg == null) return;

    final double scale = 0.95 + 0.05 * sin(_msgPulse);

    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: msg,
        style: TextStyle(
          color: color,
          fontSize: fontSize * scale,
          fontWeight: FontWeight.w900,
          letterSpacing: 3,
          shadows: <Shadow>[
            Shadow(color: color.withOpacity(0.9), blurRadius: 20),
            const Shadow(color: Color(0xFF000000), blurRadius: 4),
          ],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w);

    tp.paint(canvas, Offset((w - tp.width) / 2, FightGame.gameHeight / 2 - tp.height / 2 - 20));
  }
}
