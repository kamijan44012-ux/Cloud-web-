import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Animated background arena — crowd, lights, floor platform.
class FightArena extends Component {
  FightArena();

  final Random _rng = Random(42);
  double _time = 0;

  late final List<_CrowdDot> _crowd;
  late final List<_Spotlight> _lights;
  late final List<_Particle> _particles;

  static const double _w = 720;
  static const double _h = 340;
  static const double _groundY = 300;
  static const double _floorH = 40;

  @override
  Future<void> onLoad() async {
    _crowd = List.generate(80, (int i) {
      return _CrowdDot(
        x: _rng.nextDouble() * _w,
        y: 20 + _rng.nextDouble() * 70,
        radius: 3 + _rng.nextDouble() * 6,
        color: Color.fromARGB(
          200 + _rng.nextInt(55),
          180 + _rng.nextInt(75),
          120 + _rng.nextInt(100),
          80 + _rng.nextInt(100),
        ),
        phase: _rng.nextDouble() * pi * 2,
      );
    });

    _lights = [
      _Spotlight(x: _w * 0.15, intensity: 1.0, phase: 0),
      _Spotlight(x: _w * 0.5, intensity: 0.8, phase: 1.2),
      _Spotlight(x: _w * 0.85, intensity: 1.0, phase: 2.4),
    ];

    _particles = List.generate(18, (int i) => _Particle(_rng));
  }

  @override
  void update(double dt) {
    _time += dt;
    for (final _Particle p in _particles) {
      p.update(dt, _rng);
    }
  }

  @override
  void render(Canvas canvas) {
    _drawBackground(canvas);
    _drawSpotlights(canvas);
    _drawCrowd(canvas);
    _drawPlatform(canvas);
    _drawParticles(canvas);
  }

  void _drawBackground(Canvas canvas) {
    final Rect full = Rect.fromLTWH(0, 0, _w, _h);
    canvas.drawRect(
      full,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF04040E),
            Color(0xFF0A0A1A),
            Color(0xFF121222),
          ],
          stops: <double>[0.0, 0.5, 1.0],
        ).createShader(full),
    );
  }

  void _drawSpotlights(Canvas canvas) {
    for (final _Spotlight s in _lights) {
      final double pulse =
          0.7 + 0.3 * sin(_time * 0.6 + s.phase);
      final double coneH = _groundY - 10;
      final Offset top = Offset(s.x, 0);
      final Offset bL = Offset(s.x - 80, coneH);
      final Offset bR = Offset(s.x + 80, coneH);

      final Path cone = Path()
        ..moveTo(top.dx, top.dy)
        ..lineTo(bL.dx, bL.dy)
        ..lineTo(bR.dx, bR.dy)
        ..close();

      canvas.drawPath(
        cone,
        Paint()
          ..shader = RadialGradient(
            center: Alignment.topCenter,
            radius: 1.0,
            colors: <Color>[
              Color.fromRGBO(255, 255, 200, 0.14 * pulse * s.intensity),
              const Color(0x00FFFFFF),
            ],
          ).createShader(Rect.fromLTWH(s.x - 80, 0, 160, coneH)),
      );
    }
  }

  void _drawCrowd(Canvas canvas) {
    for (final _CrowdDot d in _crowd) {
      final double bob = sin(_time * 1.4 + d.phase) * 2.5;
      final double waveOpacity = 0.55 + 0.45 * sin(_time * 0.4 + d.x / 60);
      canvas.drawCircle(
        Offset(d.x, d.y + bob),
        d.radius,
        Paint()..color = d.color.withOpacity(d.color.opacity * waveOpacity),
      );
    }
  }

  void _drawPlatform(Canvas canvas) {
    // Main floor platform
    final Rect floor = Rect.fromLTWH(0, _groundY, _w, _floorH);
    canvas.drawRect(
      floor,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF2A2040),
            Color(0xFF1A1030),
          ],
        ).createShader(floor),
    );

    // Glowing top edge
    canvas.drawLine(
      Offset(0, _groundY),
      Offset(_w, _groundY),
      Paint()
        ..color = const Color(0xFF6644AA)
        ..strokeWidth = 2.5,
    );
    // Subtle glow on floor edge
    canvas.drawLine(
      Offset(0, _groundY),
      Offset(_w, _groundY),
      Paint()
        ..color = const Color(0x556644AA)
        ..strokeWidth = 10
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Floor tiles pattern
    for (double x = 0; x < _w; x += 60) {
      canvas.drawLine(
        Offset(x, _groundY),
        Offset(x, _groundY + _floorH),
        Paint()
          ..color = const Color(0x22FFFFFF)
          ..strokeWidth = 1,
      );
    }

    // Reflection effect on floor
    final double reflAlpha = 0.08 + 0.04 * sin(_time * 0.7);
    canvas.drawRect(
      Rect.fromLTWH(0, _groundY + 2, _w, 18),
      Paint()..color = Color.fromRGBO(100, 80, 200, reflAlpha),
    );
  }

  void _drawParticles(Canvas canvas) {
    for (final _Particle p in _particles) {
      canvas.drawCircle(
        Offset(p.x, p.y),
        p.radius,
        Paint()
          ..color = p.color.withOpacity(p.alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }
}

class _CrowdDot {
  _CrowdDot({
    required this.x,
    required this.y,
    required this.radius,
    required this.color,
    required this.phase,
  });
  final double x, y, radius, phase;
  final Color color;
}

class _Spotlight {
  _Spotlight({required this.x, required this.intensity, required this.phase});
  final double x, intensity, phase;
}

class _Particle {
  _Particle(Random rng) {
    _reset(rng);
  }

  late double x, y, vy, radius, alpha;
  late Color color;

  static const List<Color> _colors = <Color>[
    Color(0xFF6644FF),
    Color(0xFF4488FF),
    Color(0xFFFF4488),
    Color(0xFFFFAA22),
  ];

  void _reset(Random rng) {
    x = rng.nextDouble() * 720;
    y = 300 + rng.nextDouble() * 40;
    vy = -(20 + rng.nextDouble() * 60);
    radius = 1 + rng.nextDouble() * 2.5;
    alpha = 0.3 + rng.nextDouble() * 0.5;
    color = _colors[rng.nextInt(_colors.length)];
  }

  void update(double dt, Random rng) {
    y += vy * dt;
    alpha -= dt * 0.6;
    if (alpha <= 0 || y < 80) _reset(rng);
  }
}
