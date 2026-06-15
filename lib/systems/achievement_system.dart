import 'package:flutter/foundation.dart';

import '../models/achievement.dart';
import 'player_controller.dart';

/// Tracks career stats and unlocks achievements when thresholds are crossed.
/// Career counters live here (mirrored into PlayerData so they persist).
class AchievementSystem extends ChangeNotifier {
  AchievementSystem(this._player);

  final PlayerController _player;

  int _totalKills = 0;
  int _totalBossKills = 0;
  int _careerCoins = 0;

  /// Returns ids of any achievements unlocked by this update so the UI can toast.
  List<String> reportKills(int kills) {
    _totalKills += kills;
    return _checkAll();
  }

  List<String> reportBossKill() {
    _totalBossKills++;
    return _checkAll();
  }

  List<String> reportCoins(int coins) {
    _careerCoins += coins;
    return _checkAll();
  }

  List<String> reportWave(int wave) => _checkAll(wave: wave);

  List<String> _checkAll({int wave = 0}) {
    final List<String> newly = <String>[];
    for (final Achievement a in Achievement.all) {
      if (_player.data.unlockedAchievements.contains(a.id)) continue;
      final int value = switch (a.id) {
        'first_blood' => _totalKills,
        'chicken_genocide' => _totalKills,
        'boss_slayer' => _totalBossKills,
        'wave_master' => wave,
        'rich_pilot' => _careerCoins,
        'full_arsenal' => _player.data.unlockedWeapons.length,
        _ => 0,
      };
      if (value >= a.targetValue) {
        _player.data.unlockedAchievements.add(a.id);
        _player.addGems(a.rewardGems);
        newly.add(a.id);
      }
    }
    if (newly.isNotEmpty) notifyListeners();
    return newly;
  }
}
