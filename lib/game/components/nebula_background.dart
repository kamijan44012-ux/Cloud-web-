import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../sprite_catalog.dart';

/// Real nebula image backdrop that scrolls slowly for parallax depth. Two
/// stacked copies wrap seamlessly. Sits behind the canvas starfield.
class NebulaBackground extends PositionComponent with HasGameReference {
  NebulaBackground() : super(priority: -110);

  double _offset = 0;
  static const double _speed = 12;

  @override
  void update(double dt) {
    _offset = (_offset + _speed * dt) % _tileHeight;
  }

  double get _tileHeight {
    final s = SpriteCatalog.instance.nebula;
    return game.size.x * (s.srcSize.y / s.srcSize.x);
  }

  @override
  void render(Canvas canvas) {
    if (!SpriteCatalog.instance.isLoaded) return;
    final s = SpriteCatalog.instance.nebula;
    final double w = game.size.x;
    final double h = _tileHeight;
    // Draw enough vertical copies to cover the screen plus the scroll offset.
    for (double y = _offset - h; y < game.size.y + h; y += h) {
      s.render(canvas, position: Vector2(0, y), size: Vector2(w, h));
    }
    // Subtle darkening so bright sprites pop.
    canvas.drawRect(Rect.fromLTWH(0, 0, w, game.size.y),
        Paint()..color = Colors.black.withOpacity(0.25));
  }
}
