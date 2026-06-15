/// Missions / daily challenges. A mission tracks progress against a [target]
/// for a given [metric] and pays out coins/gems/battle-pass XP on completion.
enum MissionMetric {
  killChickens,
  killBosses,
  collectCoins,
  reachWave,
  useUltimate,
  collectPowerUps,
  playRuns,
}

enum MissionScope { daily, weekly, career }

class Mission {
  Mission({
    required this.id,
    required this.title,
    required this.metric,
    required this.target,
    required this.rewardCoins,
    required this.rewardGems,
    required this.rewardPassXp,
    required this.scope,
    this.progress = 0,
    this.claimed = false,
  });

  final String id;
  final String title;
  final MissionMetric metric;
  final int target;
  final int rewardCoins;
  final int rewardGems;
  final int rewardPassXp;
  final MissionScope scope;

  int progress;
  bool claimed;

  bool get isComplete => progress >= target;
  double get fraction => (progress / target).clamp(0.0, 1.0);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'progress': progress,
        'claimed': claimed,
      };
}
