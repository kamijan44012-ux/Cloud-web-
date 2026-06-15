import 'package:flutter/material.dart';
import '../config/palette.dart';

/// Unlockable spaceships. Each ship is a different power fantasy: more health,
/// more damage, wider shots, etc. Cosmetic colour + a small stat package.
class ShipData {
  const ShipData({
    required this.id,
    required this.name,
    required this.description,
    required this.color,
    required this.baseHealth,
    required this.damageMultiplier,
    required this.fireRateMultiplier,
    required this.bulletCount,
    required this.unlockCostCoins,
    required this.unlockCostGems,
  });

  final String id;
  final String name;
  final String description;
  final Color color;
  final double baseHealth;
  final double damageMultiplier;
  final double fireRateMultiplier;
  final int bulletCount; // simultaneous projectiles (spread)
  final int unlockCostCoins;
  final int unlockCostGems;

  static const List<ShipData> all = <ShipData>[
    ShipData(
      id: 'falcon',
      name: 'Star Falcon',
      description: 'Balanced rookie fighter. Free for all pilots.',
      color: Palette.hudGreen,
      baseHealth: 100,
      damageMultiplier: 1.0,
      fireRateMultiplier: 1.0,
      bulletCount: 1,
      unlockCostCoins: 0,
      unlockCostGems: 0,
    ),
    ShipData(
      id: 'viper',
      name: 'Neon Viper',
      description: 'Glass cannon. +40% damage, twin guns.',
      color: Palette.hudBlue,
      baseHealth: 90,
      damageMultiplier: 1.4,
      fireRateMultiplier: 1.1,
      bulletCount: 2,
      unlockCostCoins: 4000,
      unlockCostGems: 0,
    ),
    ShipData(
      id: 'titan',
      name: 'Iron Titan',
      description: 'Tank build. Huge health pool, triple spread.',
      color: Palette.chickenArmored,
      baseHealth: 180,
      damageMultiplier: 1.1,
      fireRateMultiplier: 0.9,
      bulletCount: 3,
      unlockCostCoins: 12000,
      unlockCostGems: 0,
    ),
    ShipData(
      id: 'phoenix',
      name: 'Galaxy Phoenix',
      description: 'Premium flagship. Everything, dialled to 11.',
      color: Palette.nebulaPink,
      baseHealth: 160,
      damageMultiplier: 1.6,
      fireRateMultiplier: 1.3,
      bulletCount: 4,
      unlockCostCoins: 0,
      unlockCostGems: 600,
    ),
  ];

  static ShipData byId(String id) =>
      all.firstWhere((ShipData s) => s.id == id, orElse: () => all.first);
}
