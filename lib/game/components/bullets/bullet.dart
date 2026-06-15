import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

enum BulletTeam { player, enemy }

/// A projectile fired by the player or an enemy. Carries its own damage and
/// behaviour flags (AOE, pierce). Renders a glowing core with a fading motion
/// trail so fire feels energetic. Collision resolution lives in the entities
/// the bullet hits (they read [damage]); the bullet just flags itself spent.
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
  final List<Vector2> _trail = <Vector2>[];

  @override
  Future<void> onLoad() async {
    add(CircleHitbox(radius: radius, anchor: Anchor.center, position: size / 2)
      ..collisionType = CollisionType.passive);
  }

  @override
  void update(double dt) {
    // Record trail in world space, capped to a few points.
    _trail.add(position.clone());
    if (_trail.length > 6) _trail.removeAt(0);

    position += velocity * dt;

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
    // Trail (in local space relative to the current position).
    for (int i = 0; i < _trail.length; i++) {
      final double f = (i + 1) / _trail.length;
      final Offset local = Offset(
        radius + (_trail[i].x - position.x),
        radius + (_trail[i].y - position.y),
      );
      canvas.drawCircle(local, radius * f * 0.9,
          Paint()..color = color.withOpacity(0.18 * f));
    }

    final Offset c = Offset(radius, radius);
    // Outer glow.
    canvas.drawCircle(c, radius * 2.0,
        Paint()..color = color.withOpacity(0.35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    // Core.
    canvas.drawCircle(c, radius, Paint()..color = color);
    canvas.drawCircle(c, radius * 0.5, Paint()..color = Colors.white);
  }
}
