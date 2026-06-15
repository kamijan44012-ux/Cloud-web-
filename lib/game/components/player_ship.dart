import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../config/palette.dart';
import '../../models/ship_data.dart';
import '../../models/weapon_data.dart';
import '../../services/audio_service.dart';
import '../chicken_hunter_game.dart';
import 'bullets/bullet.dart';
import 'effects/explosion.dart';
import 'enemies/boss_chicken.dart';
import 'enemies/enemy_chicken.dart';

/// The player's spaceship. Dragged by the player (the game forwards the finger
/// position into [targetPosition]); the ship eases toward that point, banks
/// into turns, and fires the equipped weapon automatically. Rendered with a
/// shaded hull, glowing cockpit, twin animated thrusters and a shield bubble.
class PlayerShip extends PositionComponent
    with CollisionCallbacks, HasGameReference<ChickenHunterGame> {
  PlayerShip({required this.ship, required this.maxHealth})
      : health = maxHealth,
        super(anchor: Anchor.center, size: Vector2(60, 70));

  final ShipData ship;
  final double maxHealth;
  double health;

  Vector2 targetPosition = Vector2.zero();
  double _fireTimer = 0;
  double _thrust = 0;
  double _invuln = 0;
  double _bank = 0; // -1..1 visual roll
  double _lastX = 0;

  bool get isAlive => health > 0;

  @override
  Future<void> onLoad() async {
    position = Vector2(game.size.x / 2, game.size.y * 0.82);
    targetPosition = position.clone();
    _lastX = position.x;
    add(CircleHitbox(radius: 18, anchor: Anchor.center)..position = size / 2);
  }

  @override
  void update(double dt) {
    if (!isAlive) return;
    _invuln = max(0, _invuln - dt);
    _thrust += dt * 12;

    final Vector2 delta = targetPosition - position;
    position += delta * min(1.0, dt * 12);
    position.x = position.x.clamp(size.x / 2, game.size.x - size.x / 2);
    position.y = position.y.clamp(size.y / 2, game.size.y - size.y / 2);

    // Bank toward horizontal movement, easing back to level.
    final double vx = (position.x - _lastX) / max(dt, 0.0001);
    _lastX = position.x;
    final double targetBank = (vx / 400).clamp(-1.0, 1.0);
    _bank += (targetBank - _bank) * min(1.0, dt * 8);

    _handleFiring(dt);
  }

  void _handleFiring(double dt) {
    _fireTimer -= dt;
    if (_fireTimer > 0) return;

    final WeaponData weapon = WeaponData.table[game.equippedWeapon]!;
    final WeaponStats stats = weapon.statsAtLevel(game.weaponLevel);

    double interval = stats.fireInterval / ship.fireRateMultiplier;
    if (game.buffs.rapidFire) interval *= 0.45;
    _fireTimer = interval;

    double damage = stats.damage * ship.damageMultiplier;
    if (game.buffs.doubleDamage) damage *= 2;

    final int guns = ship.bulletCount;
    final double spread = (guns - 1) * 11.0;
    for (int i = 0; i < guns; i++) {
      final double offsetX = guns == 1 ? 0 : -spread / 2 + (spread / (guns - 1)) * i;
      game.spawnPlayerBullet(Bullet(
        position: position + Vector2(offsetX, -size.y / 2 + 6),
        velocity: Vector2(0, -stats.projectileSpeed),
        damage: damage,
        team: BulletTeam.player,
        color: weapon.color,
        radius: weapon.type == WeaponType.plasma ? 8 : 5,
        aoeRadius: stats.aoeRadius,
        pierces: stats.pierces,
      ));
    }
    AudioService.instance.laser();
  }

  @override
  void onCollisionStart(Set<Vector2> points, PositionComponent other) {
    super.onCollisionStart(points, other);
    if (!isAlive) return;
    if (other is Bullet && other.team == BulletTeam.enemy) {
      takeDamage(other.damage);
      other.removeFromParent();
    } else if (other is EnemyChicken) {
      takeDamage(other.stats.contactDamage);
      other.takeDamage(99999);
    } else if (other is BossChicken) {
      takeDamage(other.stats.contactDamage);
    }
  }

  bool takeDamage(double amount) {
    if (!isAlive || _invuln > 0) return false;
    if (game.buffs.shield) return false;
    health -= amount;
    _invuln = 0.6;
    game.onPlayerDamaged();
    game.shake(6);
    if (health <= 0) {
      health = 0;
      game.add(Explosion(
        position: position.clone(),
        color: ship.color,
        particleCount: 48,
        maxRadius: 70,
        lifetime: 1.0,
      ));
      game.shake(16);
      AudioService.instance.explosion();
      return true;
    }
    return false;
  }

  void heal(double amount) => health = (health + amount).clamp(0, maxHealth);

  void revive() {
    health = maxHealth;
    _invuln = 2.0;
  }

  @override
  void render(Canvas canvas) {
    final double w = size.x, h = size.y;
    final Offset c = Offset(w / 2, h / 2);
    if (_invuln > 0 && (_invuln * 20).floor().isEven) return; // blink

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(_bank * 0.22); // bank into turns
    canvas.translate(-c.dx, -c.dy);

    // --- Twin engine flames ---
    final double flick = 0.55 + sin(_thrust) * 0.25 + Random().nextDouble() * 0.1;
    for (final double ex in <double>[w * 0.36, w * 0.64]) {
      final Path flame = Path()
        ..moveTo(ex - w * 0.06, h * 0.8)
        ..lineTo(ex, h * (0.92 + flick * 0.18))
        ..lineTo(ex + w * 0.06, h * 0.8)
        ..close();
      canvas.drawPath(flame, Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Palette.hudYellow, Palette.hudRed, Colors.transparent],
        ).createShader(Rect.fromLTWH(ex - w * 0.06, h * 0.8, w * 0.12, h * 0.3)));
      canvas.drawCircle(Offset(ex, h * 0.82), w * 0.07,
          Paint()..color = Palette.hudBlue.withOpacity(0.6)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    }

    // --- Wings (under hull) ---
    final Paint wingPaint = Paint()..color = HSLColor.fromColor(ship.color).withLightness(0.35).toColor();
    final Path wings = Path()
      ..moveTo(w * 0.5, h * 0.45)
      ..lineTo(w * 0.02, h * 0.82)
      ..lineTo(w * 0.2, h * 0.6)
      ..lineTo(w * 0.5, h * 0.55)
      ..lineTo(w * 0.8, h * 0.6)
      ..lineTo(w * 0.98, h * 0.82)
      ..close();
    canvas.drawPath(wings, wingPaint);

    // --- Main hull (shaded) ---
    final Path hull = Path()
      ..moveTo(w * 0.5, h * 0.02)
      ..cubicTo(w * 0.78, h * 0.2, w * 0.85, h * 0.6, w * 0.66, h * 0.82)
      ..lineTo(w * 0.34, h * 0.82)
      ..cubicTo(w * 0.15, h * 0.6, w * 0.22, h * 0.2, w * 0.5, h * 0.02)
      ..close();
    canvas.drawPath(hull, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          HSLColor.fromColor(ship.color).withLightness(0.7).toColor(),
          ship.color,
          HSLColor.fromColor(ship.color).withLightness(0.3).toColor(),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h)));
    canvas.drawPath(hull, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withOpacity(0.8));

    // Hull racing stripe.
    canvas.drawLine(Offset(w * 0.5, h * 0.1), Offset(w * 0.5, h * 0.78),
        Paint()..color = Colors.white.withOpacity(0.4)..strokeWidth = 2);

    // --- Cockpit (glowing) ---
    canvas.drawCircle(Offset(w * 0.5, h * 0.32), 9,
        Paint()..color = Palette.hudBlue.withOpacity(0.5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    canvas.drawCircle(Offset(w * 0.5, h * 0.32), 7, Paint()
      ..shader = const RadialGradient(colors: <Color>[Colors.white, Palette.hudBlue])
          .createShader(Rect.fromCircle(center: Offset(w * 0.5, h * 0.32), radius: 7)));

    canvas.restore();

    // --- Shield bubble (outside the bank transform) ---
    if (game.buffs.shield) {
      final double pulse = 0.5 + sin(_thrust * 0.6) * 0.2;
      canvas.drawCircle(c, w * 0.78, Paint()
        ..color = Palette.hudBlue.withOpacity(pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3);
      canvas.drawCircle(c, w * 0.78, Paint()
        ..color = Palette.hudBlue.withOpacity(0.12));
    }
  }
}
