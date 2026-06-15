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

/// Mini-boss and Giant Galactic Boss. Drives a small state machine that cycles
/// through attack patterns and ramps aggression as its health drops (phases).
///
/// Patterns:
///  - spread:  a fan of bolts aimed downward.
///  - radial:  a full ring of bullets ("bullet hell" moment).
///  - aimed:   a fast burst tracking the player.
///  - summon:  (galactic boss only) spawns escort chicks via the game.
class BossChicken extends PositionComponent
    with CollisionCallbacks, HasGameReference<ChickenHunterGame> {
  BossChicken({required Vector2 position, required this.stats})
      : health = stats.maxHealth,
        super(position: position, anchor: Anchor.center, size: Vector2.all(stats.radius * 2));

  final EnemyStats stats;
  double health;

  final Random _rng = Random();
  double _entryY = 0;
  bool _entered = false;
  double _patternTimer = 0;
  int _patternIndex = 0;
  double _bob = 0;
  double _hitFlash = 0;
  int _phase = 1;

  double get healthFraction => (health / stats.maxHealth).clamp(0.0, 1.0);

  @override
  Future<void> onLoad() async {
    _entryY = stats.radius + 60;
    add(CircleHitbox(radius: stats.radius * 0.9, anchor: Anchor.center, position: size / 2));
    AudioService.instance.bossRoar();
  }

  @override
  void update(double dt) {
    if (game.isFrozen) return;
    _hitFlash = max(0, _hitFlash - dt);
    _bob += dt;

    if (!_entered) {
      position.y += stats.speed * dt;
      if (position.y >= _entryY) _entered = true;
      return;
    }

    // Slow horizontal sway.
    position.x = game.size.x / 2 + sin(_bob * 0.8) * (game.size.x * 0.28);
    position.y = _entryY + sin(_bob * 1.4) * 16;

    // Phase escalation: faster patterns as health drops.
    _phase = healthFraction > 0.66 ? 1 : (healthFraction > 0.33 ? 2 : 3);
    final double interval = stats.shootInterval / _phase;

    _patternTimer += dt;
    if (_patternTimer >= interval) {
      _patternTimer = 0;
      _firePattern();
    }
  }

  void _firePattern() {
    final List<void Function()> patterns = <void Function()>[
      _spread,
      _aimed,
      if (stats.type == EnemyType.galacticBoss) _radial,
      if (stats.type == EnemyType.galacticBoss && _phase >= 2) _summon,
    ];
    patterns[_patternIndex % patterns.length]();
    _patternIndex++;
  }

  void _spread() {
    const int count = 5;
    for (int i = 0; i < count; i++) {
      final double angle = pi / 2 + (i - count ~/ 2) * 0.22;
      _shoot(Vector2(cos(angle), sin(angle)) * 240);
    }
  }

  void _radial() {
    const int count = 16;
    for (int i = 0; i < count; i++) {
      final double angle = (i / count) * pi * 2;
      _shoot(Vector2(cos(angle), sin(angle)) * 200);
    }
  }

  void _aimed() {
    final Vector2 dir = (game.playerPosition - position)..normalize();
    for (int i = 0; i < 3; i++) {
      _shoot(dir * (280 + i * 40));
    }
  }

  void _summon() => game.spawnEscort(position.clone());

  void _shoot(Vector2 velocity) {
    game.spawnEnemyBullet(Bullet(
      position: position.clone(),
      velocity: velocity,
      damage: stats.contactDamage * 0.5,
      team: BulletTeam.enemy,
      color: Palette.chickenBoss,
      radius: 7,
    ));
  }

  @override
  void onCollisionStart(Set<Vector2> points, PositionComponent other) {
    super.onCollisionStart(points, other);
    if (other is Bullet && other.team == BulletTeam.player && !other.spent) {
      takeDamage(other.damage);
      if (!other.pierces) {
        other.spent = true;
        other.removeFromParent();
      }
    }
  }

  bool takeDamage(double amount) {
    if (health <= 0) return false;
    health -= amount;
    _hitFlash = 0.08;
    if (health <= 0) {
      _die();
      return true;
    }
    return false;
  }

  void _die() {
    // Big multi-burst death sequence.
    for (int i = 0; i < 6; i++) {
      game.add(Explosion(
        position: position + Vector2(_rng.nextDouble() * 80 - 40, _rng.nextDouble() * 80 - 40),
        color: i.isEven ? Palette.chickenBoss : Palette.hudYellow,
        particleCount: 24,
        maxRadius: stats.radius * 0.8,
        lifetime: 0.7,
      ));
    }
    AudioService.instance.explosion();
    game.onBossKilled(this);
    removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final double r = stats.radius;
    final Offset c = Offset(r, r);
    final bool flash = _hitFlash > 0;

    // Aura.
    canvas.drawCircle(c, r * 1.15,
        Paint()..color = Palette.chickenBoss.withOpacity(0.18)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));

    // Body.
    canvas.drawCircle(c, r * 0.9, Paint()..color = flash ? Colors.white : stats.color);
    canvas.drawCircle(c, r * 0.9, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = Palette.hudYellow);

    // Crown for the galactic boss.
    if (stats.type == EnemyType.galacticBoss) {
      final Path crown = Path()
        ..moveTo(r * 0.45, r * 0.2)
        ..lineTo(r * 0.6, -r * 0.25)
        ..lineTo(r * 0.8, r * 0.1)
        ..lineTo(r, -r * 0.35)
        ..lineTo(r * 1.2, r * 0.1)
        ..lineTo(r * 1.4, -r * 0.25)
        ..lineTo(r * 1.55, r * 0.2)
        ..close();
      canvas.drawPath(crown, Paint()..color = Palette.hudYellow);
    }

    // Angry eyes.
    final Paint white = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(r * 0.7, r), r * 0.18, white);
    canvas.drawCircle(Offset(r * 1.3, r), r * 0.18, white);
    canvas.drawCircle(Offset(r * 0.72, r * 1.05), r * 0.09, Paint()..color = Palette.hudRed);
    canvas.drawCircle(Offset(r * 1.28, r * 1.05), r * 0.09, Paint()..color = Palette.hudRed);

    // Beak.
    final Path beak = Path()
      ..moveTo(r * 0.78, r * 1.55)
      ..lineTo(r * 1.22, r * 1.55)
      ..lineTo(r, r * 1.95)
      ..close();
    canvas.drawPath(beak, Paint()..color = Palette.beak);
  }
}
