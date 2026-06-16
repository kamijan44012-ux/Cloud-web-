import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';

import '../../sprite_catalog.dart';

enum BulletTeam { player, enemy }

/// A projectile fired by the player or an enemy. Carries its own damage and
/// behaviour flags (AOE, pierce). Renders a real laser sprite rotated to its
/// travel direction with a soft glow. Collision resolution lives in the
/// entities the bullet hits (they read [damage]); the bullet flags itself spent.
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
  late final Sprite _sprite;
  late final double _angle; // rotation so the sprite points along velocity
  final Paint _glow = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

  @override
  Future<void> onLoad() async {
    _sprite = team == BulletTeam.player
        ? SpriteCatalog.instance.laserPlayer
        : SpriteCatalog.instance.laserEnemy;
    // Kenney lasers point up (-Y); rotate to align with the velocity vector.
    _angle = atan2(velocity.y, velocity.x) + pi / 2;
    _glow.color = color.withOpacity(0.5);
    add(CircleHitbox(radius: radius, anchor: Anchor.center, position: size / 2)
      ..collisionType = CollisionType.passive);
  }

  @override
  void update(double dt) {
    position += velocity * dt;
    final Vector2? viewSize = findGame()?.size;
    if (viewSize != null) {
      if (position.y < -50 || position.y > viewSize.y + 50 ||
          position.x < -50 || position.x > viewSize.x + 50) {
        removeFromParent();
      }
    }
    if (spent && !pierces) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final double aspect = _sprite.srcSize.y / _sprite.srcSize.x;
    final double w = radius * 2.0;
    final double h = w * aspect; // lasers are long & thin

    canvas.save();
    canvas.translate(radius, radius);
    canvas.rotate(_angle);
    // Soft glow behind the bolt.
    canvas.drawCircle(Offset.zero, radius * 1.6, _glow);
    _sprite.render(canvas, position: Vector2(-w / 2, -h / 2), size: Vector2(w, h));
    canvas.restore();
  }
}
