import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../config/palette.dart';
import '../models/pvp_match.dart';
import '../models/ship_data.dart';
import '../models/weapon_data.dart';
import '../services/audio_service.dart';
import '../services/pvp_service.dart';
import '../systems/player_controller.dart';
import 'components/bullets/bullet.dart';
import 'components/effects/explosion.dart';
import 'components/effects/floating_text.dart';
import 'components/nebula_background.dart';
import 'components/pvp_opponent_ship.dart';
import 'components/pvp_player_ship.dart';
import 'components/star_field.dart';
import 'sprite_catalog.dart';

enum PvpState { playing, over }

enum PvpOutcome { win, lose }

/// Top-level Flame game for 1v1 online PvP. No enemies or waves — two real
/// players face each other:
///  • My ship sits at the bottom, firing upward.
///  • Opponent ship appears at the top (rotated 180°), firing downward.
/// Positions and bullet-fire events are synced via Firestore (~7 fps).
/// The first player whose health reaches 0 loses; the winner earns 100 coins.
class PvpGame extends FlameGame with DragCallbacks, HasCollisionDetection {
  PvpGame({
    required this.player,
    required this.roomCode,
    required this.isHost,
    required this.opponentName,
    required this.opponentShipId,
    required this.onMatchOver,
  });

  final PlayerController player;
  final String roomCode;
  final bool isHost;
  final String opponentName;
  final String opponentShipId;
  final void Function(PvpOutcome outcome) onMatchOver;

  // HUD-facing notifiers
  final ValueNotifier<double> myHealthFraction = ValueNotifier<double>(1.0);
  final ValueNotifier<double> opponentHealthFraction = ValueNotifier<double>(1.0);
  final ValueNotifier<PvpState> state = ValueNotifier<PvpState>(PvpState.playing);
  final ValueNotifier<String> banner = ValueNotifier<String>('');

  /// True while the pre-match countdown is running — blocks all input and sync.
  final ValueNotifier<bool> frozen = ValueNotifier<bool>(true);

  /// Normalised joystick direction set by the Flutter HUD overlay (-1..1 each axis).
  final ValueNotifier<Offset> joystickDir = ValueNotifier<Offset>(Offset.zero);

  late PvpPlayerShip _myShip;
  late PvpOpponentShip _opponentShip;

  // Last known opponent state from Firestore
  double _oppX = 270;
  double _oppY = 760;
  double _oppHealth = 100;
  int _oppBulletCount = 0;

  double _syncTimer = 0;
  static const double _syncInterval = 0.14; // ~7 fps Firestore writes

  StreamSubscription<Map<String, dynamic>>? _stateSub;
  StreamSubscription<PvpRoom?>? _roomSub;

  late WeaponType equippedWeapon;
  late int weaponLevel;

  double _shake = 0;
  final Random _rng = Random();
  bool _matchEnded = false;

  @override
  Color backgroundColor() => Palette.spaceTop;

  void shake(double intensity) => _shake = max(_shake, intensity);

  @override
  void render(Canvas canvas) {
    if (_shake > 0.2) {
      final double dx = (_rng.nextDouble() * 2 - 1) * _shake;
      final double dy = (_rng.nextDouble() * 2 - 1) * _shake;
      canvas.save();
      canvas.translate(dx, dy);
      super.render(canvas);
      canvas.restore();
    } else {
      super.render(canvas);
    }
  }

  @override
  Future<void> onLoad() async {
    equippedWeapon = player.data.equippedWeapon;
    weaponLevel = player.data.weaponLevel(equippedWeapon).clamp(1, 99);

    final ShipData myShipData = ShipData.byId(player.data.selectedShipId);
    final double healthBonus = 1 + player.data.shipUpgradeLevel('health') * 0.1;
    final double myMaxHp = myShipData.baseHealth * healthBonus;

    final ShipData oppShipData = ShipData.byId(opponentShipId);

    await SpriteCatalog.instance.load(images);

    add(NebulaBackground());
    add(StarField(areaSize: size));

    _myShip = PvpPlayerShip(ship: myShipData, maxHealth: myMaxHp);
    add(_myShip);

    _opponentShip = PvpOpponentShip(
        ship: oppShipData, maxHealth: oppShipData.baseHealth);
    _opponentShip.displayName = opponentName;
    _oppHealth = oppShipData.baseHealth;
    add(_opponentShip);

    AudioService.instance.startMusic();
    _subscribe();
  }

