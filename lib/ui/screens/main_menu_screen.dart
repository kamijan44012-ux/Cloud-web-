import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/game_config.dart';
import '../../config/palette.dart';
import '../../systems/daily_reward_system.dart';
import '../../systems/player_controller.dart';
import '../widgets/currency_bar.dart';
import '../widgets/menu_button.dart';
import '../widgets/space_background.dart';
import 'game_screen.dart';
import 'hangar_screen.dart';
import 'leaderboard_screen.dart';
import 'missions_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';
import 'upgrade_screen.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowDailyReward());
  }

  void _maybeShowDailyReward() {
    final PlayerController player = context.read<PlayerController>();
    if (!DailyRewardSystem.canClaim(player)) return;
    final DailyReward? reward = DailyRewardSystem.claim(player);
    if (reward == null || !mounted) return;
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: Palette.spaceBottom,
        title: Text('Daily Reward — Day ${reward.day}'),
        content: Text(
          'Welcome back, pilot!\n\n+${reward.coins} coins'
          '${reward.gems > 0 ? '\n+${reward.gems} gems' : ''}',
          style: const TextStyle(fontSize: 16),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Collect'),
          ),
        ],
      ),
    );
  }

  void _go(Widget screen) {
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SpaceBackground(
        child: Column(
          children: <Widget>[
            const CurrencyBar(),
            const Spacer(),
            // Title.
            Column(
              children: const <Widget>[
                Text('🐔', style: TextStyle(fontSize: 64)),
                Text(
                  'CHICKEN HUNTER',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  'SPACE WAR',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Palette.hudYellow,
                    letterSpacing: 6,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: <Widget>[
                  MenuButton(
                    label: 'PLAY',
                    icon: Icons.play_arrow,
                    color: Palette.hudGreen,
                    onTap: () => _go(const GameScreen()),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: MenuButton(
                          label: 'Hangar',
                          icon: Icons.rocket_launch,
                          color: Palette.hudBlue,
                          onTap: () => _go(const HangarScreen()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: MenuButton(
                          label: 'Upgrades',
                          icon: Icons.bolt,
                          color: Palette.nebulaPurple,
                          onTap: () => _go(const UpgradeScreen()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: MenuButton(
                          label: 'Shop',
                          icon: Icons.shopping_cart,
                          color: Palette.coin,
                          onTap: () => _go(const ShopScreen()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: MenuButton(
                          label: 'Missions',
                          icon: Icons.flag,
                          color: Palette.chickenKamikaze,
                          onTap: () => _go(const MissionsScreen()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: MenuButton(
                          label: 'Ranks',
                          icon: Icons.leaderboard,
                          color: Palette.nebulaPink,
                          onTap: () => _go(const LeaderboardScreen()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: MenuButton(
                          label: 'Settings',
                          icon: Icons.settings,
                          color: Colors.blueGrey,
                          onTap: () => _go(const SettingsScreen()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text('v${GameConfig.version}',
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
