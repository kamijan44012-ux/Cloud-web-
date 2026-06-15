import 'dart:math';

import 'package:flutter/material.dart';

import '../../config/palette.dart';

/// A lightweight animated starfield used behind every menu so the whole app
/// feels like one continuous space scene (not just the gameplay screen).
class SpaceBackground extends StatefulWidget {
  const SpaceBackground({super.key, required this.child});
  final Widget child;

  @override
  State<SpaceBackground> createState() => _SpaceBackgroundState();
}

class _SpaceBackgroundState extends State<SpaceBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 30))..repeat();
  final List<Offset> _stars = List<Offset>.generate(
    70,
    (_) => Offset(Random().nextDouble(), Random().nextDouble()),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Palette.spaceTop, Palette.spaceBottom],
        ),
      ),
      child: Stack(
        children: <Widget>[
          AnimatedBuilder(
            animation: _c,
            builder: (BuildContext context, _) => CustomPaint(
              painter: _StarPainter(_stars, _c.value),
              size: Size.infinite,
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.stars, this.t);
  final List<Offset> stars;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint();
    for (int i = 0; i < stars.length; i++) {
      final Offset s = stars[i];
      final double y = (s.dy + t * (0.2 + (i % 5) * 0.05)) % 1.0;
      final double r = 0.5 + (i % 3);
      p.color = Colors.white.withOpacity(0.2 + (i % 4) * 0.15);
      canvas.drawCircle(Offset(s.dx * size.width, y * size.height), r, p);
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.t != t;
}
