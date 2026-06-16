import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../config/palette.dart';

enum PlanetKind { earth, mars, moon, galaxy }

/// A large celestial body that drifts slowly down the screen for parallax depth.
/// Earth, Mars and the Moon are drawn with shaded surfaces, atmosphere glow and
/// craters/landmasses; the galaxy is a glowing spiral. All vector-drawn — no
/// textures. Self-removes once it leaves the bottom of the screen.
class Planet extends PositionComponent with HasGameReference {
  Planet({
    required Vector2 position,
    required this.kind,
    required this.planetRadius,
    this.driftSpeed = 14,
  }) : super(position: position, anchor: Anchor.center, priority: -90);

  final PlanetKind kind;
  final double planetRadius;
  final double driftSpeed;

  double _spin = 0;
  final Random _rng = Random(42);
  late final List<Offset> _craters;
  late final List<Offset> _land;

  @override
  Future<void> onLoad() async {
    _craters = List<Offset>.generate(
        9, (_) => Offset((_rng.nextDouble() * 2 - 1) * 0.7, (_rng.nextDouble() * 2 - 1) * 0.7));
    _land = List<Offset>.generate(
        7, (_) => Offset((_rng.nextDouble() * 2 - 1) * 0.65, (_rng.nextDouble() * 2 - 1) * 0.65));
  }

  @override
  void update(double dt) {
    position.y += driftSpeed * dt;
    _spin += dt * 0.15;
    final double h = game.size.y;
    if (position.y - planetRadius > h + planetRadius) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    switch (kind) {
      case PlanetKind.earth:
        _drawEarth(canvas);
        break;
      case PlanetKind.mars:
        _drawMars(canvas);
        break;
      case PlanetKind.moon:
        _drawMoon(canvas);
        break;
      case PlanetKind.galaxy:
        _drawGalaxy(canvas);
        break;
    }
  }

  void _atmosphere(Canvas canvas, Color glow) {
    canvas.drawCircle(Offset.zero, planetRadius * 1.25,
        Paint()..color = glow.withOpacity(0.25)..maskFilter = MaskFilter.blur(BlurStyle.normal, planetRadius * 0.25));
  }

  void _shade(Canvas canvas) {
    // Terminator shadow for a lit-from-upper-left look.
    canvas.drawCircle(Offset.zero, planetRadius, Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.5, 0.5),
        colors: <Color>[Colors.transparent, Colors.black.withOpacity(0.55)],
        stops: const <double>[0.55, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: planetRadius)));
  }

  void _clip(Canvas canvas, void Function() body) {
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: planetRadius)));
    body();
    canvas.restore();
  }

  void _drawEarth(Canvas canvas) {
    _atmosphere(canvas, Palette.hudBlue);
    // Ocean.
    canvas.drawCircle(Offset.zero, planetRadius, Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.4, -0.4),
        colors: <Color>[Color(0xFF3AA0FF), Color(0xFF12407A)],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: planetRadius)));
    _clip(canvas, () {
      // Landmasses drift with spin.
      final Paint land = Paint()..color = const Color(0xFF3FB55A);
      for (final Offset o in _land) {
        final double x = (o.dx + sin(_spin)) * planetRadius;
        final double y = o.dy * planetRadius;
        canvas.drawCircle(Offset(x % planetRadius, y), planetRadius * 0.28, land);
        canvas.drawCircle(Offset(x % planetRadius + planetRadius * 0.2, y + planetRadius * 0.15),
            planetRadius * 0.18, land);
      }
      // Cloud band.
      final Paint cloud = Paint()..color = Colors.white.withOpacity(0.35);
      canvas.drawOval(
          Rect.fromCenter(center: Offset(sin(_spin) * planetRadius * 0.3, -planetRadius * 0.1),
              width: planetRadius * 2.4, height: planetRadius * 0.5),
          cloud);
    });
    _shade(canvas);
  }

  void _drawMars(Canvas canvas) {
    _atmosphere(canvas, Palette.chickenKamikaze);
    canvas.drawCircle(Offset.zero, planetRadius, Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.4, -0.4),
        colors: <Color>[Color(0xFFE0794B), Color(0xFF8A3A1E)],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: planetRadius)));
    _clip(canvas, () {
      final Paint patch = Paint()..color = const Color(0xFF6E2C16).withOpacity(0.7);
      for (final Offset o in _land) {
        canvas.drawCircle(Offset(o.dx * planetRadius, o.dy * planetRadius), planetRadius * 0.22, patch);
      }
      // Polar ice cap.
      canvas.drawCircle(Offset(0, -planetRadius * 0.8), planetRadius * 0.35,
          Paint()..color = Colors.white.withOpacity(0.8));
    });
    _shade(canvas);
  }

  void _drawMoon(Canvas canvas) {
    canvas.drawCircle(Offset.zero, planetRadius, Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.4, -0.4),
        colors: <Color>[Color(0xFFD8D8E0), Color(0xFF7A7A88)],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: planetRadius)));
    _clip(canvas, () {
      for (final Offset o in _craters) {
        final Offset c = Offset(o.dx * planetRadius, o.dy * planetRadius);
        final double cr = planetRadius * (0.1 + (o.dx.abs() * 0.12));
        canvas.drawCircle(c, cr, Paint()..color = const Color(0xFF5E5E6B).withOpacity(0.6));
        canvas.drawCircle(c.translate(-cr * 0.2, -cr * 0.2), cr * 0.7,
            Paint()..color = const Color(0xFFB7B7C2).withOpacity(0.5));
      }
    });
    _shade(canvas);
  }

  void _drawGalaxy(Canvas canvas) {
    canvas.save();
    canvas.rotate(_spin);
    // Glowing core.
    canvas.drawCircle(Offset.zero, planetRadius * 0.35,
        Paint()..color = Palette.nebulaPink.withOpacity(0.6)..maskFilter = MaskFilter.blur(BlurStyle.normal, planetRadius * 0.3));
    // Spiral arms made of fading dots.
    for (int arm = 0; arm < 2; arm++) {
      for (int i = 0; i < 60; i++) {
        final double t = i / 60.0;
        final double ang = arm * pi + t * pi * 2.2;
        final double rad = t * planetRadius;
        final Offset p = Offset(cos(ang) * rad, sin(ang) * rad * 0.55);
        final Color c = Color.lerp(Palette.hudBlue, Palette.nebulaPink, t)!;
        canvas.drawCircle(p, planetRadius * 0.04 * (1 - t * 0.5),
            Paint()..color = c.withOpacity((1 - t) * 0.8));
      }
    }
    canvas.restore();
  }
}
