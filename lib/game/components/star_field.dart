import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../config/game_config.dart';

/// Deep-space backdrop — galactic core glow, multi-coloured parallax stars,
/// vivid nebula clouds, hyperspace dust streaks, and dramatic shooting stars.
/// Fully procedural — no external assets needed.
class StarField extends PositionComponent with HasGameReference {
  StarField({required this.areaSize}) : super(priority: -100);

  final Vector2 areaSize;
  final Random _rng = Random();
  final List<_Star> _stars = <_Star>[];
  final List<_Nebula> _nebulas = <_Nebula>[];
  final List<_Shooting> _shooting = <_Shooting>[];
  final List<_DustStreak> _dust = <_DustStreak>[];

  double _shootTimer = 2;
  double _dustTimer = 0;
  double _globalAge = 0;

  // Realistic star colour temperatures (weighted towards common types)
  static const List<Color> _starColors = <Color>[
    Color(0xFFFFFFFF), // white (A-type)   – most common
    Color(0xFFFFFFFF),
    Color(0xFFFFFFFF),
    Color(0xFFEEEEFF), // blue-white (B-type)
    Color(0xFFCCDDFF), // hot blue (O-type)
    Color(0xFFFFF8DC), // yellow-white (F-type)
    Color(0xFFFFEEAA), // yellow (G-type, like our sun)
    Color(0xFFFFCC77), // orange (K-type)
    Color(0xFFFF8866), // red giant (M-type)
    Color(0xFFFF6655), // deep red
  ];

  // Nebula colours — vivid deep-space palette
  static const List<Color> _nebulaColors = <Color>[
    Color(0xFF6A0DAD), // deep violet
    Color(0xFF9B1FCC), // purple
    Color(0xFFCC1FA0), // magenta
    Color(0xFF1F5FCC), // deep blue
    Color(0xFF0D9BD6), // cyan-blue
    Color(0xFF1FCC6A), // emerald (rare, adds variety)
  ];

  @override
  Future<void> onLoad() async {
    final int count = GameConfig.starCount;

    // Three parallax layers: background, mid, foreground
    for (int i = 0; i < count; i++) {
      _stars.add(_spawnStar(initial: true));
    }

    // Six nebula clouds spread across the sky
    for (int i = 0; i < 6; i++) {
      _nebulas.add(_Nebula(
        pos: Vector2(
          _rng.nextDouble() * areaSize.x,
          _rng.nextDouble() * areaSize.y,
        ),
        radius: areaSize.x * (0.35 + _rng.nextDouble() * 0.55),
        speed: 4 + _rng.nextDouble() * 9,
        color: _nebulaColors[i % _nebulaColors.length],
        phaseOffset: _rng.nextDouble() * pi * 2,
      ));
    }

    // Seed initial dust streaks
    for (int i = 0; i < 12; i++) {
      _dust.add(_spawnDust(initial: true));
    }
  }

  _Star _spawnStar({bool initial = false}) {
    final double depth = _rng.nextDouble(); // 0=far, 1=near
    final Color baseColor = _starColors[_rng.nextInt(_starColors.length)];
    return _Star(
      pos: Vector2(
        _rng.nextDouble() * areaSize.x,
        initial ? _rng.nextDouble() * areaSize.y : -4,
      ),
      speed: 12 + depth * 110,
      radius: 0.5 + depth * 2.1,
      baseOpacity: 0.20 + depth * 0.70,
      twinkle: _rng.nextDouble() * pi * 2,
      color: Color.lerp(baseColor, Colors.white, 0.5 + _rng.nextDouble() * 0.5)!,
      twinkleSpeed: 2.5 + _rng.nextDouble() * 4.0,
    );
  }

  _DustStreak _spawnDust({bool initial = false}) {
    return _DustStreak(
      pos: Vector2(
        _rng.nextDouble() * areaSize.x,
        initial ? _rng.nextDouble() * areaSize.y : -8,
      ),
      speed: 30 + _rng.nextDouble() * 80,
      length: 8 + _rng.nextDouble() * 28,
      opacity: 0.04 + _rng.nextDouble() * 0.08,
    );
  }

