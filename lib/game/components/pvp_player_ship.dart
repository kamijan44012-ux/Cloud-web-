import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';

import '../../models/ship_data.dart';
import '../../models/weapon_data.dart';
import '../../services/audio_service.dart';
import '../pvp_game.dart';
import '../sprite_catalog.dart';
import 'bullets/bullet.dart';

/// The local player's ship in PvP mode. Functionally equivalent to PlayerShip
/// but coupled to [PvpGame] instead of ChickenHunterGame, and without the
/// mission/achievement hooks that only apply to single-player runs.
class PvpPlayerShip extends PositionComponent with HasGameReference<PvpGame> {
  PvpPlayerShip({required this.ship, required this.maxHealth})
      : health = maxHealth,
        super(anchor: Anchor.center, size: Vector2(64, 64));

  final ShipData ship;
  final double maxHealth;
  double health;

  Vector2 targetPosition = Vector2.zero();
  double _fireTimer = 0;
  double _thrust = 0;
  double _bank = 0;
  double _lastX = 0;
  double _muzzle = 0;

  late Sprite _hull;
  late double _hullAspect;

  bool get isAlive => health > 0;

  @override
  Future<void> onLoad() async {
    _hull = SpriteCatalog.instance.ship(ship.id);
    _hullAspect = _hull.srcSize.y / _hull.srcSize.x;
    position = Vector2(game.size.x / 2, game.size.y * 0.82);
    targetPosition = position.clone();
    _lastX = position.x;
  }

  @override
  void update(double dt) {
    if (!isAlive) return;
    _muzzle = max(0, _muzzle - dt);
    _thrust += dt * 12;

    final Vector2 delta = targetPosition - position;
    position += delta * min(1.0, dt * 12);
    // Keep in bottom half of screen
    position.x = position.x.clamp(size.x / 2, game.size.x - size.x / 2);
    position.y = position.y.clamp(game.size.y * 0.55, game.size.y - size.y / 2 - 20);

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
    _fireTimer = stats.fireInterval / ship.fireRateMultiplier;

    final double damage = stats.damage * ship.damageMultiplier;
    final int guns = ship.bulletCount;
    final double spread = (guns - 1) * 11.0;

    for (int i = 0; i < guns; i++) {
      final double offsetX =
          guns == 1 ? 0 : -spread / 2 + (spread / (guns - 1)) * i;
      game.spawnPlayerBullet(Bullet(
        position: position + Vector2(offsetX, -size.y / 2 + 6),
        velocity: Vector2(0, -stats.projectileSpeed),
        damage: damage,
        team: BulletTeam.player,
        color: weapon.color,
        radius: 5,
        pierces: stats.pierces,
      ));
    }
    _muzzle = 0.06;
    AudioService.instance.laser();
  }

  void takeDamage(double amount) {
    if (!isAlive) return;
    health = (health - amount).clamp(0, maxHealth);
    game.onPlayerDamaged();
    game.shake(6);
  }

  @override
  void render(Canvas canvas) {
    final double w = size.x, h = size.y;
    final Offset c = Offset(w / 2, h / 2);
    final double hullW = w;
    final double hullH = hullW * _hullAspect;

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(_bank * 0.2);

    final Sprite thr = (_thrust * 0.6).floor().isEven
        ? SpriteCatalog.instance.thruster0
        : SpriteCatalog.instance.thruster1;
    final double tA = thr.srcSize.y / thr.srcSize.x;
    const double tw = 9;
    final double th = tw * tA;
    for (final double ex in <double>[-hullW * 0.16, hullW * 0.16]) {
      canvas.save();
      canvas.translate(ex, hullH * 0.42);
      canvas.rotate(pi);
      thr.render(canvas, position: Vector2(-tw / 2, -th / 2), size: Vector2(tw, th));
      canvas.restore();
    }

    _hull.render(canvas,
        position: Vector2(-hullW / 2, -hullH / 2), size: Vector2(hullW, hullH));

    if (health / maxHealth < 0.4) {
      SpriteCatalog.instance.playerDamage.render(canvas,
          position: Vector2(-hullW / 2, -hullH / 2), size: Vector2(hullW, hullH));
    }

    if (_muzzle > 0) {
      final double m = 16 * (_muzzle / 0.06);
      SpriteCatalog.instance.sparkYellow.render(canvas,
          position: Vector2(-m / 2, -hullH / 2 - m * 0.4), size: Vector2(m, m));
    }

    canvas.restore();
  }
}
