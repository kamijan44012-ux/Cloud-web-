import 'package:flutter/material.dart';
import '../config/palette.dart';

/// Collectible power-ups dropped by enemies. Each has an icon glyph, colour,
/// and (for timed buffs) a duration applied by the game's BuffManager.
enum PowerUpType {
  shield,
  rapidFire,
  health,
  magnet,
  doubleDamage,
  timeFreeze,
  coinBurst,
}

class PowerUpInfo {
  const PowerUpInfo({
    required this.type,
    required this.label,
    required this.glyph,
    required this.color,
    required this.duration,
    this.instant = false,
  });

  final PowerUpType type;
  final String label;
  final String glyph; // emoji-ish glyph drawn on the pickup
  final Color color;
  final double duration; // seconds, 0 for instant pickups
  final bool instant;

  static const Map<PowerUpType, PowerUpInfo> table = <PowerUpType, PowerUpInfo>{
    PowerUpType.shield: PowerUpInfo(
      type: PowerUpType.shield,
      label: 'Shield',
      glyph: '🛡',
      color: Palette.hudBlue,
      duration: 8,
    ),
    PowerUpType.rapidFire: PowerUpInfo(
      type: PowerUpType.rapidFire,
      label: 'Rapid Fire',
      glyph: '⚡',
      color: Palette.hudYellow,
      duration: 7,
    ),
    PowerUpType.health: PowerUpInfo(
      type: PowerUpType.health,
      label: 'Repair',
      glyph: '❤',
      color: Palette.hudRed,
      duration: 0,
      instant: true,
    ),
    PowerUpType.magnet: PowerUpInfo(
      type: PowerUpType.magnet,
      label: 'Magnet',
      glyph: '🧲',
      color: Palette.nebulaPink,
      duration: 9,
    ),
    PowerUpType.doubleDamage: PowerUpInfo(
      type: PowerUpType.doubleDamage,
      label: '2x Damage',
      glyph: '✖',
      color: Palette.chickenKamikaze,
      duration: 7,
    ),
    PowerUpType.timeFreeze: PowerUpInfo(
      type: PowerUpType.timeFreeze,
      label: 'Time Freeze',
      glyph: '❄',
      color: Palette.gem,
      duration: 4,
    ),
    PowerUpType.coinBurst: PowerUpInfo(
      type: PowerUpType.coinBurst,
      label: 'Coin Burst',
      glyph: '💰',
      color: Palette.coin,
      duration: 0,
      instant: true,
    ),
  };
}
