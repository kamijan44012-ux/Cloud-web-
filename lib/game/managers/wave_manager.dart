import 'dart:math';

import '../../models/enemy_type.dart';

/// Decides *what* to spawn and *when*. The game asks the wave manager to advance
/// time and hands back spawn requests. Every 5th wave is a mini-boss wave and
/// every 10th is a giant galactic boss wave. Between bosses, enemy variety and
/// spawn rate ramp up with the wave number.
class WaveManager {
  WaveManager();

  final Random _rng = Random();

  int wave = 0;
  bool _bossActive = false;
  int _enemiesRemainingInWave = 0;
  double _spawnTimer = 0;
  double _spawnInterval = 1.2;

  bool get isBossWave => wave % 5 == 0;
  bool get isGiantBossWave => wave % 10 == 0;
  bool get bossActive => _bossActive;
  bool get waveCleared => _enemiesRemainingInWave <= 0 && !_bossActive;

  /// Begin the next wave. Returns the boss type to spawn immediately, or null
  /// for a normal wave (enemies stream in via [tick]).
  EnemyType? startNextWave() {
    wave++;
    _spawnTimer = 0;
    _spawnInterval = max(0.35, 1.2 - wave * 0.03);

    if (isGiantBossWave) {
      _bossActive = true;
      _enemiesRemainingInWave = 0;
      return EnemyType.galacticBoss;
    }
    if (isBossWave) {
      _bossActive = true;
      _enemiesRemainingInWave = 0;
      return EnemyType.miniBoss;
    }
    _enemiesRemainingInWave = 8 + wave * 2;
    return null;
  }

  void onBossDefeated() => _bossActive = false;

  /// Advance the spawn clock; returns an enemy type to spawn this frame, or null.
  EnemyType? tick(double dt) {
    if (_bossActive || _enemiesRemainingInWave <= 0) return null;
    _spawnTimer += dt;
    if (_spawnTimer < _spawnInterval) return null;
    _spawnTimer = 0;
    _enemiesRemainingInWave--;
    return _rollEnemyType();
  }

  EnemyType _rollEnemyType() {
    // Weighted pool that introduces tougher types as waves progress.
    final List<EnemyType> pool = <EnemyType>[
      EnemyType.normal,
      EnemyType.normal,
      EnemyType.normal,
      if (wave >= 2) EnemyType.fast,
      if (wave >= 3) EnemyType.fast,
      if (wave >= 4) EnemyType.armored,
      if (wave >= 5) EnemyType.kamikaze,
      if (wave >= 6) EnemyType.laser,
      if (wave >= 8) EnemyType.armored,
      if (wave >= 8) EnemyType.laser,
    ];
    return pool[_rng.nextInt(pool.length)];
  }
}
