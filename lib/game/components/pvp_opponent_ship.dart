import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../models/ship_data.dart';
import '../pvp_game.dart';
import '../sprite_catalog.dart';

/// The remote opponent's ship. Its position is driven by Firestore sync via
/// [updateFromSync], converting the opponent's local Y into our inverted Y so
/// it appears at the top of the screen facing downward.
class PvpOpponentShip extends PositionComponent with HasGameReference<PvpGame> {
  PvpOpponentShip({required this.ship, required this.maxHealth})
      : health = maxHealth,
        super(anchor: Anchor.center, size: Vector2(64, 64));

  final ShipData ship;
  final double maxHealth;
  double health;
  String displayName = '';

  Vector2 _syncTarget = Vector2.zero();
  double _thrust = 0;

  late Sprite _hull;
  late double _hullAspect;

  @override
  Future<void> onLoad() async {
    _hull = SpriteCatalog.instance.ship(ship.id);
    _hullAspect = _hull.srcSize.y / _hull.srcSize.x;
    position = Vector2(game.size.x / 2, game.size.y * 0.18);
    _syncTarget = position.clone();
  }

  /// Convert the opponent's own-device Y (near screen bottom) into our Y
  /// (near screen top) so the two ships face each other.
  void updateFromSync(double opponentX, double opponentY) {
    _syncTarget = Vector2(opponentX, game.size.y - opponentY);
  }

  @override
  void update(double dt) {
    _thrust += dt * 12;
    final Vector2 delta = _syncTarget - position;
    position += delta * min(1.0, dt * 6);
    position.x = position.x.clamp(size.x / 2, game.size.x - size.x / 2);
    // Keep opponent in upper 45 % of screen
    position.y = position.y.clamp(size.y / 2, game.size.y * 0.45);
  }

  @override
  void render(Canvas canvas) {
    final double w = size.x, h = size.y;
    final Offset c = Offset(w / 2, h / 2);
    final double hullW = w;
    final double hullH = hullW * _hullAspect;

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(pi); // face downward toward the player

    final Sprite thr = (_thrust * 0.6).floor().isEven
        ? SpriteCatalog.instance.thruster0
        : SpriteCatalog.instance.thruster1;
    final double tA = thr.srcSize.y / thr.srcSize.x;
    const double tw = 9;
    final double th = tw * tA;
    for (final double ex in <double>[-hullW * 0.16, hullW * 0.16]) {
      canvas.save();
      canvas.translate(ex, hullH * 0.42);
      canvas.rotate(pi);
      thr.render(canvas, position: Vector2(-tw / 2, -th / 2), size: Vector2(tw, th));
      canvas.restore();
    }

    _hull.render(canvas,
        position: Vector2(-hullW / 2, -hullH / 2), size: Vector2(hullW, hullH));

    if (health / maxHealth < 0.4) {
      SpriteCatalog.instance.playerDamage.render(canvas,
          position: Vector2(-hullW / 2, -hullH / 2), size: Vector2(hullW, hullH));
    }

    canvas.restore();
  }
}
