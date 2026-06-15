import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chicken_hunter_space_war/models/player_data.dart';
import 'package:chicken_hunter_space_war/models/weapon_data.dart';
import 'package:chicken_hunter_space_war/systems/player_controller.dart';
import 'package:chicken_hunter_space_war/systems/save_system.dart';

void main() {
  // PlayerController persists via SharedPreferences, so mock it.
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  PlayerController makeController() => PlayerController(SaveSystem(), PlayerData());

  group('Economy', () {
    test('cannot spend more coins than owned', () {
      final PlayerController p = makeController();
      p.addCoins(100);
      expect(p.spendCoins(150), isFalse);
      expect(p.coins, 100);
      expect(p.spendCoins(60), isTrue);
      expect(p.coins, 40);
    });

    test('balances never go negative on gems', () {
      final PlayerController p = makeController();
      expect(p.spendGems(1), isFalse);
      expect(p.gems, 0);
    });
  });

  group('Leveling', () {
    test('XP rolls over into levels and grants gems', () {
      final PlayerController p = makeController();
      final int startGems = p.gems;
      final int gained = p.addXp(10000);
      expect(gained, greaterThan(0));
      expect(p.level, greaterThan(1));
      expect(p.gems, greaterThan(startGems));
    });
  });

  group('Weapons', () {
    test('upgrading a weapon spends coins and raises its level', () {
      final PlayerController p = makeController();
      p.addCoins(100000);
      final int before = p.data.weaponLevel(WeaponType.laser);
      expect(p.upgradeWeapon(WeaponType.laser), isTrue);
      expect(p.data.weaponLevel(WeaponType.laser), before + 1);
      expect(p.coins, lessThan(100000));
    });

    test('locked weapon cannot be equipped', () {
      final PlayerController p = makeController();
      p.equipWeapon(WeaponType.nuke); // not unlocked
      expect(p.data.equippedWeapon, WeaponType.laser);
    });
  });

  group('Persistence', () {
    test('round-trips player data through JSON', () {
      final PlayerData data = PlayerData(coins: 1234, gems: 56, level: 7);
      final PlayerData restored = PlayerData.fromJson(data.toJson());
      expect(restored.coins, 1234);
      expect(restored.gems, 56);
      expect(restored.level, 7);
    });
  });
}