  @override
  void update(double dt) {
    _globalAge += dt;

    // Nebulas drift down slowly
    for (final _Nebula n in _nebulas) {
      n.pos.y += n.speed * dt;
      n.phase += dt * 0.25;
      if (n.pos.y - n.radius > areaSize.y) {
        n.pos
          ..y = -n.radius
          ..x = _rng.nextDouble() * areaSize.x;
      }
    }

    // Stars scroll down (parallax speed)
    for (final _Star s in _stars) {
      s.pos.y += s.speed * dt;
      s.twinkle += dt * s.twinkleSpeed;
      if (s.pos.y > areaSize.y + 4) {
        final _Star fresh = _spawnStar();
        s
          ..pos = fresh.pos
          ..speed = fresh.speed
          ..radius = fresh.radius
          ..baseOpacity = fresh.baseOpacity
          ..twinkle = fresh.twinkle
          ..color = fresh.color;
      }
    }

    // Dust streaks
    _dustTimer -= dt;
    if (_dustTimer <= 0) {
      _dustTimer = 0.3 + _rng.nextDouble() * 0.5;
      _dust.add(_spawnDust());
    }
    for (final _DustStreak d in _dust) {
      d.pos.y += d.speed * dt;
    }
    _dust.removeWhere((_DustStreak d) => d.pos.y > areaSize.y + 40);

    // Shooting stars
    _shootTimer -= dt;
    if (_shootTimer <= 0) {
      _shootTimer = 3 + _rng.nextDouble() * 5;
      final double angle = -pi * 0.35 + _rng.nextDouble() * pi * 0.7;
      final double spd = 420 + _rng.nextDouble() * 220;
      _shooting.add(_Shooting(
        pos: Vector2(_rng.nextDouble() * areaSize.x, -15),
        velocity: Vector2(sin(angle) * spd, cos(angle) * spd),
        trailLength: 38 + _rng.nextDouble() * 42,
      ));
    }
    for (final _Shooting s in _shooting) {
      s.pos += s.velocity * dt;
      s.life -= dt * 1.1;
    }
    _shooting.removeWhere((_Shooting s) => s.life <= 0 || s.pos.y > areaSize.y + 30);
  }

  @override
  void render(Canvas canvas) {
    _renderGalacticCore(canvas);
    _renderNebulas(canvas);
    _renderDust(canvas);
    _renderStars(canvas);
    _renderShootingStars(canvas);
  }

