import 'package:flutter/material.dart';
import '../config/palette.dart';

/// Every kind of chicken in the galaxy. Behaviour for each is implemented in
/// `game/components/enemies/` and selected by this enum.
enum EnemyType {
  normal,
  fast,
  armored,
  laser,
  kamikaze,
  miniBoss,
  galacticBoss,
}

/// Static, data-driven stats for an enemy type. Keeping stats out of the
/// component classes makes balancing a spreadsheet-style exercise and lets us
/// scale everything by wave/difficulty in one place ([scaledFor]).
class EnemyStats {
  const EnemyStats({
    required this.type,
    required this.maxHealth,
    required this.speed,
    required this.contactDamage,
    required this.coinReward,
    required this.xpReward,
    required this.radius,
    required this.color,
    this.canShoot = false,
    this.shootInterval = 2.0,
    this.isBoss = false,
  });

  final EnemyType type;
  final double maxHealth;
  final double speed; // logical px / second
  final double contactDamage;
  final int coinReward;
  final int xpReward;
  final double radius;
  final Color color;
  final bool canShoot;
  final double shootInterval;
  final bool isBoss;

  /// Returns a copy with health/damage/reward scaled up for deeper waves so the
  /// game keeps getting harder (and more rewarding) without new content.
  EnemyStats scaledFor(int wave) {
    final double hpMul = 1 + wave * 0.12;
    final double dmgMul = 1 + wave * 0.05;
    final double rewardMul = 1 + wave * 0.08;
    return EnemyStats(
      type: type,
      maxHealth: maxHealth * hpMul,
      speed: speed * (1 + wave * 0.01).clamp(1.0, 2.0),
      contactDamage: contactDamage * dmgMul,
      coinReward: (coinReward * rewardMul).round(),
      xpReward: (xpReward * rewardMul).round(),
      radius: radius,
      color: color,
      canShoot: canShoot,
      shootInterval: shootInterval,
      isBoss: isBoss,
    );
  }

  static const Map<EnemyType, EnemyStats> table = <EnemyType, EnemyStats>{
    EnemyType.normal: EnemyStats(
      type: EnemyType.normal,
      maxHealth: 30,
      speed: 70,
      contactDamage: 10,
      coinReward: 5,
      xpReward: 3,
      radius: 22,
      color: Palette.chickenNormal,
    ),
    EnemyType.fast: EnemyStats(
      type: EnemyType.fast,
      maxHealth: 18,
      speed: 160,
      contactDamage: 8,
      coinReward: 7,
      xpReward: 4,
      radius: 18,
      color: Palette.chickenFast,
    ),
    EnemyType.armored: EnemyStats(
      type: EnemyType.armored,
      maxHealth: 90,
      speed: 45,
      contactDamage: 16,
      coinReward: 14,
      xpReward: 9,
      radius: 26,
      color: Palette.chickenArmored,
    ),
    EnemyType.laser: EnemyStats(
      type: EnemyType.laser,
      maxHealth: 45,
      speed: 55,
      contactDamage: 10,
      coinReward: 16,
      xpReward: 11,
      radius: 23,
      color: Palette.chickenLaser,
      canShoot: true,
      shootInterval: 1.8,
    ),
    EnemyType.kamikaze: EnemyStats(
      type: EnemyType.kamikaze,
      maxHealth: 22,
      speed: 120,
      contactDamage: 28,
      coinReward: 12,
      xpReward: 8,
      radius: 20,
      color: Palette.chickenKamikaze,
    ),
    EnemyType.miniBoss: EnemyStats(
      type: EnemyType.miniBoss,
      maxHealth: 600,
      speed: 40,
      contactDamage: 30,
      coinReward: 120,
      xpReward: 80,
      radius: 46,
      color: Palette.chickenBoss,
      canShoot: true,
      shootInterval: 1.2,
      isBoss: true,
    ),
    EnemyType.galacticBoss: EnemyStats(
      type: EnemyType.galacticBoss,
      maxHealth: 2400,
      speed: 28,
      contactDamage: 45,
      coinReward: 500,
      xpReward: 320,
      radius: 72,
      color: Palette.chickenBoss,
      canShoot: true,
      shootInterval: 0.8,
      isBoss: true,
    ),
  };
}
