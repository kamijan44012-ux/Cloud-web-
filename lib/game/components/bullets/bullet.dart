import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

enum BulletTeam { player, enemy }

/// A projectile fired by the player or an enemy. Carries its own damage and
/// behaviour flags (AOE, pierce) so the weapon system can stay data-driven.
/// Collision resolution lives in the entities the bullet hits (chickens read
/// [damage]); the bullet just flags itself spent.
class Bullet extends PositionComponent with CollisionCallbacks {
  Bullet({
    required Vector2 position,
    required this.velocity,
    required this.damage,
    required this.team,
    required this.color,
    this.radius = 5,
    this.aoeRadius = 0,
    this.pierces = false,
  }) : super(position: position, anchor: Anchor.center, size: Vector2.all(radius * 2));

  Vector2 velocity;
  final double damage;
  final BulletTeam team;
  final Color color;
  final double radius;
  final double aoeRadius;
  final bool pierces;

  bool spent = false;

  @override
  Future<void> onLoad() async {
    add(CircleHitbox(radius: radius, anchor: Anchor.center, position: size / 2)
      ..collisionType = CollisionType.passive);
  }

  @override
  void update(double dt) {
    position += velocity * dt;
    // Despawn off-screen (with margin).
    final Vector2? viewSize = findGame()?.size;
    if (viewSize != null) {
      if (position.y < -40 || position.y > viewSize.y + 40 ||
          position.x < -40 || position.x > viewSize.x + 40) {
        removeFromParent();
      }
    }
    if (spent && !pierces) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final Paint glow = Paint()
      ..color = color.withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(Offset(radius, radius), radius * 1.8, glow);
    final Paint core = Paint()..color = color;
    canvas.drawCircle(Offset(radius, radius), radius, core);
    canvas.drawCircle(Offset(radius, radius), radius * 0.5, Paint()..color = Colors.white);
  }
}
