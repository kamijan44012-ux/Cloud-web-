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

/// The player's spaceship. It is *dragged* by the player (the game forwards the
/// finger position into [targetPosition]); the ship eases toward that point so
/// movement feels smooth rather than teleporting. It auto-fires the equipped
/// weapon on a timer modulated by buffs and ship stats.
class PlayerShip extends PositionComponent
    with CollisionCallbacks, HasGameReference<ChickenHunterGame> {
  PlayerShip({required this.ship, required this.maxHealth})
      : health = maxHealth,
        super(anchor: Anchor.center, size: Vector2(56, 64));

  final ShipData ship;
  final double maxHealth;
  double health;

  Vector2 targetPosition = Vector2.zero();
  double _fireTimer = 0;
  double _thrust = 0;
  double _invuln = 0; // brief i-frames after taking a hit

  bool get isAlive => health > 0;

  @override
  Future<void> onLoad() async {
    position = Vector2(game.size.x / 2, game.size.y * 0.82);
    targetPosition = position.clone();
    add(CircleHitbox(radius: 18, anchor: Anchor.center)
      ..position = size / 2);
  }

  @override
  void update(double dt) {
    if (!isAlive) return;
    _invuln = max(0, _invuln - dt);
    _thrust = (_thrust + dt * 6) % (pi * 2);

    // Smooth follow toward the player's finger, clamped to the screen.
    final Vector2 delta = targetPosition - position;
    position += delta * min(1.0, dt * 12);
    position.x = position.x.clamp(size.x / 2, game.size.x - size.x / 2);
    position.y = position.y.clamp(size.y / 2, game.size.y - size.y / 2);

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

    // Spread based on the ship's gun count.
    final int guns = ship.bulletCount;
    final double spread = (guns - 1) * 10.0;
    for (int i = 0; i < guns; i++) {
      final double offsetX = guns == 1 ? 0 : -spread / 2 + (spread / (guns - 1)) * i;
      game.spawnPlayerBullet(Bullet(
        position: position + Vector2(offsetX, -size.y / 2),
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
      other.takeDamage(99999); // the chicken splatters on contact
    } else if (other is BossChicken) {
      takeDamage(other.stats.contactDamage);
    }
  }

  /// Apply incoming damage, respecting the shield buff and i-frames. Returns
  /// true if the ship was destroyed.
  bool takeDamage(double amount) {
    if (!isAlive || _invuln > 0) return false;
    if (game.buffs.shield) return false; // shield fully absorbs
    health -= amount;
    _invuln = 0.6;
    game.onPlayerDamaged();
    if (health <= 0) {
      health = 0;
      game.add(Explosion(
        position: position.clone(),
        color: ship.color,
        particleCount: 40,
        maxRadius: 60,
        lifetime: 0.9,
      ));
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
    if (_invuln > 0 && (_invuln * 20).floor().isEven) {
      // Blink while invulnerable.
      return;
    }

    // Engine flame.
    final double flicker = 0.6 + sin(_thrust * 3) * 0.4;
    final Path flame = Path()
      ..moveTo(w * 0.4, h * 0.85)
      ..lineTo(w * 0.5, h * (0.95 + flicker * 0.12))
      ..lineTo(w * 0.6, h * 0.85)
      ..close();
    canvas.drawPath(flame, Paint()..color = Palette.hudYellow.withOpacity(0.9));

    // Hull.
    final Path hull = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w * 0.92, h * 0.78)
      ..lineTo(w * 0.5, h * 0.62)
      ..lineTo(w * 0.08, h * 0.78)
      ..close();
    canvas.drawPath(hull, Paint()..color = ship.color);
    canvas.drawPath(hull, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withOpacity(0.85));

    // Cockpit.
    canvas.drawCircle(Offset(w * 0.5, h * 0.34), 7, Paint()..color = Palette.hudBlue);

    // Shield bubble.
    if (game.buffs.shield) {
      canvas.drawCircle(Offset(w / 2, h / 2), w * 0.75, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Palette.hudBlue.withOpacity(0.6 + sin(_thrust * 4) * 0.2));
    }
  }
}
