import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../../config/game_config.dart';

/// A short-lived particle burst used for chicken deaths, hits and boss defeats.
/// Self-removes when its lifetime expires. Particle count respects the global
/// budget so heavy moments stay smooth on low-end hardware.
class Explosion extends PositionComponent {
  Explosion({
    required Vector2 position,
    this.color = const Color(0xFFFFB347),
    this.particleCount = 16,
    this.maxRadius = 40,
    this.lifetime = 0.5,
  }) : super(position: position, anchor: Anchor.center);

  final Color color;
  final int particleCount;
  final double maxRadius;
  final double lifetime;

  final Random _rng = Random();
  final List<_Particle> _particles = <_Particle>[];
  double _age = 0;

  @override
  Future<void> onLoad() async {
    final int count = min(particleCount, GameConfig.particleBudget ~/ 4);
    for (int i = 0; i < count; i++) {
      final double angle = _rng.nextDouble() * pi * 2;
      final double speed = 40 + _rng.nextDouble() * 160;
      _particles.add(_Particle(
        velocity: Vector2(cos(angle), sin(angle)) * speed,
        radius: 2 + _rng.nextDouble() * 4,
      ));
    }
  }

  @override
  void update(double dt) {
    _age += dt;
    if (_age >= lifetime) {
      removeFromParent();
      return;
    }
    for (final _Particle p in _particles) {
      p.pos += p.velocity * dt;
      p.velocity *= 0.92; // drag
    }
  }

  @override
  void render(Canvas canvas) {
    final double t = (_age / lifetime).clamp(0.0, 1.0);
    final Paint paint = Paint()..color = color.withOpacity(1 - t);
    for (final _Particle p in _particles) {
      canvas.drawCircle(Offset(p.pos.x, p.pos.y), p.radius * (1 - t * 0.5), paint);
    }
    // Bright flash ring early in the life.
    if (t < 0.4) {
      final Paint ring = Paint()
        ..color = Colors.white.withOpacity((0.4 - t) * 2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(Offset.zero, maxRadius * t * 2.5, ring);
    }
  }
}

class _Particle {
  _Particle({required this.velocity, required this.radius}) : pos = Vector2.zero();
  Vector2 pos;
  Vector2 velocity;
  double radius;
}
