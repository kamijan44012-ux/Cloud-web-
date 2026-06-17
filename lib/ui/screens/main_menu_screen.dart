import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/game_config.dart';
import '../../config/palette.dart';
import '../../services/auth_service.dart';
import '../../services/referral_service.dart';
import '../../systems/daily_reward_system.dart';
import '../../systems/player_controller.dart';
import '../widgets/currency_bar.dart';
import '../widgets/menu_button.dart';
import '../widgets/profile_avatar_button.dart';
import '../widgets/space_background.dart';
import 'admin_panel_screen.dart';
import 'coin_request_screen.dart';
import 'game_screen.dart';
import 'hangar_screen.dart';
import 'invite_screen.dart';
import 'pvp_lobby_screen.dart';
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

  Future<void> _openAdminPanel() async {
    final TextEditingController pwCtrl = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: const Color(0xFF12122A),
        title: const Text('Admin Panel',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: pwCtrl,
          obscureText: true,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Password',
            labelStyle: const TextStyle(color: Colors.white60),
            filled: true,
            fillColor: Colors.white.withOpacity(0.08),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enter')),
        ],
      ),
    );
    if (!mounted || ok != true) return;
    if (!AuthService.instance.checkAdminPanelPassword(pwCtrl.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incorrect password.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    _go(const AdminPanelScreen());
  }

  /// Shows the Mobile / Desktop mode picker before launching a game screen.
  Future<bool?> _pickMode() async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: Palette.spaceBottom,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: <Widget>[
            Icon(Icons.devices, color: Palette.hudYellow, size: 22),
            SizedBox(width: 8),
            Text(
              'Choose Display Mode',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'How should the game fit your screen?',
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                Expanded(
                  child: _ModeButton(
                    icon: Icons.smartphone,
                    label: 'Mobile',
                    description: 'Portrait\nphone ratio',
                    color: Palette.hudGreen,
                    onTap: () => Navigator.pop(ctx, true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ModeButton(
                    icon: Icons.desktop_windows,
                    label: 'Desktop',
                    description: 'Full\nscreen',
                    color: Palette.hudBlue,
                    onTap: () => Navigator.pop(ctx, false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startPlay() async {
    final bool? mobile = await _pickMode();
    if (!mounted || mobile == null) return;
    _go(GameScreen(mobileMode: mobile));
  }

  Future<void> _startVs() async {
    final bool? mobile = await _pickMode();
    if (!mounted || mobile == null) return;
    _go(PvpLobbyScreen(mobileMode: mobile));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: IntrinsicHeight(
                child: Column(
                  children: <Widget>[
                    const CurrencyBar(leading: ProfileAvatarButton()),
                    const SizedBox(height: 32),
                    // Title
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
                    const SizedBox(height: 32),
                    // Buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        children: <Widget>[
                          MenuButton(
                            label: 'PLAY',
                            icon: Icons.play_arrow,
                            color: Palette.hudGreen,
                            onTap: _startPlay,
                          ),
                          const SizedBox(height: 12),
                          MenuButton(
                            label: 'VS MODE',
                            icon: Icons.people,
                            color: Palette.hudRed,
                            subtitle: '1v1 Online — Winner gets 100 coins',
                            onTap: _startVs,
                          ),
                          const SizedBox(height: 12),
                          MenuButton(
                            label: 'Invite Friends',
                            icon: Icons.card_giftcard,
                            color: Palette.hudGreen,
                            subtitle: 'Earn ${ReferralService.inviterBonus} coins per friend',
                            onTap: () => _go(const InviteScreen()),
                          ),
                          const SizedBox(height: 12),
                          MenuButton(
                            label: 'Request Coins',
                            icon: Icons.monetization_on,
                            color: Palette.coin,
                            subtitle: 'Ask admin for free coins',
                            onTap: () => _go(const CoinRequestScreen()),
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
                    const SizedBox(height: 24),
                    GestureDetector(
                      onLongPress: _openAdminPanel,
                      child: Text('v${GameConfig.version}',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.4), fontSize: 12)),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.6), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
