import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../../config/palette.dart';

/// A full-screen "jump to lightspeed" effect played between waves: stars stretch
/// into long streaks rushing downward, a bright flash at the peak, then it
/// fades. Purely cosmetic and self-removing.
class Hyperspace extends PositionComponent with HasGameReference {
  Hyperspace({this.lifetime = 1.4}) : super(priority: 60);

  final double lifetime;
  double _age = 0;
  final Random _rng = Random();
  final List<_Streak> _streaks = <_Streak>[];

  @override
  Future<void> onLoad() async {
    final Vector2 s = game.size;
    for (int i = 0; i < 90; i++) {
      _streaks.add(_Streak(
        x: _rng.nextDouble() * s.x,
        y: _rng.nextDouble() * s.y,
        speed: 600 + _rng.nextDouble() * 1400,
        len: 20 + _rng.nextDouble() * 60,
        color: <Color>[Colors.white, Palette.hudBlue, Palette.nebulaPink][_rng.nextInt(3)],
      ));
    }
  }

  /// 0..1..0 intensity envelope.
  double get _intensity {
    final double t = _age / lifetime;
    if (t < 0.25) return t / 0.25;
    if (t > 0.7) return (1 - t) / 0.3;
    return 1.0;
  }

  @override
  void update(double dt) {
    _age += dt;
    if (_age >= lifetime) {
      removeFromParent();
      return;
    }
    final double k = _intensity;
    final double h = game.size.y;
    for (final _Streak s in _streaks) {
      s.y += s.speed * k * dt;
      if (s.y > h + s.len) s.y = -s.len;
    }
  }

  @override
  void render(Canvas canvas) {
    final double k = _intensity;
    final Vector2 size = game.size;

    // Radial speed-blur vignette.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = Palette.spaceBottom.withOpacity(0.35 * k),
    );

    for (final _Streak s in _streaks) {
      final double len = s.len * (0.5 + k * 2.5);
      canvas.drawLine(
        Offset(s.x, s.y),
        Offset(s.x, s.y + len),
        Paint()
          ..color = s.color.withOpacity(0.7 * k)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }

    // Central flash at the peak of the jump.
    if (k > 0.85) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y),
          Paint()..color = Colors.white.withOpacity((k - 0.85) * 4));
    }
  }
}

class _Streak {
  _Streak({required this.x, required this.y, required this.speed, required this.len, required this.color});
  double x;
  double y;
  double speed;
  double len;
  Color color;
}
