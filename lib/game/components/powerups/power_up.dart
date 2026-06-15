import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../../models/power_up_type.dart';
import '../../chicken_hunter_game.dart';
import '../player_ship.dart';

/// A floating collectible. Drifts downward, bobbing, until the player touches
/// it (or it's pulled in by the Magnet buff). The game resolves the effect on
/// collision; this component is purely the pickup + its look.
class PowerUp extends PositionComponent
    with CollisionCallbacks, HasGameReference<ChickenHunterGame> {
  PowerUp({required Vector2 position, required this.type})
      : info = PowerUpInfo.table[type]!,
        super(position: position, anchor: Anchor.center, size: Vector2.all(40));

  final PowerUpType type;
  final PowerUpInfo info;

  double _t = 0;
  bool magnetTarget = false;

  @override
  Future<void> onLoad() async {
    add(CircleHitbox(radius: 20, anchor: Anchor.center, position: size / 2));
  }

  @override
  void onCollisionStart(Set<Vector2> points, PositionComponent other) {
    super.onCollisionStart(points, other);
    if (other is PlayerShip) {
      game.collectPowerUp(this);
    }
  }

  @override
  void update(double dt) {
    _t += dt;
    if (!magnetTarget) {
      position.y += 55 * dt;
      position.x += sin(_t * 3) * 18 * dt;
    }
    final Vector2? viewSize = findGame()?.size;
    if (viewSize != null && position.y > viewSize.y + 40) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final double pulse = 0.85 + sin(_t * 6) * 0.15;
    final Offset c = Offset(size.x / 2, size.y / 2);
    canvas.drawCircle(c, 20 * pulse,
        Paint()..color = info.color.withOpacity(0.25)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawCircle(c, 16, Paint()..color = info.color);
    canvas.drawCircle(c, 16, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withOpacity(0.9));
    final TextPainter tp = TextPainter(
      text: TextSpan(text: info.glyph, style: const TextStyle(fontSize: 18)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }
}
