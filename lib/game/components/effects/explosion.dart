import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../../config/game_config.dart';

/// A layered explosion effect: a bright flash, an expanding shockwave ring,
/// fast coloured sparks, slow smoke puffs, and (for chicken deaths) spinning
/// feathers. Self-removes when its lifetime expires. Particle counts respect
/// the global budget so heavy moments stay smooth on low-end hardware.
class Explosion extends PositionComponent {
  Explosion({
    required Vector2 position,
    this.color = const Color(0xFFFFB347),
    this.particleCount = 16,
    this.maxRadius = 40,
    this.lifetime = 0.6,
    this.feathers = false,
    this.shockwave = true,
  }) : super(position: position, anchor: Anchor.center);

  final Color color;
  final int particleCount;
  final double maxRadius;
  final double lifetime;
  final bool feathers;
  final bool shockwave;

  final Random _rng = Random();
  final List<_Spark> _sparks = <_Spark>[];
  final List<_Smoke> _smoke = <_Smoke>[];
  final List<_Feather> _feathers = <_Feather>[];
  double _age = 0;

  @override
  Future<void> onLoad() async {
    final int count = min(particleCount, GameConfig.particleBudget ~/ 3);
    for (int i = 0; i < count; i++) {
      final double angle = _rng.nextDouble() * pi * 2;
      final double speed = 60 + _rng.nextDouble() * 220;
      _sparks.add(_Spark(
        velocity: Vector2(cos(angle), sin(angle)) * speed,
        radius: 1.5 + _rng.nextDouble() * 3.5,
        hot: _rng.nextBool(),
      ));
    }
    for (int i = 0; i < count ~/ 3; i++) {
      final double angle = _rng.nextDouble() * pi * 2;
      _smoke.add(_Smoke(
        velocity: Vector2(cos(angle), sin(angle)) * (20 + _rng.nextDouble() * 40),
        radius: maxRadius * (0.25 + _rng.nextDouble() * 0.35),
      ));
    }
    if (feathers) {
      for (int i = 0; i < count ~/ 2; i++) {
        final double angle = _rng.nextDouble() * pi * 2;
        _feathers.add(_Feather(
          velocity: Vector2(cos(angle), sin(angle)) * (40 + _rng.nextDouble() * 120),
          spin: (_rng.nextDouble() - 0.5) * 12,
          size: maxRadius * 0.25,
        ));
      }
    }
  }

  @override
  void update(double dt) {
    _age += dt;
    if (_age >= lifetime) {
      removeFromParent();
      return;
    }
    for (final _Spark p in _sparks) {
      p.pos += p.velocity * dt;
      p.velocity *= 0.90;
    }
    for (final _Smoke s in _smoke) {
      s.pos += s.velocity * dt;
      s.velocity *= 0.94;
    }
    for (final _Feather f in _feathers) {
      f.pos += f.velocity * dt;
      f.velocity *= 0.93;
      f.velocity.y += 30 * dt; // gravity drift
      f.angle += f.spin * dt;
    }
  }

  @override
  void render(Canvas canvas) {
    final double t = (_age / lifetime).clamp(0.0, 1.0);

    // Smoke (drawn first, behind).
    for (final _Smoke s in _smoke) {
      canvas.drawCircle(
        Offset(s.pos.x, s.pos.y),
        s.radius * (0.5 + t),
        Paint()..color = const Color(0xFF5A5A6A).withOpacity((1 - t) * 0.25),
      );
    }

    // Core flash early on.
    if (t < 0.35) {
      final double a = (0.35 - t) / 0.35;
      canvas.drawCircle(Offset.zero, maxRadius * (0.3 + t * 1.5),
          Paint()..color = Colors.white.withOpacity(a)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      canvas.drawCircle(Offset.zero, maxRadius * (0.2 + t),
          Paint()..color = color.withOpacity(a * 0.9));
    }

    // Shockwave ring.
    if (shockwave && t < 0.6) {
      canvas.drawCircle(
        Offset.zero,
        maxRadius * t * 2.8,
        Paint()
          ..color = Colors.white.withOpacity((0.6 - t) * 1.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - t),
      );
    }

    // Sparks.
    for (final _Spark p in _sparks) {
      final Color cc = p.hot ? Color.lerp(Colors.white, color, t)! : color;
      canvas.drawCircle(Offset(p.pos.x, p.pos.y), p.radius * (1 - t * 0.6),
          Paint()..color = cc.withOpacity(1 - t)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1));
    }

    // Feathers.
    for (final _Feather f in _feathers) {
      canvas.save();
      canvas.translate(f.pos.x, f.pos.y);
      canvas.rotate(f.angle);
      final Path feather = Path()
        ..moveTo(0, -f.size)
        ..quadraticBezierTo(f.size * 0.5, 0, 0, f.size)
        ..quadraticBezierTo(-f.size * 0.5, 0, 0, -f.size)
        ..close();
      canvas.drawPath(feather, Paint()..color = color.withOpacity((1 - t) * 0.9));
      canvas.restore();
    }
  }
}

class _Spark {
  _Spark({required this.velocity, required this.radius, required this.hot}) : pos = Vector2.zero();
  Vector2 pos;
  Vector2 velocity;
  double radius;
  bool hot;
}

class _Smoke {
  _Smoke({required this.velocity, required this.radius}) : pos = Vector2.zero();
  Vector2 pos;
  Vector2 velocity;
  double radius;
}

class _Feather {
  _Feather({required this.velocity, required this.spin, required this.size})
      : pos = Vector2.zero(),
        angle = 0;
  Vector2 pos;
  Vector2 velocity;
  double spin;
  double size;
  double angle;
}
