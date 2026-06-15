import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../../config/palette.dart';
import '../../../models/enemy_type.dart';
import '../../../services/audio_service.dart';
import '../../chicken_hunter_game.dart';
import '../bullets/bullet.dart';
import '../effects/explosion.dart';
import 'chicken_art.dart';

/// A single enemy chicken. One class drives every non-boss type; the behaviour
/// branch is selected by [stats.type] in [update]. Visuals are fully animated
/// (flapping wings, body bob, spawn pop-in, hit squash, eye blinks) and drawn
/// by [ChickenArt] so there are no sprite assets to ship.
///
/// AI summary:
///  - normal:   drifts down with a gentle sine weave.
///  - fast:     dives straight down, quickly.
///  - armored:  slow tank; wears a metal helmet and shrugs off damage.
///  - laser:    descends to a hover line, strafes, and fires aimed bolts.
///  - kamikaze: accelerates toward the player to ram them, fuse sparking.
class EnemyChicken extends PositionComponent
    with CollisionCallbacks, HasGameReference<ChickenHunterGame> {
  EnemyChicken({required Vector2 position, required this.stats})
      : health = stats.maxHealth,
        super(position: position, anchor: Anchor.center, size: Vector2.all(stats.radius * 2));

  final EnemyStats stats;
  double health;

  final Random _rng = Random();
  double _phase = 0;
  double _wing = 0;
  double _shootTimer = 0;
  double _hoverTargetY = 0;
  int _strafeDir = 1;
  double _hitFlash = 0;
  double _spawn = 0; // 0..1 pop-in
  double _blink = 0; // >0 means eyes closed
  double _blinkTimer = 0;

  bool get isDead => health <= 0;

  @override
  Future<void> onLoad() async {
    _phase = _rng.nextDouble() * pi * 2;
    _wing = _rng.nextDouble() * pi * 2;
    _hoverTargetY = 120 + _rng.nextDouble() * 160;
    _strafeDir = _rng.nextBool() ? 1 : -1;
    _blinkTimer = 1.5 + _rng.nextDouble() * 3;
    add(CircleHitbox(radius: stats.radius * 0.85, anchor: Anchor.center, position: size / 2));
  }

  @override
  void update(double dt) {
    // Spawn pop-in always animates, even when frozen, so it never looks stuck.
    _spawn = min(1, _spawn + dt * 5);

    if (game.isFrozen) {
      _hitFlash = max(0, _hitFlash - dt);
      return; // Time Freeze power-up halts enemy logic.
    }

    _phase += dt;
    // Wings beat faster the faster the chicken moves.
    _wing += dt * (8 + stats.speed * 0.03);
    _hitFlash = max(0, _hitFlash - dt);

    // Occasional eye blink.
    _blinkTimer -= dt;
    if (_blinkTimer <= 0) {
      _blink = 0.12;
      _blinkTimer = 2 + _rng.nextDouble() * 3;
    }
    _blink = max(0, _blink - dt);

    switch (stats.type) {
      case EnemyType.normal:
        position.y += stats.speed * dt;
        position.x += sin(_phase * 2) * 30 * dt;
        break;
      case EnemyType.fast:
        position.y += stats.speed * dt;
        position.x += sin(_phase * 6) * 14 * dt;
        break;
      case EnemyType.armored:
        position.y += stats.speed * dt;
        break;
      case EnemyType.laser:
        if (position.y < _hoverTargetY) {
          position.y += stats.speed * dt;
        } else {
          position.x += _strafeDir * stats.speed * 1.6 * dt;
          if (position.x < stats.radius || position.x > game.size.x - stats.radius) {
            _strafeDir = -_strafeDir;
          }
          _maybeShoot(dt);
        }
        break;
      case EnemyType.kamikaze:
        final Vector2 toPlayer = (game.playerPosition - position)..normalize();
        position += toPlayer * stats.speed * dt;
        break;
      default:
        position.y += stats.speed * dt;
    }

    if (position.y > game.size.y + stats.radius * 2) {
      game.onEnemyEscaped(this);
      removeFromParent();
    }
  }

  void _maybeShoot(double dt) {
    _shootTimer += dt;
    if (_shootTimer < stats.shootInterval) return;
    _shootTimer = 0;
    final Vector2 dir = (game.playerPosition - position)..normalize();
    game.spawnEnemyBullet(
      Bullet(
        position: position.clone(),
        velocity: dir * 260,
        damage: stats.contactDamage,
        team: BulletTeam.enemy,
        color: Palette.chickenLaser,
      ),
    );
  }

  @override
  void onCollisionStart(Set<Vector2> points, PositionComponent other) {
    super.onCollisionStart(points, other);
    if (other is Bullet && other.team == BulletTeam.player && !other.spent) {
      takeDamage(other.damage);
      if (other.aoeRadius > 0) {
        game.applyAoeDamage(other.position.clone(), other.aoeRadius, other.damage);
      }
      if (!other.pierces) {
        other.spent = true;
        other.removeFromParent();
      }
    }
  }

  /// Apply damage; returns true if this hit was the kill.
  bool takeDamage(double amount) {
    if (isDead) return false;
    final double effective = stats.type == EnemyType.armored ? amount * 0.6 : amount;
    health -= effective;
    _hitFlash = 0.14;
    AudioService.instance.hit();
    if (isDead) {
      game.onEnemyKilled(this);
      _die();
      return true;
    }
    return false;
  }

  void _die() {
    // Feather burst + pop.
    game.add(Explosion(
      position: position.clone(),
      color: stats.color,
      particleCount: 20,
      maxRadius: stats.radius,
      feathers: true,
    ));
    AudioService.instance.explosion();
    removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final double r = stats.radius;
    final Offset c = Offset(r, r);

    // Spawn pop-in with a little overshoot, plus a hit squash.
    final double pop = _spawn < 1 ? _easeOutBack(_spawn) : 1.0;
    final double squash = 1 - _hitFlash * 0.6;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(pop * (2 - squash), pop * squash);
    canvas.translate(-c.dx, -c.dy);

    ChickenArt.draw(
      canvas,
      center: c,
      radius: r,
      bodyColor: stats.color,
      type: stats.type,
      wing: _wing,
      bob: sin(_phase * 3),
      blink: _blink > 0,
      flash: _hitFlash > 0,
    );
    canvas.restore();

    // Health bar for tougher enemies (outside the squash so it stays steady).
    if (stats.maxHealth > 40 && health < stats.maxHealth) {
      final double w = r * 1.7;
      final double frac = (health / stats.maxHealth).clamp(0.0, 1.0);
      final RRect bg = RRect.fromRectAndRadius(
          Rect.fromLTWH(r - w / 2, -10, w, 5), const Radius.circular(3));
      canvas.drawRRect(bg, Paint()..color = Colors.black54);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(r - w / 2, -10, w * frac, 5), const Radius.circular(3)),
        Paint()..color = Color.lerp(Palette.hudRed, Palette.hudGreen, frac)!,
      );
    }
  }

  double _easeOutBack(double t) {
    const double s = 1.70158;
    final double u = t - 1;
    return 1 + (s + 1) * u * u * u + s * u * u;
  }
}
