import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';

import '../../../config/palette.dart';
import '../../../models/enemy_type.dart';
import '../../../services/audio_service.dart';
import '../../chicken_hunter_game.dart';
import '../../sprite_catalog.dart';
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
  double _wing = 0;
  double _hitFlash = 0;
  double _telegraph = 0; // glows just before firing
  final Paint _flashPaint = Paint()
    ..colorFilter = const ColorFilter.mode(Colors.white, BlendMode.srcATop);
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
    _telegraph = max(0, _telegraph - dt);
    _bob += dt;
    _wing += dt * 5;

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
    // Telegraph (glow) in the last 0.3s before a volley.
    if (interval - _patternTimer < 0.3) _telegraph = 1;
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
    game.shake(3);
    if (health <= 0) {
      _die();
      return true;
    }
    return false;
  }

  void _die() {
    // Big multi-burst death sequence: several sprite blasts + particle bursts.
    for (int i = 0; i < 5; i++) {
      final Vector2 at = position + Vector2(_rng.nextDouble() * 90 - 45, _rng.nextDouble() * 90 - 45);
      game.add(SpriteAnimationComponent(
        animation: SpriteCatalog.instance.explosion,
        size: Vector2.all(stats.radius * (1.4 + _rng.nextDouble())),
        anchor: Anchor.center,
        position: at,
        removeOnFinish: true,
      ));
      game.add(Explosion(
        position: at,
        color: i.isEven ? Palette.chickenBoss : Palette.hudYellow,
        particleCount: 18,
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

    // Pulsing menace aura, brighter when telegraphing an attack.
    final double auraPulse = 0.18 + (sin(_bob * 4) + 1) * 0.06 + _telegraph * 0.35;
    canvas.drawCircle(c, r * (1.25 + _telegraph * 0.15),
        Paint()
          ..color = Palette.chickenBoss.withOpacity(auraPulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));

    // The boss is a giant alien dreadnought sprite that wobbles menacingly.
    final Sprite sp = SpriteCatalog.instance.enemies[stats.type]!;
    final double aspect = sp.srcSize.y / sp.srcSize.x;
    final double bw = r * 2.0;
    final double bh = bw * aspect;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(sin(_bob * 1.5) * 0.04);
    sp.render(
      canvas,
      position: Vector2(-bw / 2, -bh / 2),
      size: Vector2(bw, bh),
      overridePaint: _hitFlash > 0 ? _flashPaint : null,
    );
    canvas.restore();

    // Golden crown on top.
    final Path crown = Path()
      ..moveTo(r * 0.45, r * 0.35)
      ..lineTo(r * 0.6, -r * 0.2)
      ..lineTo(r * 0.8, r * 0.2)
      ..lineTo(r, -r * 0.35)
      ..lineTo(r * 1.2, r * 0.2)
      ..lineTo(r * 1.4, -r * 0.2)
      ..lineTo(r * 1.55, r * 0.35)
      ..close();
    canvas.drawPath(crown, Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFFFFF1A8), Palette.coin],
      ).createShader(Rect.fromLTWH(r * 0.45, -r * 0.35, r * 1.1, r * 0.7)));
    for (final double jx in <double>[0.6, 1.0, 1.4]) {
      canvas.drawCircle(Offset(r * jx, -r * 0.1), r * 0.06, Paint()..color = Palette.hudRed);
    }

    // Boss health bar floating above.
    final double w = r * 2.2;
    final double frac = healthFraction;
    final Rect bg = Rect.fromLTWH(r - w / 2, -r * 0.55, w, 8);
    canvas.drawRRect(RRect.fromRectAndRadius(bg, const Radius.circular(4)),
        Paint()..color = Colors.black54);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(r - w / 2, -r * 0.55, w * frac, 8), const Radius.circular(4)),
      Paint()..color = Color.lerp(Palette.hudRed, Palette.hudGreen, frac)!,
    );
  }
}
