import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../../config/game_config.dart';

/// A layered explosion: blinding white flash → expanding fire ring →
/// coloured fire sparks → slow smoke puffs → (optionally) spinning feathers.
/// Much more dramatic than the original — fire-coloured sparks, double
/// shockwave, and a secondary delayed pulse for heavy explosions.
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
  final List<_FireSpark> _sparks = <_FireSpark>[];
  final List<_Ember> _embers = <_Ember>[];
  final List<_Smoke> _smoke = <_Smoke>[];
  final List<_Feather> _feathers = <_Feather>[];
  double _age = 0;

  // Fire colour palette used for sparks
  static const List<Color> _firePalette = <Color>[
    Color(0xFFFFFFFF), // white-hot
    Color(0xFFFFFF88), // yellow
    Color(0xFFFFCC00), // gold
    Color(0xFFFF8800), // orange
    Color(0xFFFF4400), // deep orange
    Color(0xFFFF1100), // red
  ];

  @override
  Future<void> onLoad() async {
    final int count = min(particleCount, GameConfig.particleBudget ~/ 3);

    // Main fire sparks — fast, bright, hot colours
    for (int i = 0; i < count; i++) {
      final double angle = _rng.nextDouble() * pi * 2;
      final double speed = 80 + _rng.nextDouble() * 280;
      final Color c = _firePalette[_rng.nextInt(_firePalette.length)];
      _sparks.add(_FireSpark(
        velocity: Vector2(cos(angle), sin(angle)) * speed,
        radius: 1.8 + _rng.nextDouble() * 4.0,
        color: c,
        hot: _rng.nextDouble() < 0.4,
      ));
    }

    // Secondary slow embers — orange-red, drift and fade
    final int emberCount = (count * 0.6).ceil();
    for (int i = 0; i < emberCount; i++) {
      final double angle = _rng.nextDouble() * pi * 2;
      final double speed = 25 + _rng.nextDouble() * 80;
      _embers.add(_Ember(
        velocity: Vector2(cos(angle), sin(angle)) * speed,
        radius: maxRadius * (0.15 + _rng.nextDouble() * 0.28),
      ));
    }

    // Smoke puffs
    for (int i = 0; i < count ~/ 3; i++) {
      final double angle = _rng.nextDouble() * pi * 2;
      _smoke.add(_Smoke(
        velocity: Vector2(cos(angle), sin(angle)) * (18 + _rng.nextDouble() * 38),
        radius: maxRadius * (0.22 + _rng.nextDouble() * 0.40),
      ));
    }

    if (feathers) {
      for (int i = 0; i < count ~/ 2; i++) {
        final double angle = _rng.nextDouble() * pi * 2;
        _feathers.add(_Feather(
          velocity: Vector2(cos(angle), sin(angle)) * (45 + _rng.nextDouble() * 130),
          spin: (_rng.nextDouble() - 0.5) * 14,
          size: maxRadius * 0.26,
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
    for (final _FireSpark p in _sparks) {
      p.pos += p.velocity * dt;
      p.velocity *= 0.88; // sparks slow down fast (air drag)
    }
    for (final _Ember e in _embers) {
      e.pos += e.velocity * dt;
      e.velocity *= 0.92;
    }
    for (final _Smoke s in _smoke) {
      s.pos += s.velocity * dt;
      s.velocity *= 0.94;
    }
    for (final _Feather f in _feathers) {
      f.pos += f.velocity * dt;
      f.velocity *= 0.93;
      f.velocity.y += 32 * dt;
      f.angle += f.spin * dt;
    }
  }

  @override
  void render(Canvas canvas) {
    final double t = (_age / lifetime).clamp(0.0, 1.0);

    // ── Smoke (behind everything) ──────────────────────────────────────────
    for (final _Smoke s in _smoke) {
      canvas.drawCircle(
        Offset(s.pos.x, s.pos.y),
        s.radius * (0.4 + t * 0.8),
        Paint()..color = const Color(0xFF3A3040).withOpacity((1 - t) * 0.30),
      );
    }

    // ── Slow embers / fire cloud ──────────────────────────────────────────
    for (final _Ember e in _embers) {
      final double a = (1 - t) * 0.40;
      canvas.drawCircle(
        Offset(e.pos.x, e.pos.y),
        e.radius * (0.3 + t * 0.7),
        Paint()
          ..color = Color.lerp(const Color(0xFFFF6600), const Color(0xFFFF1100), t)!
              .withOpacity(a)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, e.radius * 0.5),
      );
    }

    // ── Blinding initial flash ─────────────────────────────────────────────
    if (t < 0.30) {
      final double a = (0.30 - t) / 0.30;
      // White hot core
      canvas.drawCircle(
        Offset.zero,
        maxRadius * (0.55 + t * 1.4),
        Paint()
          ..color = Colors.white.withOpacity(a * 0.95)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      // Yellow-orange outer flash
      canvas.drawCircle(
        Offset.zero,
        maxRadius * (0.35 + t * 1.1),
        Paint()..color = const Color(0xFFFFCC00).withOpacity(a * 0.80),
      );
      canvas.drawCircle(
        Offset.zero,
        maxRadius * (0.25 + t * 0.9),
        Paint()..color = color.withOpacity(a * 0.70),
      );
    }

    // ── Double shockwave rings ─────────────────────────────────────────────
    if (shockwave) {
      if (t < 0.55) {
        canvas.drawCircle(
          Offset.zero,
          maxRadius * t * 2.6,
          Paint()
            ..color = Colors.white.withOpacity((0.55 - t) * 1.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.5 * (1 - t * 1.6).clamp(0.5, 3.5),
        );
      }
      // Second, slightly delayed ring
      if (t > 0.08 && t < 0.65) {
        final double t2 = (t - 0.08) / 0.57;
        canvas.drawCircle(
          Offset.zero,
          maxRadius * t2 * 2.1,
          Paint()
            ..color = const Color(0xFFFF8800).withOpacity((0.65 - t) * 0.9)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5 * (1 - t2).clamp(0.4, 2.5),
        );
      }
    }

    // ── Fire sparks ────────────────────────────────────────────────────────
    for (final _FireSpark p in _sparks) {
      final Color cc = p.hot
          ? Color.lerp(Colors.white, p.color, (t * 2.5).clamp(0, 1))!
          : Color.lerp(p.color, const Color(0xFF660000), t)!;
      final double sparkR = p.radius * (1 - t * 0.55).clamp(0.2, 1.0);
      canvas.drawCircle(
        Offset(p.pos.x, p.pos.y),
        sparkR,
        Paint()
          ..color = cc.withOpacity((1 - t).clamp(0, 1))
          ..maskFilter = p.hot
              ? const MaskFilter.blur(BlurStyle.normal, 1.5)
              : null,
      );
    }

    // ── Feathers ───────────────────────────────────────────────────────────
    for (final _Feather f in _feathers) {
      canvas.save();
      canvas.translate(f.pos.x, f.pos.y);
      canvas.rotate(f.angle);
      final Path feather = Path()
        ..moveTo(0, -f.size)
        ..quadraticBezierTo(f.size * 0.5, 0, 0, f.size)
        ..quadraticBezierTo(-f.size * 0.5, 0, 0, -f.size)
        ..close();
      canvas.drawPath(feather, Paint()..color = color.withOpacity((1 - t) * 0.88));
      canvas.restore();
    }
  }
}

class _FireSpark {
  _FireSpark({required this.velocity, required this.radius, required this.color, required this.hot})
      : pos = Vector2.zero();
  Vector2 pos;
  Vector2 velocity;
  double radius;
  Color color;
  bool hot;
}

class _Ember {
  _Ember({required this.velocity, required this.radius}) : pos = Vector2.zero();
  Vector2 pos;
  Vector2 velocity;
  double radius;
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