  // --- Galactic core: a soft, multi-layered elliptical glow ----------------
  void _renderGalacticCore(Canvas canvas) {
    final double cx = areaSize.x * 0.5;
    final double cy = areaSize.y * 0.38;
    final double pulse = 1.0 + sin(_globalAge * 0.18) * 0.04;

    // Outer halo – deep blue/violet
    final double outerW = areaSize.x * 1.20 * pulse;
    final double outerH = areaSize.y * 0.40 * pulse;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: outerW, height: outerH),
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            const Color(0xFF2A0D5C).withOpacity(0.28),
            const Color(0xFF0A0420).withOpacity(0.0),
          ],
        ).createShader(Rect.fromCenter(center: Offset(cx, cy), width: outerW, height: outerH))
        ..blendMode = BlendMode.screen,
    );

    // Mid band – cyan-violet
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: outerW * 0.55, height: outerH * 0.55),
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            const Color(0xFF4B1A9C).withOpacity(0.22),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCenter(center: Offset(cx, cy), width: outerW * 0.55, height: outerH * 0.55))
        ..blendMode = BlendMode.screen,
    );

    // Bright core nucleus
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: outerW * 0.18, height: outerH * 0.20),
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            const Color(0xFFBBA8FF).withOpacity(0.20),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCenter(center: Offset(cx, cy), width: outerW * 0.18, height: outerH * 0.20))
        ..blendMode = BlendMode.screen,
    );
  }

  // --- Nebula clouds --------------------------------------------------------
  void _renderNebulas(Canvas canvas) {
    for (final _Nebula n in _nebulas) {
      final double pulse = 0.08 + (sin(n.phase + n.phaseOffset) + 1) * 0.05;
      final Offset center = Offset(n.pos.x, n.pos.y);
      final Rect bounds = Rect.fromCircle(center: center, radius: n.radius);
      canvas.drawCircle(
        center,
        n.radius,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[n.color.withOpacity(pulse), Colors.transparent],
            stops: const <double>[0.0, 1.0],
          ).createShader(bounds)
          ..blendMode = BlendMode.screen,
      );
    }
  }

  // --- Hyperspace dust streaks ----------------------------------------------
  void _renderDust(Canvas canvas) {
    final Paint p = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 0.8;
    for (final _DustStreak d in _dust) {
      p.color = Colors.white.withOpacity(d.opacity);
      canvas.drawLine(
        Offset(d.pos.x, d.pos.y),
        Offset(d.pos.x, d.pos.y - d.length),
        p,
      );
    }
  }

  // --- Stars ----------------------------------------------------------------
  void _renderStars(Canvas canvas) {
    final Paint p = Paint();
    for (final _Star s in _stars) {
      final double tw = s.baseOpacity * (0.55 + 0.45 * sin(s.twinkle));
      final double alpha = tw.clamp(0.0, 1.0);

      // Bright stars get a soft glow
      if (s.radius > 1.5) {
        p.color = s.color.withOpacity(alpha * 0.30);
        p.maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        canvas.drawCircle(Offset(s.pos.x, s.pos.y), s.radius * 2.2, p);
        p.maskFilter = null;
      }

      p.color = s.color.withOpacity(alpha);
      canvas.drawCircle(Offset(s.pos.x, s.pos.y), s.radius, p);
    }
  }

  // --- Shooting stars with glowing colour trail ----------------------------
  void _renderShootingStars(Canvas canvas) {
    for (final _Shooting s in _shooting) {
      final double alpha = s.life.clamp(0.0, 1.0);
      final Vector2 tip = s.pos;
      final Vector2 tail = s.pos - s.velocity.normalized() * s.trailLength * alpha;

      // Glow aura behind the trail
      canvas.drawLine(
        Offset(tail.x, tail.y),
        Offset(tip.x, tip.y),
        Paint()
          ..color = const Color(0xFFCCEEFF).withOpacity(alpha * 0.25)
          ..strokeWidth = 5.0
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );

      // Sharp bright trail
      canvas.drawLine(
        Offset(tail.x, tail.y),
        Offset(tip.x, tip.y),
        Paint()
          ..color = Colors.white.withOpacity(alpha * 0.95)
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round,
      );

      // Bright head spark
      canvas.drawCircle(
        Offset(tip.x, tip.y),
        2.5 * alpha,
        Paint()..color = const Color(0xFFEEF8FF).withOpacity(alpha),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------

class _Star {
  _Star({
    required this.pos,
    required this.speed,
    required this.radius,
    required this.baseOpacity,
    required this.twinkle,
    required this.color,
    required this.twinkleSpeed,
  });
  Vector2 pos;
  double speed;
  double radius;
  double baseOpacity;
  double twinkle;
  Color color;
  double twinkleSpeed;
}

class _Nebula {
  _Nebula({
    required this.pos,
    required this.radius,
    required this.speed,
    required this.color,
    required this.phaseOffset,
  }) : phase = 0;
  Vector2 pos;
  double radius;
  double speed;
  Color color;
  double phase;
  double phaseOffset;
}

class _Shooting {
  _Shooting({required this.pos, required this.velocity, required this.trailLength})
      : life = 1.0;
  Vector2 pos;
  Vector2 velocity;
  double life;
  double trailLength;
}

class _DustStreak {
  _DustStreak({required this.pos, required this.speed, required this.length, required this.opacity});
  Vector2 pos;
  double speed;
  double length;
  double opacity;
}
