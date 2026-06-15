/// Permanent, account-wide achievements. Unlike missions these never reset and
/// usually pay out gems. They double as Google Play Games achievements if you
/// wire `games_services` later.
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.rewardGems,
    required this.targetValue,
  });

  final String id;
  final String title;
  final String description;
  final int rewardGems;
  final int targetValue;

  static const List<Achievement> all = <Achievement>[
    Achievement(
      id: 'first_blood',
      title: 'First Blood',
      description: 'Destroy your first chicken.',
      rewardGems: 5,
      targetValue: 1,
    ),
    Achievement(
      id: 'chicken_genocide',
      title: 'Galactic Exterminator',
      description: 'Destroy 1,000 chickens in total.',
      rewardGems: 50,
      targetValue: 1000,
    ),
    Achievement(
      id: 'boss_slayer',
      title: 'Boss Slayer',
      description: 'Defeat 10 bosses.',
      rewardGems: 40,
      targetValue: 10,
    ),
    Achievement(
      id: 'wave_master',
      title: 'Wave Master',
      description: 'Reach wave 25 in a single run.',
      rewardGems: 60,
      targetValue: 25,
    ),
    Achievement(
      id: 'rich_pilot',
      title: 'Space Tycoon',
      description: 'Accumulate 100,000 coins over your career.',
      rewardGems: 80,
      targetValue: 100000,
    ),
    Achievement(
      id: 'full_arsenal',
      title: 'Full Arsenal',
      description: 'Unlock every weapon.',
      rewardGems: 100,
      targetValue: 4,
    ),
  ];
}
