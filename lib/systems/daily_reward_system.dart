import 'player_controller.dart';

/// 7-day escalating daily login reward with streak tracking. Day 7 pays gems to
/// pull players back; missing a day resets the streak to day 1.
class DailyReward {
  const DailyReward(this.day, this.coins, this.gems);
  final int day;
  final int coins;
  final int gems;
}

class DailyRewardSystem {
  static const List<DailyReward> rewards = <DailyReward>[
    DailyReward(1, 100, 0),
    DailyReward(2, 200, 0),
    DailyReward(3, 350, 5),
    DailyReward(4, 500, 0),
    DailyReward(5, 800, 10),
    DailyReward(6, 1200, 0),
    DailyReward(7, 2000, 50),
  ];

  /// Whether a reward is available to claim right now.
  static bool canClaim(PlayerController player) {
    final String? last = player.data.lastDailyClaim;
    if (last == null) return true;
    final DateTime lastDate = DateTime.parse(last);
    final DateTime now = DateTime.now();
    return !_isSameDay(lastDate, now);
  }

  /// Claims today's reward, advancing or resetting the streak. Returns the
  /// reward granted, or null if already claimed today.
  static DailyReward? claim(PlayerController player) {
    if (!canClaim(player)) return null;
    final String? last = player.data.lastDailyClaim;
    final DateTime now = DateTime.now();

    if (last != null) {
      final DateTime lastDate = DateTime.parse(last);
      final bool consecutive = _isSameDay(lastDate.add(const Duration(days: 1)), now);
      player.data.dailyStreak = consecutive ? player.data.dailyStreak + 1 : 0;
    }

    final int index = player.data.dailyStreak % rewards.length;
    final DailyReward reward = rewards[index];

    player.addCoins(reward.coins);
    player.addGems(reward.gems);
    player.data.lastDailyClaim = now.toIso8601String();
    player.persist();
    return reward;
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
