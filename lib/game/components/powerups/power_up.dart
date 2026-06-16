import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';

import '../../../models/power_up_type.dart';
import '../../chicken_hunter_game.dart';
import '../../sprite_catalog.dart';
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

    // Soft outer glow.
    canvas.drawCircle(c, 22 * pulse,
        Paint()..color = info.color.withOpacity(0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));

    // Rotating dashed energy ring.
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(_t * 2);
    final Paint ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = info.color.withOpacity(0.9);
    for (int i = 0; i < 8; i++) {
      final double a = i * pi / 4;
      canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: 20),
          a, pi / 8, false, ring);
    }
    canvas.restore();

    // Real power-up icon sprite, gently bobbing in scale.
    final Sprite sp = SpriteCatalog.instance.powerups[type]!;
    final double s = 26 * pulse;
    sp.render(canvas, position: Vector2(c.dx - s / 2, c.dy - s / 2), size: Vector2(s, s));
  }
}
