import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/palette.dart';
import '../../systems/player_controller.dart';

/// Top-of-screen wallet showing coins, gems and player level. Reactively
/// rebuilds whenever the [PlayerController] changes.
class CurrencyBar extends StatelessWidget {
  const CurrencyBar({super.key, this.showLevel = true, this.leading});
  final bool showLevel;

  /// Optional widget shown at the far left (e.g. a profile avatar button).
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final PlayerController player = context.watch<PlayerController>();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: <Widget>[
            if (leading != null) ...<Widget>[
              leading!,
              const SizedBox(width: 8),
            ],
            if (showLevel) ...<Widget>[
              _Pill(
                color: Palette.xp,
                icon: Icons.military_tech,
                label: 'Lv ${player.level}',
              ),
              const Spacer(),
            ],
            _Pill(color: Palette.coin, icon: Icons.monetization_on, label: '${player.coins}'),
            const SizedBox(width: 8),
            _Pill(color: Palette.gem, icon: Icons.diamond, label: '${player.gems}'),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.color, required this.icon, required this.label});
  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.7), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