  void _subscribe() {
    _stateSub =
        PvpService.instance.listenToGameState(roomCode).listen(_onStateUpdate);
    _roomSub = PvpService.instance.listenToRoom(roomCode).listen((PvpRoom? room) {
      if (room == null) return;
      if (room.status == PvpStatus.finished && state.value != PvpState.over) {
        _handleMatchOver(room.winner ?? (isHost ? 'guest' : 'host'));
      }
    });
  }

  void _onStateUpdate(Map<String, dynamic> data) {
    if (state.value != PvpState.playing) return;
    final String opp = isHost ? 'g' : 'h';
    final String my = isHost ? 'h' : 'g';

    // Opponent position
    _oppX = (data['${opp}_x'] as num?)?.toDouble() ?? _oppX;
    _oppY = (data['${opp}_y'] as num?)?.toDouble() ?? _oppY;
    if (_opponentShip.isLoaded) {
      _opponentShip.updateFromSync(_oppX, _oppY);
    }

    // Opponent health (written by us when we deal damage; cross-checked here)
    final double newOppHp =
        (data['${opp}_hp'] as num?)?.toDouble() ?? _oppHealth;
    if (newOppHp != _oppHealth) {
      _oppHealth = newOppHp;
      _opponentShip.health = newOppHp;
      opponentHealthFraction.value =
          (_oppHealth / _opponentShip.maxHealth).clamp(0.0, 1.0);
      if (_oppHealth <= 0 && state.value == PvpState.playing) {
        _endMatch(winner: isHost ? 'host' : 'guest');
      }
    }

    // Spawn bullets whenever opponent's fire count increases
    final int newFired = (data['${opp}_fired'] as int?) ?? 0;
    if (newFired > _oppBulletCount) {
      final int newShots = (newFired - _oppBulletCount).clamp(0, 6);
      for (int i = 0; i < newShots; i++) {
        _spawnOpponentBullet();
      }
      _oppBulletCount = newFired;
    }

    // My health as seen by Firestore (opponent may have written damage to it)
    final double remoteMyHp =
        (data['${my}_hp'] as num?)?.toDouble() ?? _myShip.health;
    if (remoteMyHp < _myShip.health && _myShip.isAlive) {
      _myShip.health = remoteMyHp.clamp(0, _myShip.maxHealth);
      myHealthFraction.value =
          (_myShip.health / _myShip.maxHealth).clamp(0.0, 1.0);
      shake(6);
      if (_myShip.health <= 0 && state.value == PvpState.playing) {
        _endMatch(winner: isHost ? 'guest' : 'host');
      }
    }
  }

  void _spawnOpponentBullet() {
    if (!_opponentShip.isLoaded) return;
    add(Bullet(
      position:
          _opponentShip.position.clone() + Vector2(0, _opponentShip.size.y / 2),
      velocity: Vector2(0, 380),
      damage: 10,
      team: BulletTeam.enemy,
      color: Colors.redAccent,
      radius: 5,
    ));
  }

