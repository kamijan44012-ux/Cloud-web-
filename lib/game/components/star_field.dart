import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../config/game_config.dart';
import '../../config/palette.dart';

/// Animated deep-space backdrop: drifting coloured nebula clouds, three
/// parallax star layers (twinkling), and the occasional shooting star. Cheap to
/// draw and density scales with [GameConfig.starCount] for low-end devices.
class StarField extends PositionComponent with HasGameReference {
  StarField({required this.areaSize}) : super(priority: -100);

  final Vector2 areaSize;
  final Random _rng = Random();
  final List<_Star> _stars = <_Star>[];
  final List<_Nebula> _nebulas = <_Nebula>[];
  final List<_Shooting> _shooting = <_Shooting>[];
  double _shootTimer = 3;

  @override
  Future<void> onLoad() async {
    for (int i = 0; i < GameConfig.starCount; i++) {
      _stars.add(_spawnStar(initial: true));
    }
    final List<Color> tints = <Color>[
      Palette.nebulaPurple,
      Palette.nebulaPink,
      Palette.hudBlue,
    ];
    for (int i = 0; i < 4; i++) {
      _nebulas.add(_Nebula(
        pos: Vector2(_rng.nextDouble() * areaSize.x, _rng.nextDouble() * areaSize.y),
        radius: areaSize.x * (0.4 + _rng.nextDouble() * 0.5),
        speed: 6 + _rng.nextDouble() * 12,
        color: tints[i % tints.length],
      ));
    }
  }

  _Star _spawnStar({bool initial = false}) {
    final double depth = _rng.nextDouble();
    return _Star(
      pos: Vector2(
        _rng.nextDouble() * areaSize.x,
        initial ? _rng.nextDouble() * areaSize.y : -2,
      ),
      speed: 18 + depth * 130,
      radius: 0.6 + depth * 1.9,
      baseOpacity: 0.25 + depth * 0.6,
      twinkle: _rng.nextDouble() * pi * 2,
    );
  }

  @override
  void update(double dt) {
    for (final _Nebula n in _nebulas) {
      n.pos.y += n.speed * dt;
      n.phase += dt * 0.3;
      if (n.pos.y - n.radius > areaSize.y) {
        n.pos
          ..y = -n.radius
          ..x = _rng.nextDouble() * areaSize.x;
      }
    }
    for (final _Star s in _stars) {
      s.pos.y += s.speed * dt;
      s.twinkle += dt * 4;
      if (s.pos.y > areaSize.y) {
        s.pos
          ..y = -2
          ..x = _rng.nextDouble() * areaSize.x;
      }
    }
    // Occasional shooting star.
    _shootTimer -= dt;
    if (_shootTimer <= 0) {
      _shootTimer = 4 + _rng.nextDouble() * 6;
      _shooting.add(_Shooting(
        pos: Vector2(_rng.nextDouble() * areaSize.x, -10),
        velocity: Vector2((_rng.nextDouble() - 0.5) * 200, 320 + _rng.nextDouble() * 160),
      ));
    }
    for (final _Shooting s in _shooting) {
      s.pos += s.velocity * dt;
      s.life -= dt;
    }
    _shooting.removeWhere((_Shooting s) => s.life <= 0 || s.pos.y > areaSize.y + 20);
  }

  @override
  void render(Canvas canvas) {
    // Nebula clouds (soft, additive).
    for (final _Nebula n in _nebulas) {
      final double pulse = 0.10 + (sin(n.phase) + 1) * 0.04;
      canvas.drawCircle(
        Offset(n.pos.x, n.pos.y),
        n.radius,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[n.color.withOpacity(pulse), Colors.transparent],
          ).createShader(Rect.fromCircle(center: Offset(n.pos.x, n.pos.y), radius: n.radius))
          ..blendMode = BlendMode.screen,
      );
    }

    // Stars (twinkling).
    final Paint p = Paint();
    for (final _Star s in _stars) {
      final double tw = s.baseOpacity * (0.6 + 0.4 * sin(s.twinkle));
      p.color = Colors.white.withOpacity(tw.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(s.pos.x, s.pos.y), s.radius, p);
    }

    // Shooting stars with a tail.
    for (final _Shooting s in _shooting) {
      final Vector2 tail = s.pos - s.velocity.normalized() * 26;
      canvas.drawLine(
        Offset(tail.x, tail.y),
        Offset(s.pos.x, s.pos.y),
        Paint()
          ..color = Colors.white.withOpacity(s.life.clamp(0.0, 1.0))
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
  }
}

class _Star {
  _Star({required this.pos, required this.speed, required this.radius, required this.baseOpacity, required this.twinkle});
  Vector2 pos;
  double speed;
  double radius;
  double baseOpacity;
  double twinkle;
}

class _Nebula {
  _Nebula({required this.pos, required this.radius, required this.speed, required this.color}) : phase = 0;
  Vector2 pos;
  double radius;
  double speed;
  Color color;
  double phase;
}

class _Shooting {
  _Shooting({required this.pos, required this.velocity}) : life = 1.0;
  Vector2 pos;
  Vector2 velocity;
  double life;
}
