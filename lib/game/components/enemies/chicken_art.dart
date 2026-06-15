import 'dart:math';

import 'package:flutter/material.dart';

import '../../../config/palette.dart';
import '../../../models/enemy_type.dart';

/// Stateless cartoon-chicken renderer shared by enemies and bosses. Everything
/// is drawn with the [Canvas] API — flapping wings, shaded body, comb, beak,
/// wattle, blinking eyes, little legs, and per-type accessories (helmet,
/// goggles, angry brows + fuse, etc.). No sprite assets required.
class ChickenArt {
  ChickenArt._();

  static Color _shade(Color base, double amount) {
    final HSLColor hsl = HSLColor.fromColor(base);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }

  static void draw(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color bodyColor,
    required EnemyType type,
    required double wing,
    required double bob,
    required bool blink,
    required bool flash,
  }) {
    final double r = radius;
    final Color body = flash ? Colors.white : bodyColor;
    final Color dark = _shade(bodyColor, -0.18);
    final double flap = sin(wing) * 0.6; // wing rotation

    canvas.save();
    canvas.translate(center.dx, center.dy + bob * r * 0.05);

    // --- Tail feathers (behind, top-back) ---
    final Paint tailPaint = Paint()..color = dark;
    for (int i = -1; i <= 1; i++) {
      final Path tail = Path()
        ..moveTo(i * r * 0.2, -r * 0.6)
        ..quadraticBezierTo(i * r * 0.5, -r * 1.25, i * r * 0.15, -r * 1.15)
        ..quadraticBezierTo(i * r * 0.05, -r * 0.8, i * r * 0.2, -r * 0.6)
        ..close();
      canvas.drawPath(tail, tailPaint);
    }

    // --- Wings (flapping) ---
    _wing(canvas, r, dark, side: -1, flap: flap);
    _wing(canvas, r, dark, side: 1, flap: -flap);

    // --- Legs ---
    final Paint legPaint = Paint()
      ..color = Palette.beak
      ..strokeWidth = r * 0.08
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(-r * 0.3, r * 0.8), Offset(-r * 0.35, r * 1.05), legPaint);
    canvas.drawLine(Offset(r * 0.3, r * 0.8), Offset(r * 0.35, r * 1.05), legPaint);

    // --- Body (shaded sphere) ---
    final Rect bodyRect = Rect.fromCenter(center: Offset.zero, width: r * 1.7, height: r * 1.85);
    final Paint bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        colors: <Color>[_shade(body, 0.12), body, dark],
        stops: const <double>[0.0, 0.6, 1.0],
      ).createShader(bodyRect);
    canvas.drawOval(bodyRect, bodyPaint);

    // Belly highlight.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, r * 0.25), width: r * 0.9, height: r * 0.8),
      Paint()..color = _shade(body, 0.18).withOpacity(0.6),
    );

    // --- Comb (red zigzag on top) ---
    final Paint comb = Paint()..color = Palette.comb;
    final Path combPath = Path()..moveTo(-r * 0.35, -r * 0.78);
    for (int i = 0; i < 3; i++) {
      final double x = -r * 0.35 + i * r * 0.35;
      combPath.lineTo(x + r * 0.1, -r * 1.05);
      combPath.lineTo(x + r * 0.35, -r * 0.78);
    }
    combPath.close();
    canvas.drawPath(combPath, comb);

    // --- Beak (pointing down toward the player) ---
    final Path beak = Path()
      ..moveTo(-r * 0.18, r * 0.35)
      ..lineTo(r * 0.18, r * 0.35)
      ..lineTo(0, r * 0.7)
      ..close();
    canvas.drawPath(beak, Paint()..color = Palette.beak);
    canvas.drawPath(beak, Paint()..color = _shade(Palette.beak, -0.12)..style = PaintingStyle.stroke..strokeWidth = 1);
    // Wattle.
    canvas.drawCircle(Offset(0, r * 0.5), r * 0.1, Paint()..color = Palette.comb);

    // --- Eyes ---
    _eyes(canvas, r, blink: blink, type: type);

    // --- Per-type accessories ---
    switch (type) {
      case EnemyType.armored:
        _helmet(canvas, r);
        break;
      case EnemyType.laser:
        _goggles(canvas, r);
        break;
      case EnemyType.kamikaze:
        _angryFuse(canvas, r, wing);
        break;
      case EnemyType.fast:
        _speedLines(canvas, r);
        break;
      default:
        break;
    }

    canvas.restore();
  }

  static void _wing(Canvas canvas, double r, Color color, {required int side, required double flap}) {
    canvas.save();
    canvas.translate(side * r * 0.7, -r * 0.1);
    canvas.rotate(flap * side);
    final Path wing = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(side * r * 0.9, -r * 0.1, side * r * 0.8, r * 0.5)
      ..quadraticBezierTo(side * r * 0.4, r * 0.4, 0, r * 0.3)
      ..close();
    canvas.drawPath(wing, Paint()..color = color);
    canvas.drawPath(
        wing,
        Paint()
          ..color = _shade(color, -0.1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    canvas.restore();
  }

  static void _eyes(Canvas canvas, double r, {required bool blink, required EnemyType type}) {
    final double ex = r * 0.28;
    final double ey = -r * 0.05;
    if (blink) {
      final Paint lid = Paint()
        ..color = Colors.black
        ..strokeWidth = r * 0.05
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(-ex - r * 0.12, ey), Offset(-ex + r * 0.12, ey), lid);
      canvas.drawLine(Offset(ex - r * 0.12, ey), Offset(ex + r * 0.12, ey), lid);
      return;
    }
    final Paint white = Paint()..color = Colors.white;
    final Paint pupil = Paint()..color = Colors.black;
    for (final double sx in <double>[-ex, ex]) {
      canvas.drawCircle(Offset(sx, ey), r * 0.17, white);
      canvas.drawCircle(Offset(sx, ey + r * 0.05), r * 0.09, pupil);
      canvas.drawCircle(Offset(sx + r * 0.03, ey), r * 0.03, white); // glint
    }
  }

  static void _helmet(Canvas canvas, double r) {
    final Paint metal = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[const Color(0xFFB9C4D6), const Color(0xFF6E7C90)],
      ).createShader(Rect.fromCircle(center: Offset(0, -r * 0.3), radius: r));
    final Path helmet = Path()
      ..addArc(Rect.fromCenter(center: Offset(0, -r * 0.05), width: r * 1.7, height: r * 1.7),
          pi, pi);
    canvas.drawPath(helmet, metal);
    // Rivets.
    for (final double a in <double>[-0.7, 0, 0.7]) {
      canvas.drawCircle(Offset(a * r * 0.6, -r * 0.55), r * 0.06, Paint()..color = const Color(0xFF4A5568));
    }
  }

  static void _goggles(Canvas canvas, double r) {
    final Paint frame = Paint()
      ..color = const Color(0xFF222831)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.08;
    final Paint lens = Paint()..color = Palette.hudRed.withOpacity(0.85);
    for (final double sx in <double>[-r * 0.28, r * 0.28]) {
      canvas.drawCircle(Offset(sx, -r * 0.05), r * 0.2, lens);
      canvas.drawCircle(Offset(sx, -r * 0.05), r * 0.2, frame);
    }
    canvas.drawLine(Offset(-r * 0.1, -r * 0.05), Offset(r * 0.1, -r * 0.05), frame);
  }

  static void _angryFuse(Canvas canvas, double r, double wing) {
    // Angry eyebrows.
    final Paint brow = Paint()
      ..color = Colors.black
      ..strokeWidth = r * 0.07
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(-r * 0.45, -r * 0.32), Offset(-r * 0.12, -r * 0.18), brow);
    canvas.drawLine(Offset(r * 0.45, -r * 0.32), Offset(r * 0.12, -r * 0.18), brow);
    // Fuse with a sparking tip.
    final Paint fuse = Paint()
      ..color = const Color(0xFF5A3A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.06;
    final Path f = Path()
      ..moveTo(0, -r * 0.85)
      ..quadraticBezierTo(r * 0.3, -r * 1.2, r * 0.15, -r * 1.35);
    canvas.drawPath(f, fuse);
    final double spark = 0.7 + (sin(wing * 3) + 1) * 0.3;
    canvas.drawCircle(Offset(r * 0.15, -r * 1.35), r * 0.12 * spark,
        Paint()..color = Palette.hudYellow..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
  }

  static void _speedLines(Canvas canvas, double r) {
    final Paint p = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = r * 0.05
      ..strokeCap = StrokeCap.round;
    for (final double y in <double>[-r * 0.3, 0, r * 0.3]) {
      canvas.drawLine(Offset(-r * 1.2, y), Offset(-r * 0.85, y), p);
    }
  }
}
