import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/game_config.dart';
import '../../config/palette.dart';
import '../../services/ads_service.dart';
import '../../services/iap_service.dart';
import '../../systems/player_controller.dart';
import '../widgets/currency_bar.dart';
import '../widgets/space_background.dart';

/// Store front: real-money gem packs + special offers (IAP), a free-gems
/// rewarded ad, and gem→coin conversion. Real prices come from the store via
/// [IapService]; we fall back to a default label when products aren't loaded.
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final PlayerController player = context.watch<PlayerController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Galactic Store'), backgroundColor: Colors.transparent),
      extendBodyBehindAppBar: true,
      body: SpaceBackground(
        child: Column(
          children: <Widget>[
            const CurrencyBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  _freeGems(context, player),
                  const SizedBox(height: 8),
                  _header('Special Offers'),
                  _iapTile(context, GameConfig.iapStarterPack, 'Starter Pack', '5000 🪙 + 300 💎', Palette.hudGreen, '\$2.99'),
                  _iapTile(context, GameConfig.iapRemoveAds, 'Remove Ads', 'No more interstitials', Palette.hudRed, '\$3.99',
                      owned: player.adsRemoved),
                  _iapTile(context, GameConfig.iapBattlePass, 'Battle Pass', 'Unlock premium track', Palette.nebulaPink, '\$4.99',
                      owned: player.data.battlePassPremium),
                  _header('Gem Packs'),
                  _iapTile(context, GameConfig.iapGems500, 'Pouch of Gems', '500 💎', Palette.gem, '\$4.99'),
                  _iapTile(context, GameConfig.iapGems1200, 'Bag of Gems', '1200 💎', Palette.gem, '\$9.99'),
                  _iapTile(context, GameConfig.iapGems3000, 'Chest of Gems', '3000 💎', Palette.gem, '\$19.99'),
                  _header('Convert'),
                  _convertTile(context, player),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Palette.hudYellow)),
      );

  Widget _freeGems(BuildContext context, PlayerController player) => Card(
        color: Palette.nebulaPurple.withOpacity(0.6),
        child: ListTile(
          leading: const Icon(Icons.ondemand_video, color: Colors.white),
          title: const Text('Free Gems'),
          subtitle: const Text('Watch a short video for +5 💎'),
          trailing: ElevatedButton(
            onPressed: () => AdsService.instance.showRewarded(onReward: () => player.addGems(5)),
            child: const Text('Watch'),
          ),
        ),
      );

  Widget _iapTile(BuildContext context, String id, String name, String desc, Color color, String fallbackPrice,
      {bool owned = false}) {
    final price = IapService.instance.product(id)?.price ?? fallbackPrice;
    return Card(
      color: Colors.black.withOpacity(0.45),
      child: ListTile(
        leading: Icon(Icons.diamond, color: color),
        title: Text(name),
        subtitle: Text(desc),
        trailing: owned
            ? const Text('OWNED', style: TextStyle(color: Palette.hudGreen, fontWeight: FontWeight.bold))
            : ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: color),
                onPressed: () => IapService.instance.buy(id),
                child: Text(price),
              ),
      ),
    );
  }

  Widget _convertTile(BuildContext context, PlayerController player) => Card(
        color: Colors.black.withOpacity(0.45),
        child: ListTile(
          leading: const Icon(Icons.currency_exchange, color: Palette.coin),
          title: const Text('10 💎 → 1000 🪙'),
          subtitle: const Text('Convert gems into coins'),
          trailing: ElevatedButton(
            onPressed: player.gems >= 10
                ? () {
                    if (player.spendGems(10)) player.addCoins(1000);
                  }
                : null,
            child: const Text('Convert'),
          ),
        ),
      );
}
