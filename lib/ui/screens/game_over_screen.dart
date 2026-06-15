import 'package:flutter/material.dart';

import '../../config/palette.dart';
import '../../game/chicken_hunter_game.dart';
import '../../services/ads_service.dart';
import '../widgets/menu_button.dart';

/// The post-run overlay. Shows the run summary and offers: revive (rewarded
/// ad), double coins (rewarded ad), retry, and back to menu. Rendered inside
/// the game screen's Stack so the frozen battlefield shows behind it.
class GameOverOverlay extends StatefulWidget {
  const GameOverOverlay({
    super.key,
    required this.result,
    required this.onRetry,
    required this.onMenu,
    this.onRevive,
  });

  final RunResult result;
  final VoidCallback onRetry;
  final VoidCallback onMenu;
  final VoidCallback? onRevive;

  @override
  State<GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<GameOverOverlay> {
  bool _doubled = false;

  @override
  Widget build(BuildContext context) {
    final RunResult r = widget.result;
    return Container(
      color: Colors.black.withOpacity(0.78),
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('GAME OVER',
                    style: TextStyle(
                        fontSize: 36, fontWeight: FontWeight.w900, color: Palette.hudRed)),
                const SizedBox(height: 16),
                _stat('Score', '${r.score}', Palette.hudYellow),
                _stat('Wave reached', '${r.wave}', Palette.nebulaPink),
                _stat('Chickens hunted', '${r.kills}', Palette.hudGreen),
                _stat('Bosses defeated', '${r.bossKills}', Palette.chickenBoss),
                _stat('Coins earned', '${_doubled ? r.coins * 2 : r.coins}', Palette.coin),
                _stat('XP gained', '${r.xp}', Palette.xp),
                const SizedBox(height: 24),
                if (widget.onRevive != null)
                  MenuButton(
                    label: 'REVIVE',
                    subtitle: 'Watch ad to continue',
                    icon: Icons.favorite,
                    color: Palette.hudGreen,
                    onTap: widget.onRevive!,
                  ),
                if (!_doubled) ...<Widget>[
                  const SizedBox(height: 12),
                  MenuButton(
                    label: 'DOUBLE COINS',
                    subtitle: 'Watch ad for 2x',
                    icon: Icons.ondemand_video,
                    color: Palette.coin,
                    onTap: () => AdsService.instance.showRewarded(
                      onReward: () => setState(() => _doubled = true),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: MenuButton(
                          label: 'Retry',
                          icon: Icons.replay,
                          color: Palette.hudBlue,
                          onTap: widget.onRetry),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MenuButton(
                          label: 'Menu',
                          icon: Icons.home,
                          color: Palette.nebulaPurple,
                          onTap: widget.onMenu),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(label, style: const TextStyle(fontSize: 16, color: Colors.white70)),
            Text(value,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      );
}
