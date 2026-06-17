import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';

import '../../sprite_catalog.dart';

enum BulletTeam { player, enemy }

/// A projectile fired by the player or an enemy.
/// Player bullets render as a vivid fire-flame tear-drop.
/// Enemy bullets keep the laser-sprite look with a coloured glow.
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
  late final double _angle;
  final Paint _glow = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

  // flicker phase so each bullet animates independently
  final double _phase = Random().nextDouble() * pi * 2;
  double _age = 0;

  @override
  Future<void> onLoad() async {
    _sprite = team == BulletTeam.player
        ? SpriteCatalog.instance.laserPlayer
        : SpriteCatalog.instance.laserEnemy;
    _angle = atan2(velocity.y, velocity.x) + pi / 2;
    _glow.color = color.withOpacity(0.55);
    add(CircleHitbox(radius: radius, anchor: Anchor.center, position: size / 2)
      ..collisionType = CollisionType.passive);
  }

  @override
  void update(double dt) {
    _age += dt;
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
    canvas.save();
    canvas.translate(radius, radius);
    canvas.rotate(_angle);

    if (team == BulletTeam.player) {
      _renderFire(canvas);
    } else {
      _renderEnemyBolt(canvas);
    }

    canvas.restore();
  }

  void _renderFire(Canvas canvas) {
    final double r = radius;
    // Slight flicker in flame height
    final double flicker = 1.0 + sin(_age * 28 + _phase) * 0.12;
    final double h = r * 5.2 * flicker;

    // --- Outer diffuse orange/red aura ---
    canvas.drawCircle(
      Offset(0, -h * 0.28),
      r * 2.6,
      Paint()
        ..color = const Color(0xFFFF4400).withOpacity(0.22)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 2.2),
    );

    // --- Main flame body (teardrop / tear shape) ---
    final Path flamePath = Path()
      ..moveTo(0, -h)
      ..cubicTo(r * 1.05, -h * 0.52, r * 0.85, -r * 0.15, 0, r * 0.45)
      ..cubicTo(-r * 0.85, -r * 0.15, -r * 1.05, -h * 0.52, 0, -h)
      ..close();

    final Rect bounds = Rect.fromLTWH(-r, -h, r * 2, h + r * 0.45);
    canvas.drawPath(
      flamePath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.white,
            const Color(0xFFFFFF44),
            const Color(0xFFFF9900),
            const Color(0xFFFF3300).withOpacity(0.08),
          ],
          stops: const <double>[0.0, 0.22, 0.68, 1.0],
        ).createShader(bounds),
    );

    // --- Inner hot white core ---
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, -h * 0.22),
        width: r * 0.72,
        height: r * 1.6,
      ),
      Paint()
        ..color = Colors.white.withOpacity(0.92)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
  }

  void _renderEnemyBolt(Canvas canvas) {
    final double aspect = _sprite.srcSize.y / _sprite.srcSize.x;
    final double w = radius * 2.0;
    final double h = w * aspect;
    canvas.drawCircle(Offset.zero, radius * 1.8, _glow);
    _sprite.render(canvas, position: Vector2(-w / 2, -h / 2), size: Vector2(w, h));
  }
}
