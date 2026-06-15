import 'package:flutter/foundation.dart';

import 'player_controller.dart';

class BattlePassReward {
  const BattlePassReward({
    required this.tier,
    required this.freeCoins,
    required this.freeGems,
    required this.premiumCoins,
    required this.premiumGems,
    this.premiumShipId,
  });

  final int tier;
  final int freeCoins;
  final int freeGems;
  final int premiumCoins;
  final int premiumGems;
  final String? premiumShipId;
}

/// Seasonal battle pass: 30 tiers, a free track and a premium track unlocked by
/// IAP. XP comes from missions and run performance. This is one of the strongest
/// long-term retention + monetisation loops in the game.
class BattlePassSystem extends ChangeNotifier {
  BattlePassSystem(this._player);

  final PlayerController _player;

  static const int xpPerTier = 100;
  static const int maxTier = 30;

  int get tier => _player.data.battlePassTier;
  int get tierXp => _player.data.battlePassXp;
  bool get isPremium => _player.data.battlePassPremium;
  double get tierFraction => (tierXp / xpPerTier).clamp(0.0, 1.0);

  /// Procedurally generated reward table. Premium tiers are richer and every
  /// 10th tier hands out a ship to chase.
  BattlePassReward rewardForTier(int t) {
    return BattlePassReward(
      tier: t,
      freeCoins: 200 + t * 20,
      freeGems: t % 5 == 0 ? 5 : 0,
      premiumCoins: 400 + t * 40,
      premiumGems: t % 3 == 0 ? 10 : 5,
      premiumShipId: t == 20 ? 'phoenix' : null,
    );
  }

  void addXp(int amount) {
    if (amount <= 0 || tier >= maxTier) return;
    _player.data.battlePassXp += amount;
    while (_player.data.battlePassXp >= xpPerTier && _player.data.battlePassTier < maxTier) {
      _player.data.battlePassXp -= xpPerTier;
      _player.data.battlePassTier++;
      _grant(rewardForTier(_player.data.battlePassTier));
    }
    _player.persist();
    notifyListeners();
  }

  void _grant(BattlePassReward r) {
    _player.addCoins(r.freeCoins);
    _player.addGems(r.freeGems);
    if (isPremium) {
      _player.addCoins(r.premiumCoins);
      _player.addGems(r.premiumGems);
      if (r.premiumShipId != null) {
        _player.data.unlockedShips.add(r.premiumShipId!);
      }
    }
  }
}
