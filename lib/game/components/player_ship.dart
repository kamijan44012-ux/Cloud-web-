import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';

import '../../models/ship_data.dart';
import '../../models/weapon_data.dart';
import '../../services/audio_service.dart';
import '../chicken_hunter_game.dart';
import '../sprite_catalog.dart';
import 'bullets/bullet.dart';
import 'effects/explosion.dart';
import 'enemies/boss_chicken.dart';
import 'enemies/enemy_chicken.dart';

/// The player's spaceship. Dragged by the player (the game forwards the finger
/// position into [targetPosition]); the ship eases toward that point, banks
/// into turns, and fires the equipped weapon automatically. Rendered from a
/// real ship sprite with animated thrusters, a muzzle flash, a damage overlay
/// when low on health, and a shield-bubble sprite.
class PlayerShip extends PositionComponent
    with CollisionCallbacks, HasGameReference<ChickenHunterGame> {
  PlayerShip({required this.ship, required this.maxHealth})
      : health = maxHealth,
        super(anchor: Anchor.center, size: Vector2(64, 64));

  final ShipData ship;
  final double maxHealth;
  double health;

  Vector2 targetPosition = Vector2.zero();
  double _fireTimer = 0;
  double _thrust = 0;
  double _invuln = 0;
  double _bank = 0; // -1..1 visual roll
  double _lastX = 0;
  double _muzzle = 0; // muzzle-flash timer

  late final Sprite _hull;
  late final double _hullAspect;

  bool get isAlive => health > 0;

  @override
  Future<void> onLoad() async {
    _hull = SpriteCatalog.instance.ship(ship.id);
    _hullAspect = _hull.srcSize.y / _hull.srcSize.x;
    position = Vector2(game.size.x / 2, game.size.y * 0.82);
    targetPosition = position.clone();
    _lastX = position.x;
    add(CircleHitbox(radius: 18, anchor: Anchor.center)..position = size / 2);
  }

  @override
  void update(double dt) {
    if (!isAlive) return;
    _invuln = max(0, _invuln - dt);
    _muzzle = max(0, _muzzle - dt);
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
    _muzzle = 0.06;
    game.shake(1.5);
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

    final double hullW = w;
    final double hullH = hullW * _hullAspect;

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(_bank * 0.2); // bank into turns

    // --- Engine thrusters (animated frames, pointing back/down) ---
    final Sprite thr = (_thrust * 0.6).floor().isEven
        ? SpriteCatalog.instance.thruster0
        : SpriteCatalog.instance.thruster1;
    final double tA = thr.srcSize.y / thr.srcSize.x;
    const double tw = 9;
    final double th = tw * tA;
    for (final double ex in <double>[-hullW * 0.16, hullW * 0.16]) {
      canvas.save();
      canvas.translate(ex, hullH * 0.42);
      canvas.rotate(pi); // flame points downward behind the ship
      thr.render(canvas, position: Vector2(-tw / 2, -th / 2), size: Vector2(tw, th));
      canvas.restore();
    }

    // --- Hull sprite ---
    _hull.render(canvas, position: Vector2(-hullW / 2, -hullH / 2), size: Vector2(hullW, hullH));

    // Damage overlay when badly hurt.
    if (health / maxHealth < 0.4) {
      SpriteCatalog.instance.playerDamage.render(canvas,
          position: Vector2(-hullW / 2, -hullH / 2), size: Vector2(hullW, hullH));
    }

    // Muzzle flash at the nose.
    if (_muzzle > 0) {
      final double m = 16 * (_muzzle / 0.06);
      SpriteCatalog.instance.sparkYellow.render(canvas,
          position: Vector2(-m / 2, -hullH / 2 - m * 0.4), size: Vector2(m, m));
    }

    canvas.restore();

    // --- Shield bubble sprite (outside the bank transform) ---
    if (game.buffs.shield) {
      final double pulse = 1.0 + sin(_thrust * 0.6) * 0.06;
      final double sd = w * 1.5 * pulse;
      SpriteCatalog.instance.shield.render(canvas,
          position: Vector2(c.dx - sd / 2, c.dy - sd / 2), size: Vector2(sd, sd));
    }
  }
}
