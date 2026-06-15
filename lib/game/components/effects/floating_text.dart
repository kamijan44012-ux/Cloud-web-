import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// A small number/label that floats up and fades out — used for coin/score
/// pop-ups on kills and for "LEVEL UP!" style call-outs. Self-removes when done.
class FloatingText extends PositionComponent {
  FloatingText({
    required Vector2 position,
    required this.text,
    this.color = const Color(0xFFFFC93C),
    this.fontSize = 16,
    this.lifetime = 0.9,
    this.rise = 50,
  }) : super(position: position, anchor: Anchor.center);

  final String text;
  final Color color;
  final double fontSize;
  final double lifetime;
  final double rise;

  double _age = 0;
  late final TextPainter _tp;

  @override
  Future<void> onLoad() async {
    _tp = TextPainter(textDirection: TextDirection.ltr);
    _layout(1.0);
  }

  void _layout(double opacity) {
    _tp.text = TextSpan(
      text: text,
      style: TextStyle(
        color: color.withOpacity(opacity),
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        shadows: <Shadow>[Shadow(color: Colors.black.withOpacity(opacity * 0.8), blurRadius: 3)],
      ),
    );
    _tp.layout();
  }

  @override
  void update(double dt) {
    _age += dt;
    position.y -= rise * dt;
    if (_age >= lifetime) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final double t = (_age / lifetime).clamp(0.0, 1.0);
    final double scale = t < 0.2 ? (t / 0.2) : 1.0; // small pop-in
    _layout(1 - t);
    canvas.save();
    canvas.scale(scale);
    _tp.paint(canvas, Offset(-_tp.width / 2, -_tp.height / 2));
    canvas.restore();
  }
}
