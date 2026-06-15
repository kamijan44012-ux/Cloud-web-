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

/// A single enemy chicken. One class drives every non-boss type; the behaviour
/// branch is selected by [stats.type] in [update]. This keeps spawning trivial
/// and all the AI in one readable place.
///
/// AI summary:
///  - normal:   drifts down with a gentle sine weave.
///  - fast:     dives straight down, quickly.
///  - armored:  slow tank; flashes when its "armour" absorbs a hit.
///  - laser:    descends to a hover line, strafes, and fires aimed bolts.
///  - kamikaze: accelerates toward the player's last position to ram them.
class EnemyChicken extends PositionComponent
    with CollisionCallbacks, HasGameReference<ChickenHunterGame> {
  EnemyChicken({required Vector2 position, required this.stats})
      : health = stats.maxHealth,
        super(position: position, anchor: Anchor.center, size: Vector2.all(stats.radius * 2));

  final EnemyStats stats;
  double health;

  final Random _rng = Random();
  double _phase = 0;
  double _shootTimer = 0;
  double _hoverTargetY = 0;
  int _strafeDir = 1;
  double _hitFlash = 0;

  bool get isDead => health <= 0;

  @override
  Future<void> onLoad() async {
    _phase = _rng.nextDouble() * pi * 2;
    _hoverTargetY = 120 + _rng.nextDouble() * 160;
    _strafeDir = _rng.nextBool() ? 1 : -1;
    add(CircleHitbox(radius: stats.radius * 0.9, anchor: Anchor.center, position: size / 2));
  }

  @override
  void update(double dt) {
    if (game.isFrozen) {
      _hitFlash = max(0, _hitFlash - dt);
      return; // Time Freeze power-up halts enemy logic.
    }
    _phase += dt;
    _hitFlash = max(0, _hitFlash - dt);

    switch (stats.type) {
      case EnemyType.normal:
        position.y += stats.speed * dt;
        position.x += sin(_phase * 2) * 30 * dt;
        break;
      case EnemyType.fast:
        position.y += stats.speed * dt;
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

    // Despawn if it flies off the bottom (counts as escaped).
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
    // Armoured chickens shrug off a fraction of incoming damage.
    final double effective = stats.type == EnemyType.armored ? amount * 0.6 : amount;
    health -= effective;
    _hitFlash = 0.12;
    AudioService.instance.hit();
    if (isDead) {
      game.onEnemyKilled(this);
      _die();
      return true;
    }
    return false;
  }

  void _die() {
    game.add(Explosion(
      position: position.clone(),
      color: stats.color,
      particleCount: 18,
      maxRadius: stats.radius,
    ));
    AudioService.instance.explosion();
    removeFromParent();
  }

  // ---------------------------------------------------------------------------
  // Cartoon chicken rendering (no sprite assets required).
  // ---------------------------------------------------------------------------
  @override
  void render(Canvas canvas) {
    final double r = stats.radius;
    final Offset c = Offset(r, r);
    final bool flash = _hitFlash > 0;

    // Body.
    final Paint body = Paint()..color = flash ? Colors.white : stats.color;
    canvas.drawCircle(c, r * 0.85, body);

    // Armour plating ring for armored type.
    if (stats.type == EnemyType.armored) {
      canvas.drawCircle(c, r * 0.85, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color(0xFF6E7C90));
    }

    // Comb.
    final Path comb = Path()
      ..moveTo(r * 0.7, r * 0.25)
      ..quadraticBezierTo(r, -r * 0.05, r * 1.3, r * 0.25)
      ..close();
    canvas.drawPath(comb, Paint()..color = Palette.comb);

    // Beak (points down toward the player).
    final Path beak = Path()
      ..moveTo(r * 0.8, r * 1.5)
      ..lineTo(r * 1.2, r * 1.5)
      ..lineTo(r, r * 1.85)
      ..close();
    canvas.drawPath(beak, Paint()..color = Palette.beak);

    // Eyes.
    final Paint white = Paint()..color = Colors.white;
    final Paint pupil = Paint()..color = Colors.black;
    canvas.drawCircle(Offset(r * 0.72, r * 0.95), r * 0.16, white);
    canvas.drawCircle(Offset(r * 1.28, r * 0.95), r * 0.16, white);
    canvas.drawCircle(Offset(r * 0.74, r * 1.0), r * 0.08, pupil);
    canvas.drawCircle(Offset(r * 1.26, r * 1.0), r * 0.08, pupil);

    // Health bar for tougher enemies.
    if (stats.maxHealth > 40 && health < stats.maxHealth) {
      final double w = r * 1.6;
      final double frac = (health / stats.maxHealth).clamp(0.0, 1.0);
      final Rect bg = Rect.fromLTWH(r - w / 2, -8, w, 4);
      canvas.drawRect(bg, Paint()..color = Colors.black54);
      canvas.drawRect(Rect.fromLTWH(r - w / 2, -8, w * frac, 4),
          Paint()..color = Palette.hudGreen);
    }
  }
}
