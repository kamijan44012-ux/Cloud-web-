import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/palette.dart';
import '../../models/weapon_data.dart';
import '../../systems/player_controller.dart';
import '../widgets/currency_bar.dart';
import '../widgets/space_background.dart';

/// Weapon arsenal: unlock with gems, upgrade with coins, equip one weapon.
/// Also exposes the four global ship-stat upgrade tracks.
class UpgradeScreen extends StatelessWidget {
  const UpgradeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final PlayerController player = context.watch<PlayerController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Arsenal & Upgrades'), backgroundColor: Colors.transparent),
      extendBodyBehindAppBar: true,
      body: SpaceBackground(
        child: Column(
          children: <Widget>[
            const CurrencyBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  const _SectionTitle('Weapons'),
                  ...WeaponData.table.values.map((WeaponData w) => _WeaponCard(weapon: w, player: player)),
                  const SizedBox(height: 16),
                  const _SectionTitle('Ship Systems'),
                  _statTile(context, player, 'health', 'Hull Plating', 'Max health +10% / level'),
                  _statTile(context, player, 'damage', 'Targeting Array', 'Damage +5% / level'),
                  _statTile(context, player, 'fireRate', 'Coolant System', 'Fire rate +4% / level'),
                  _statTile(context, player, 'magnet', 'Tractor Beam', 'Pickup range / level'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile(BuildContext context, PlayerController player, String key, String name, String desc) {
    final int level = player.data.shipUpgradeLevel(key);
    final int cost = player.shipStatUpgradeCost(key);
    return Card(
      color: Colors.black.withOpacity(0.4),
      child: ListTile(
        title: Text('$name  (Lv $level)'),
        subtitle: Text(desc),
        trailing: ElevatedButton(
          onPressed: player.coins >= cost ? () => player.upgradeShipStat(key) : null,
          child: Text('$cost 🪙'),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Palette.hudYellow)),
      );
}

class _WeaponCard extends StatelessWidget {
  const _WeaponCard({required this.weapon, required this.player});
  final WeaponData weapon;
  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    final bool unlocked = player.isWeaponUnlocked(weapon.type);
    final bool equipped = player.data.equippedWeapon == weapon.type;
    final int level = player.data.weaponLevel(weapon.type);
    final bool maxed = level >= weapon.maxLevel;
    final int upgradeCost = weapon.upgradeCost(level);

    return Card(
      color: Colors.black.withOpacity(0.45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: equipped ? Palette.hudGreen : weapon.color.withOpacity(0.5), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.gps_fixed, color: weapon.color),
                const SizedBox(width: 8),
                Text(weapon.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (unlocked) Text('Lv $level', style: const TextStyle(color: Palette.hudGreen)),
              ],
            ),
            const SizedBox(height: 4),
            Text(weapon.description, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                if (!unlocked)
                  ElevatedButton(
                    onPressed: player.gems >= weapon.unlockCostGems
                        ? () => player.unlockWeapon(weapon.type)
                        : null,
                    child: Text(weapon.unlockCostGems == 0 ? 'Unlock' : 'Unlock ${weapon.unlockCostGems} 💎'),
                  )
                else ...<Widget>[
                  ElevatedButton(
                    onPressed: equipped ? null : () => player.equipWeapon(weapon.type),
                    child: Text(equipped ? 'Equipped' : 'Equip'),
                  ),
                  const SizedBox(width: 8),
                  if (!maxed)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Palette.coin),
                      onPressed: player.coins >= upgradeCost ? () => player.upgradeWeapon(weapon.type) : null,
                      child: Text('Upgrade $upgradeCost 🪙'),
                    )
                  else
                    const Text('MAX', style: TextStyle(color: Palette.hudYellow, fontWeight: FontWeight.bold)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
