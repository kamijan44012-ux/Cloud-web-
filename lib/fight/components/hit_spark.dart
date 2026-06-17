import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Explosive hit spark effect spawned on successful hit.
class HitSpark extends PositionComponent {
  HitSpark({required Vector2 position, required this.blocked})
      : super(position: position);

  final bool blocked;

  double _life = 0;
  final Random _rng = Random();
  late final List<_Ray> _rays;

  static const double _maxLife = 0.28;

  @override
  Future<void> onLoad() async {
    final int count = blocked ? 6 : 10;
    _rays = List.generate(count, (_) => _Ray(_rng, blocked));
  }

  @override
  void update(double dt) {
    _life += dt;
    if (_life >= _maxLife) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final double t = _life / _maxLife;
    final double alpha = 1 - t;

    for (final _Ray r in _rays) {
      final double dx = r.dx * r.speed * t * _maxLife;
      final double dy = r.dy * r.speed * t * _maxLife;
      final double fade = (1 - t) * r.opacity;

      // Main ray
      canvas.drawLine(
        Offset(dx * 0.3, dy * 0.3),
        Offset(dx, dy),
        Paint()
          ..color = r.color.withOpacity(fade.clamp(0, 1))
          ..strokeWidth = r.width * (1 - t * 0.6)
          ..strokeCap = StrokeCap.round,
      );
    }

    // Core flash
    if (t < 0.35) {
      final double size = 22 * (1 - t / 0.35);
      canvas.drawCircle(
        Offset.zero,
        size,
        Paint()
          ..color = (blocked ? Colors.cyan : Colors.white)
              .withOpacity(alpha * 0.85)
          ..maskFilter =
              const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawCircle(
        Offset.zero,
        size * 0.45,
        Paint()
          ..color = Colors.white.withOpacity(alpha),
      );
    }
  }
}

class _Ray {
  _Ray(Random rng, bool blocked) {
    final double angle = rng.nextDouble() * pi * 2;
    dx = cos(angle);
    dy = sin(angle);
    speed = 160 + rng.nextDouble() * 120;
    width = 2 + rng.nextDouble() * (blocked ? 2 : 4);
    opacity = 0.6 + rng.nextDouble() * 0.4;
    final List<Color> palette = blocked
        ? const <Color>[Color(0xFF00FFFF), Color(0xFF0088FF), Color(0xFFFFFFFF)]
        : const <Color>[
            Color(0xFFFFFFFF),
            Color(0xFFFFEE44),
            Color(0xFFFF8800),
            Color(0xFFFF4400),
          ];
    color = palette[rng.nextInt(palette.length)];
  }

  late double dx, dy, speed, width, opacity;
  late Color color;
}
