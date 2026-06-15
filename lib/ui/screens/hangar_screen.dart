import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/palette.dart';
import '../../models/ship_data.dart';
import '../../systems/player_controller.dart';
import '../widgets/currency_bar.dart';
import '../widgets/space_background.dart';

/// Ship hangar: browse, unlock (coins or gems) and select your spaceship.
class HangarScreen extends StatelessWidget {
  const HangarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final PlayerController player = context.watch<PlayerController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Hangar'), backgroundColor: Colors.transparent),
      extendBodyBehindAppBar: true,
      body: SpaceBackground(
        child: Column(
          children: <Widget>[
            const CurrencyBar(),
            Expanded(
              child: GridView.count(
                padding: const EdgeInsets.all(16),
                crossAxisCount: 2,
                childAspectRatio: 0.74,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: ShipData.all
                    .map((ShipData s) => _ShipCard(ship: s, player: player))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShipCard extends StatelessWidget {
  const _ShipCard({required this.ship, required this.player});
  final ShipData ship;
  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    final bool unlocked = player.isShipUnlocked(ship.id);
    final bool selected = player.data.selectedShipId == ship.id;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? Palette.hudGreen : ship.color.withOpacity(0.6), width: 2),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: <Widget>[
          Expanded(child: CustomPaint(painter: _ShipPainter(ship.color), size: const Size(60, 70))),
          Text(ship.name, style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          Text(ship.description,
              style: const TextStyle(fontSize: 10, color: Colors.white60),
              textAlign: TextAlign.center,
              maxLines: 2),
          const SizedBox(height: 6),
          if (!unlocked)
            ElevatedButton(
              onPressed: () {
                final bool ok = player.unlockShip(ship);
                if (!ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Not enough currency!')),
                  );
                }
              },
              child: Text(ship.unlockCostGems > 0
                  ? '${ship.unlockCostGems} 💎'
                  : '${ship.unlockCostCoins} 🪙'),
            )
          else
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: selected ? Palette.hudGreen : null,
              ),
              onPressed: selected ? null : () => player.selectShip(ship.id),
              child: Text(selected ? 'Selected' : 'Select'),
            ),
        ],
      ),
    );
  }
}

/// Draws the ship silhouette so each card previews the actual in-game look.
class _ShipPainter extends CustomPainter {
  _ShipPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width, h = size.height;
    final Path hull = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w * 0.92, h * 0.78)
      ..lineTo(w * 0.5, h * 0.62)
      ..lineTo(w * 0.08, h * 0.78)
      ..close();
    canvas.drawPath(hull, Paint()..color = color);
    canvas.drawCircle(Offset(w * 0.5, h * 0.34), 6, Paint()..color = Palette.hudBlue);
  }

  @override
  bool shouldRepaint(_ShipPainter old) => old.color != color;
}
