import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../config/game_config.dart';
import '../../config/palette.dart';

/// A cheap, GPU-friendly parallax starfield drawn in a single component. Stars
/// scroll downward at varied speeds to sell forward motion. Count scales with
/// [GameConfig.starCount] so low-end devices draw fewer.
class StarField extends PositionComponent with HasGameReference {
  StarField({required this.areaSize}) : super(priority: -100);

  final Vector2 areaSize;
  final Random _rng = Random();
  final List<_Star> _stars = <_Star>[];

  @override
  Future<void> onLoad() async {
    for (int i = 0; i < GameConfig.starCount; i++) {
      _stars.add(_spawn(initial: true));
    }
  }

  _Star _spawn({bool initial = false}) {
    final double depth = _rng.nextDouble();
    return _Star(
      pos: Vector2(
        _rng.nextDouble() * areaSize.x,
        initial ? _rng.nextDouble() * areaSize.y : -2,
      ),
      speed: 20 + depth * 110,
      radius: 0.6 + depth * 1.8,
      opacity: 0.25 + depth * 0.6,
    );
  }

  @override
  void update(double dt) {
    for (final _Star s in _stars) {
      s.pos.y += s.speed * dt;
      if (s.pos.y > areaSize.y) {
        s.pos
          ..y = -2
          ..x = _rng.nextDouble() * areaSize.x;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final Paint p = Paint();
    for (final _Star s in _stars) {
      p.color = Colors.white.withOpacity(s.opacity);
      canvas.drawCircle(Offset(s.pos.x, s.pos.y), s.radius, p);
    }
    // Faint nebula wash for depth.
    final Paint neb = Paint()
      ..shader = const RadialGradient(
        colors: <Color>[Palette.nebulaPurple, Colors.transparent],
      ).createShader(Rect.fromCircle(
        center: Offset(areaSize.x * 0.3, areaSize.y * 0.25),
        radius: areaSize.x * 0.6,
      ))
      ..blendMode = BlendMode.screen;
    canvas.drawRect(Rect.fromLTWH(0, 0, areaSize.x, areaSize.y), neb);
  }
}

class _Star {
  _Star({required this.pos, required this.speed, required this.radius, required this.opacity});
  Vector2 pos;
  double speed;
  double radius;
  double opacity;
}
