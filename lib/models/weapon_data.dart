import 'package:flutter/material.dart';
import '../config/palette.dart';

enum WeaponType { laser, plasma, rocket, lightning, nuke }

/// Definition of a weapon plus its per-level upgrade curve. The player's owned
/// level for each weapon lives in PlayerData; this class turns a level into
/// concrete stats via [statsAtLevel].
class WeaponData {
  const WeaponData({
    required this.type,
    required this.name,
    required this.description,
    required this.color,
    required this.baseDamage,
    required this.baseFireInterval,
    required this.projectileSpeed,
    required this.maxLevel,
    required this.unlockCostGems,
    this.pierces = false,
    this.aoeRadius = 0,
    this.isUltimate = false,
  });

  final WeaponType type;
  final String name;
  final String description;
  final Color color;
  final double baseDamage;
  final double baseFireInterval;
  final double projectileSpeed;
  final int maxLevel;
  final int unlockCostGems;
  final bool pierces;
  final double aoeRadius;
  final bool isUltimate;

  WeaponStats statsAtLevel(int level) {
    final int l = level.clamp(1, maxLevel);
    return WeaponStats(
      damage: baseDamage * (1 + (l - 1) * 0.25),
      fireInterval: baseFireInterval * (1 - (l - 1) * 0.04).clamp(0.4, 1.0),
      projectileSpeed: projectileSpeed,
      aoeRadius: aoeRadius,
      pierces: pierces,
    );
  }

  /// Coin cost to go from [level] to [level]+1. Exponential so late upgrades
  /// are a meaningful gem/coin sink (retention + monetisation).
  int upgradeCost(int level) => (60 * (1.55 * level).clamp(1, 999)).round() + level * level * 25;

  static const Map<WeaponType, WeaponData> table = <WeaponType, WeaponData>{
    WeaponType.laser: WeaponData(
      type: WeaponType.laser,
      name: 'Pulse Laser',
      description: 'Reliable rapid-fire starter laser.',
      color: Palette.hudGreen,
      baseDamage: 10,
      baseFireInterval: 0.30,
      projectileSpeed: 620,
      maxLevel: 20,
      unlockCostGems: 0,
    ),
    WeaponType.plasma: WeaponData(
      type: WeaponType.plasma,
      name: 'Plasma Cannon',
      description: 'Heavy bolts that hit hard and slow.',
      color: Palette.hudBlue,
      baseDamage: 26,
      baseFireInterval: 0.55,
      projectileSpeed: 520,
      maxLevel: 20,
      unlockCostGems: 120,
    ),
    WeaponType.rocket: WeaponData(
      type: WeaponType.rocket,
      name: 'Rocket Pod',
      description: 'Explodes on impact, area damage.',
      color: Palette.chickenKamikaze,
      baseDamage: 40,
      baseFireInterval: 0.85,
      projectileSpeed: 460,
      maxLevel: 20,
      unlockCostGems: 220,
      aoeRadius: 70,
    ),
    WeaponType.lightning: WeaponData(
      type: WeaponType.lightning,
      name: 'Lightning Gun',
      description: 'Chains through enemies, pierces all.',
      color: Palette.xp,
      baseDamage: 18,
      baseFireInterval: 0.45,
      projectileSpeed: 800,
      maxLevel: 20,
      unlockCostGems: 320,
      pierces: true,
    ),
    WeaponType.nuke: WeaponData(
      type: WeaponType.nuke,
      name: 'Nuclear Strike',
      description: 'Ultimate: clears the screen. Charges over time.',
      color: Palette.hudRed,
      baseDamage: 9999,
      baseFireInterval: 999,
      projectileSpeed: 0,
      maxLevel: 5,
      unlockCostGems: 0,
      aoeRadius: 2000,
      isUltimate: true,
    ),
  };
}

class WeaponStats {
  const WeaponStats({
    required this.damage,
    required this.fireInterval,
    required this.projectileSpeed,
    required this.aoeRadius,
    required this.pierces,
  });

  final double damage;
  final double fireInterval;
  final double projectileSpeed;
  final double aoeRadius;
  final bool pierces;
}
