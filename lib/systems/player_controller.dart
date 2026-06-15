import 'package:flutter/foundation.dart';

import '../models/player_data.dart';
import '../models/ship_data.dart';
import '../models/weapon_data.dart';
import 'save_system.dart';

/// The app-wide "wallet + locker" controller. Every screen reads currencies and
/// unlocks from here via Provider, and every spend/earn goes through one of
/// these guarded methods so balances can never go negative and so we can hook
/// analytics/cloud-save in a single place.
class PlayerController extends ChangeNotifier {
  PlayerController(this._save, this._data);

  final SaveSystem _save;
  PlayerData _data;

  PlayerData get data => _data;

  static Future<PlayerController> boot() async {
    final SaveSystem save = SaveSystem();
    final PlayerData data = await save.load();
    return PlayerController(save, data);
  }

  Future<void> persist() async {
    await _save.save(_data);
  }

  void _changed() {
    notifyListeners();
    // Fire-and-forget local persistence; cloud sync is debounced elsewhere.
    persist();
  }

  // ---------------------------------------------------------------------------
  // Currencies
  // ---------------------------------------------------------------------------
  int get coins => _data.coins;
  int get gems => _data.gems;
  int get level => _data.level;
  int get xp => _data.xp;

  void addCoins(int amount) {
    if (amount <= 0) return;
    _data.coins += amount;
    _changed();
  }

  void addGems(int amount) {
    if (amount <= 0) return;
    _data.gems += amount;
    _changed();
  }

  bool spendCoins(int amount) {
    if (amount < 0 || _data.coins < amount) return false;
    _data.coins -= amount;
    _changed();
    return true;
  }

  bool spendGems(int amount) {
    if (amount < 0 || _data.gems < amount) return false;
    _data.gems -= amount;
    _changed();
    return true;
  }

  /// Adds XP and resolves any level-ups, rewarding gems per level. Returns the
  /// number of levels gained so the UI can show a celebration.
  int addXp(int amount) {
    if (amount <= 0) return 0;
    _data.xp += amount;
    int gained = 0;
    while (_data.xp >= _data.xpForNextLevel) {
      _data.xp -= _data.xpForNextLevel;
      _data.level++;
      _data.gems += 10; // level-up gem reward
      gained++;
    }
    _changed();
    return gained;
  }

  // ---------------------------------------------------------------------------
  // Run results — called once when a run ends.
  // ---------------------------------------------------------------------------
  void recordRun({required int score, required int wave, required int coinsEarned}) {
    if (score > _data.highScore) _data.highScore = score;
    if (wave > _data.highestWave) _data.highestWave = wave;
    _data.coins += coinsEarned;
    _changed();
  }

  // ---------------------------------------------------------------------------
  // Weapons
  // ---------------------------------------------------------------------------
  bool isWeaponUnlocked(WeaponType type) => _data.unlockedWeapons.contains(type);

  bool unlockWeapon(WeaponType type) {
    final WeaponData def = WeaponData.table[type]!;
    if (isWeaponUnlocked(type)) return true;
    if (!spendGems(def.unlockCostGems)) return false;
    _data.unlockedWeapons.add(type);
    _data.weaponLevels[type.name] = 1;
    _changed();
    return true;
  }

  bool upgradeWeapon(WeaponType type) {
    if (!isWeaponUnlocked(type)) return false;
    final WeaponData def = WeaponData.table[type]!;
    final int current = _data.weaponLevel(type);
    if (current >= def.maxLevel) return false;
    if (!spendCoins(def.upgradeCost(current))) return false;
    _data.weaponLevels[type.name] = current + 1;
    _changed();
    return true;
  }

  void equipWeapon(WeaponType type) {
    if (!isWeaponUnlocked(type)) return;
    _data.equippedWeapon = type;
    _changed();
  }

  // ---------------------------------------------------------------------------
  // Ships + ship stat upgrades
  // ---------------------------------------------------------------------------
  bool isShipUnlocked(String id) => _data.unlockedShips.contains(id);

  bool unlockShip(ShipData ship) {
    if (isShipUnlocked(ship.id)) return true;
    if (ship.unlockCostGems > 0) {
      if (!spendGems(ship.unlockCostGems)) return false;
    } else {
      if (!spendCoins(ship.unlockCostCoins)) return false;
    }
    _data.unlockedShips.add(ship.id);
    _changed();
    return true;
  }

  void selectShip(String id) {
    if (!isShipUnlocked(id)) return;
    _data.selectedShipId = id;
    _changed();
  }

  /// Generic ship stat upgrade ("health", "damage", "fireRate", "magnet").
  bool upgradeShipStat(String key, {int maxLevel = 15}) {
    final int current = _data.shipUpgradeLevel(key);
    if (current >= maxLevel) return false;
    final int cost = 100 + current * current * 40;
    if (!spendCoins(cost)) return false;
    _data.shipUpgradeLevels[key] = current + 1;
    _changed();
    return true;
  }

  int shipStatUpgradeCost(String key) {
    final int current = _data.shipUpgradeLevel(key);
    return 100 + current * current * 40;
  }

  // ---------------------------------------------------------------------------
  // IAP-driven grants
  // ---------------------------------------------------------------------------
  void grantRemoveAds() {
    _data.adsRemoved = true;
    _changed();
  }

  void grantBattlePassPremium() {
    _data.battlePassPremium = true;
    _changed();
  }

  bool get adsRemoved => _data.adsRemoved;

  /// Replace the whole data object (used by cloud restore). Picks the most
  /// recently synced of the two to avoid clobbering newer local progress.
  void mergeFromCloud(PlayerData cloud) {
    if (cloud.lastSyncedMs >= _data.lastSyncedMs) {
      _data = cloud;
      _changed();
    }
  }
}
