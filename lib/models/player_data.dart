import 'weapon_data.dart';

/// The single source of truth for all persistent player state. This is what
/// gets serialised to local storage and mirrored to Firestore for cloud save.
///
/// Keep this class pure data + (de)serialisation. Mutating logic that has rules
/// (spending, levelling, etc.) lives in the systems layer so it can be tested
/// and so cheating is harder to do by accident.
class PlayerData {
  PlayerData({
    this.coins = 0,
    this.gems = 0,
    this.xp = 0,
    this.level = 1,
    this.highScore = 0,
    this.highestWave = 0,
    String? selectedShipId,
    WeaponType? equippedWeapon,
    Map<String, int>? weaponLevels,
    Map<String, int>? shipUpgradeLevels,
    Set<String>? unlockedShips,
    Set<WeaponType>? unlockedWeapons,
    Set<String>? completedMissions,
    Set<String>? unlockedAchievements,
    this.lastDailyClaim,
    this.dailyStreak = 0,
    this.battlePassTier = 0,
    this.battlePassXp = 0,
    this.battlePassPremium = false,
    this.adsRemoved = false,
    this.lastSyncedMs = 0,
  })  : selectedShipId = selectedShipId ?? 'falcon',
        equippedWeapon = equippedWeapon ?? WeaponType.laser,
        weaponLevels = weaponLevels ?? <String, int>{WeaponType.laser.name: 1},
        shipUpgradeLevels = shipUpgradeLevels ?? <String, int>{},
        unlockedShips = unlockedShips ?? <String>{'falcon'},
        unlockedWeapons = unlockedWeapons ?? <WeaponType>{WeaponType.laser},
        completedMissions = completedMissions ?? <String>{},
        unlockedAchievements = unlockedAchievements ?? <String>{};

  int coins;
  int gems;
  int xp;
  int level;
  int highScore;
  int highestWave;

  String selectedShipId;
  WeaponType equippedWeapon;

  /// weapon name -> level
  Map<String, int> weaponLevels;

  /// upgrade key (e.g. "health", "damage", "fireRate") -> level
  Map<String, int> shipUpgradeLevels;

  Set<String> unlockedShips;
  Set<WeaponType> unlockedWeapons;
  Set<String> completedMissions;
  Set<String> unlockedAchievements;

  /// ISO-8601 timestamp of the last claimed daily reward.
  String? lastDailyClaim;
  int dailyStreak;

  int battlePassTier;
  int battlePassXp;
  bool battlePassPremium;

  bool adsRemoved;
  int lastSyncedMs;

  int weaponLevel(WeaponType type) => weaponLevels[type.name] ?? 0;
  int shipUpgradeLevel(String key) => shipUpgradeLevels[key] ?? 0;

  /// XP required to reach the *next* level from the current one.
  int get xpForNextLevel => 100 + (level - 1) * (level - 1) * 25;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'coins': coins,
        'gems': gems,
        'xp': xp,
        'level': level,
        'highScore': highScore,
        'highestWave': highestWave,
        'selectedShipId': selectedShipId,
        'equippedWeapon': equippedWeapon.name,
        'weaponLevels': weaponLevels,
        'shipUpgradeLevels': shipUpgradeLevels,
        'unlockedShips': unlockedShips.toList(),
        'unlockedWeapons': unlockedWeapons.map((WeaponType w) => w.name).toList(),
        'completedMissions': completedMissions.toList(),
        'unlockedAchievements': unlockedAchievements.toList(),
        'lastDailyClaim': lastDailyClaim,
        'dailyStreak': dailyStreak,
        'battlePassTier': battlePassTier,
        'battlePassXp': battlePassXp,
        'battlePassPremium': battlePassPremium,
        'adsRemoved': adsRemoved,
        'lastSyncedMs': lastSyncedMs,
      };

  factory PlayerData.fromJson(Map<String, dynamic> json) {
    WeaponType weaponFromName(String? n) => WeaponType.values.firstWhere(
          (WeaponType w) => w.name == n,
          orElse: () => WeaponType.laser,
        );
    return PlayerData(
      coins: (json['coins'] ?? 0) as int,
      gems: (json['gems'] ?? 0) as int,
      xp: (json['xp'] ?? 0) as int,
      level: (json['level'] ?? 1) as int,
      highScore: (json['highScore'] ?? 0) as int,
      highestWave: (json['highestWave'] ?? 0) as int,
      selectedShipId: json['selectedShipId'] as String?,
      equippedWeapon: weaponFromName(json['equippedWeapon'] as String?),
      weaponLevels: (json['weaponLevels'] as Map?)?.map(
            (dynamic k, dynamic v) => MapEntry<String, int>(k as String, v as int),
          ) ??
          <String, int>{WeaponType.laser.name: 1},
      shipUpgradeLevels: (json['shipUpgradeLevels'] as Map?)?.map(
            (dynamic k, dynamic v) => MapEntry<String, int>(k as String, v as int),
          ) ??
          <String, int>{},
      unlockedShips: ((json['unlockedShips'] as List?) ?? <dynamic>['falcon'])
          .map((dynamic e) => e as String)
          .toSet(),
      unlockedWeapons: ((json['unlockedWeapons'] as List?) ?? <dynamic>['laser'])
          .map((dynamic e) => weaponFromName(e as String))
          .toSet(),
      completedMissions: ((json['completedMissions'] as List?) ?? <dynamic>[])
          .map((dynamic e) => e as String)
          .toSet(),
      unlockedAchievements: ((json['unlockedAchievements'] as List?) ?? <dynamic>[])
          .map((dynamic e) => e as String)
          .toSet(),
      lastDailyClaim: json['lastDailyClaim'] as String?,
      dailyStreak: (json['dailyStreak'] ?? 0) as int,
      battlePassTier: (json['battlePassTier'] ?? 0) as int,
      battlePassXp: (json['battlePassXp'] ?? 0) as int,
      battlePassPremium: (json['battlePassPremium'] ?? false) as bool,
      adsRemoved: (json['adsRemoved'] ?? false) as bool,
      lastSyncedMs: (json['lastSyncedMs'] ?? 0) as int,
    );
  }
}
