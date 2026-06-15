import '../../models/power_up_type.dart';

/// Tracks active timed power-up buffs and counts them down. The game ticks this
/// each frame and reads the boolean getters to alter gameplay (fire rate,
/// damage, shield, magnet, time-freeze).
class BuffManager {
  final Map<PowerUpType, double> _remaining = <PowerUpType, double>{};

  void activate(PowerUpType type, double duration) {
    _remaining[type] = (_remaining[type] ?? 0) + duration;
  }

  void tick(double dt) {
    final List<PowerUpType> expired = <PowerUpType>[];
    _remaining.forEach((PowerUpType type, double t) {
      final double left = t - dt;
      if (left <= 0) {
        expired.add(type);
      } else {
        _remaining[type] = left;
      }
    });
    for (final PowerUpType t in expired) {
      _remaining.remove(t);
    }
  }

  void clear() => _remaining.clear();

  bool isActive(PowerUpType t) => (_remaining[t] ?? 0) > 0;
  double remaining(PowerUpType t) => _remaining[t] ?? 0;

  bool get shield => isActive(PowerUpType.shield);
  bool get rapidFire => isActive(PowerUpType.rapidFire);
  bool get magnet => isActive(PowerUpType.magnet);
  bool get doubleDamage => isActive(PowerUpType.doubleDamage);
  bool get timeFreeze => isActive(PowerUpType.timeFreeze);

  Map<PowerUpType, double> get active => Map<PowerUpType, double>.unmodifiable(_remaining);
}
