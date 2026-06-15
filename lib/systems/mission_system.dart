import 'package:flutter/foundation.dart';

import '../models/mission.dart';
import 'battle_pass.dart';
import 'player_controller.dart';

/// Generates and tracks daily/weekly missions and pushes completion rewards.
/// During a run, the game calls [report] with metric deltas; the system fans
/// those out to every active mission and to the battle pass.
class MissionSystem extends ChangeNotifier {
  MissionSystem(this._player, this._battlePass) {
    _ensureDailies();
  }

  final PlayerController _player;
  final BattlePassSystem _battlePass;

  final List<Mission> _missions = <Mission>[];
  List<Mission> get missions => List<Mission>.unmodifiable(_missions);

  void _ensureDailies() {
    if (_missions.isNotEmpty) return;
    // A small rotating pool. In production seed these from Remote Config /
    // server time so every player gets the same daily set.
    _missions.addAll(<Mission>[
      Mission(
        id: 'daily_kill_60',
        title: 'Pluck 60 chickens',
        metric: MissionMetric.killChickens,
        target: 60,
        rewardCoins: 400,
        rewardGems: 0,
        rewardPassXp: 30,
        scope: MissionScope.daily,
      ),
      Mission(
        id: 'daily_wave_10',
        title: 'Reach wave 10',
        metric: MissionMetric.reachWave,
        target: 10,
        rewardCoins: 600,
        rewardGems: 5,
        rewardPassXp: 40,
        scope: MissionScope.daily,
      ),
      Mission(
        id: 'daily_powerups_5',
        title: 'Grab 5 power-ups',
        metric: MissionMetric.collectPowerUps,
        target: 5,
        rewardCoins: 300,
        rewardGems: 0,
        rewardPassXp: 25,
        scope: MissionScope.daily,
      ),
      Mission(
        id: 'weekly_boss_3',
        title: 'Defeat 3 bosses this week',
        metric: MissionMetric.killBosses,
        target: 3,
        rewardCoins: 1500,
        rewardGems: 25,
        rewardPassXp: 120,
        scope: MissionScope.weekly,
      ),
    ]);
  }

  /// Report a gameplay event. [metric] is what happened, [amount] how much
  /// (e.g. killChickens +1). For [MissionMetric.reachWave] pass the absolute
  /// wave number; we keep the max rather than summing.
  void report(MissionMetric metric, int amount) {
    bool dirty = false;
    for (final Mission m in _missions) {
      if (m.metric != metric || m.claimed) continue;
      if (metric == MissionMetric.reachWave) {
        if (amount > m.progress) {
          m.progress = amount;
          dirty = true;
        }
      } else {
        m.progress += amount;
        dirty = true;
      }
    }
    if (dirty) notifyListeners();
  }

  bool claim(Mission mission) {
    if (!mission.isComplete || mission.claimed) return false;
    mission.claimed = true;
    _player.addCoins(mission.rewardCoins);
    _player.addGems(mission.rewardGems);
    _battlePass.addXp(mission.rewardPassXp);
    notifyListeners();
    return true;
  }
}