  // ---------------------------------------------------------------------------
  // Drag controls
  // ---------------------------------------------------------------------------
  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (frozen.value || state.value != PvpState.playing) return;
    if (joystickDir.value != Offset.zero) return; // joystick takes priority
    _myShip.targetPosition = event.canvasEndPosition;
  }

  @override
  void onDragStart(DragStartEvent event) {
    if (frozen.value || state.value != PvpState.playing) return;
    if (joystickDir.value != Offset.zero) return; // joystick takes priority
    _myShip.targetPosition = event.canvasPosition;
  }

  // ---------------------------------------------------------------------------
  // Main loop
  // ---------------------------------------------------------------------------
  @override
  void update(double dt) {
    super.update(dt);
    if (frozen.value || state.value != PvpState.playing) return;

    if (_shake > 0) _shake = max(0, _shake - dt * 45);

    // Joystick relative movement
    final Offset jDir = joystickDir.value;
    if (jDir != Offset.zero && _myShip.isLoaded) {
      const double speed = 720.0;
      _myShip.targetPosition.x = (_myShip.position.x + jDir.dx * speed * dt)
          .clamp(_myShip.size.x / 2, size.x - _myShip.size.x / 2);
      _myShip.targetPosition.y = (_myShip.position.y + jDir.dy * speed * dt)
          .clamp(size.y * 0.55, size.y - _myShip.size.y / 2 - 20);
    }

    myHealthFraction.value =
        (_myShip.health / _myShip.maxHealth).clamp(0.0, 1.0);

    _syncTimer += dt;
    if (_syncTimer >= _syncInterval) {
      _syncTimer = 0;
      _pushState();
    }

    _checkHits();
  }

  /// Distance-based hit detection — no Flame collision system needed.
  void _checkHits() {
    final List<Bullet> toRemove = <Bullet>[];

    for (final Bullet b in children.whereType<Bullet>()) {
      if (b.team == BulletTeam.player && _opponentShip.isLoaded) {
        if (b.position.distanceTo(_opponentShip.position) < 28) {
          _oppHealth =
              (_oppHealth - b.damage).clamp(0.0, _opponentShip.maxHealth);
          _opponentShip.health = _oppHealth;
          opponentHealthFraction.value =
              (_oppHealth / _opponentShip.maxHealth).clamp(0.0, 1.0);
          add(FloatingText(
            position: _opponentShip.position.clone(),
            text: '-${b.damage.round()}',
            color: Palette.chickenKamikaze,
          ));
          toRemove.add(b);
          shake(3);

          if (_oppHealth <= 0 && state.value == PvpState.playing) {
            _endMatch(winner: isHost ? 'host' : 'guest');
          }
        }
      } else if (b.team == BulletTeam.enemy &&
          _myShip.isLoaded &&
          _myShip.isAlive) {
        if (b.position.distanceTo(_myShip.position) < 28) {
          _myShip.takeDamage(b.damage);
          toRemove.add(b);
        }
      }
    }

    for (final Bullet b in toRemove) {
      b.removeFromParent();
    }
  }

  Future<void> _pushState() async {
    if (state.value != PvpState.playing) return;
    await PvpService.instance.syncHealth(
      code: roomCode,
      isHost: isHost,
      myHealth: _myShip.health,
      opponentHealth: _oppHealth,
    );
    await PvpService.instance.updatePosition(
      code: roomCode,
      isHost: isHost,
      x: _myShip.position.x,
      y: _myShip.position.y,
    );
  }

  // ---------------------------------------------------------------------------
  // Called by PvpPlayerShip when it fires a bullet
  // ---------------------------------------------------------------------------
  void spawnPlayerBullet(Bullet bullet) {
    add(bullet);
    // Fire-and-forget increment so the opponent sees the bullet
    PvpService.instance
        .incrementBulletCount(code: roomCode, isHost: isHost);
  }

  void onPlayerDamaged() {
    myHealthFraction.value =
        (_myShip.health / _myShip.maxHealth).clamp(0.0, 1.0);
    if (!_myShip.isAlive && state.value == PvpState.playing) {
      _endMatch(winner: isHost ? 'guest' : 'host');
    }
  }

  // ---------------------------------------------------------------------------
  // Match lifecycle
  // ---------------------------------------------------------------------------
  void _endMatch({required String winner}) {
    if (_matchEnded) return;
    _matchEnded = true;
    PvpService.instance.endMatch(code: roomCode, winner: winner);
    _handleMatchOver(winner);
  }

  void _handleMatchOver(String winner) {
    if (state.value == PvpState.over) return;
    state.value = PvpState.over;
    AudioService.instance.stopMusic();
    _stateSub?.cancel();
    _roomSub?.cancel();

    final bool isWinner =
        (winner == 'host' && isHost) || (winner == 'guest' && !isHost);
    final PvpOutcome outcome =
        isWinner ? PvpOutcome.win : PvpOutcome.lose;

    if (isWinner) {
      add(Explosion(
        position: _opponentShip.isLoaded
            ? _opponentShip.position.clone()
            : size / 2,
        color: Palette.hudYellow,
        particleCount: 40,
        maxRadius: 80,
        lifetime: 0.9,
      ));
      shake(18);
    }

    banner.value = isWinner ? 'YOU WIN!' : 'YOU LOSE';
    Future<void>.delayed(const Duration(seconds: 2), () => onMatchOver(outcome));
  }

  @override
  void onRemove() {
    _stateSub?.cancel();
    _roomSub?.cancel();
    super.onRemove();
  }
}
