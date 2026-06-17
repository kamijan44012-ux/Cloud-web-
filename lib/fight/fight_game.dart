import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Color, Colors;
import 'package:flutter/services.dart';

import '../services/audio_service.dart';
import 'fight_data.dart';
import 'components/fight_arena.dart';
import 'components/fighter_component.dart';
import 'components/fight_hud.dart';
import 'components/hit_spark.dart';
import 'ai/fight_bot.dart';

class FightGame extends FlameGame with KeyboardEvents {
  FightGame({
    required this.gameMode,
    required this.p1Character,
    required this.p2Character,
    this.onMatchEnd,
  });

  final GameMode gameMode;
  final CharacterData p1Character;
  final CharacterData p2Character;
  final void Function(bool p1Won, String winnerName)? onMatchEnd;

  static const double gameWidth = 720;
  static const double gameHeight = 340;
  static const double groundY = 300;

  late FighterComponent p1;
  late FighterComponent p2;
  late FightHud hud;
  FightBot? bot;

  // Round state
  FightPhase phase = FightPhase.countdown;
  double countdownTimer = 3.6;
  int countdownValue = 3;
  int p1Wins = 0;
  int p2Wins = 0;
  int currentRound = 1;
  double roundTimer = 99.0;
  double roundPauseTimer = 0;
  String roundMessage = '';

  final Set<LogicalKeyboardKey> _keys = <LogicalKeyboardKey>{};

  @override
  Color backgroundColor() => const Color(0xFF000000);

  @override
  Future<void> onLoad() async {
    camera.viewfinder.visibleGameSize = Vector2(gameWidth, gameHeight);

    await add(FightArena());

    p1 = FighterComponent(
      characterData: p1Character,
      isP1: true,
      facingRight: true,
    );
    p2 = FighterComponent(
      characterData: p2Character,
      isP1: false,
      facingRight: false,
    );
    await add(p1);
    await add(p2);

    hud = FightHud(this);
    await add(hud);

    if (gameMode == GameMode.vsBot) {
      bot = FightBot(fighter: p2, opponent: p1, game: this);
    }

    _resetPositions();
    _startCountdown();
  }

  void _resetPositions() {
    p1.position = Vector2(200, groundY);
    p2.position = Vector2(520, groundY);
    p1.velocity = Vector2.zero();
    p2.velocity = Vector2.zero();
    p1.facingRight = true;
    p2.facingRight = false;
  }

  void _startCountdown() {
    phase = FightPhase.countdown;
    countdownTimer = 3.6;
    countdownValue = 3;
    p1.resetToIdle();
    p2.resetToIdle();
  }

  @override
  void update(double dt) {
    super.update(dt);
    switch (phase) {
      case FightPhase.countdown:
        _updateCountdown(dt);
      case FightPhase.fighting:
        _updateFighting(dt);
      case FightPhase.roundPause:
        _updateRoundPause(dt);
      case FightPhase.gameOver:
        break;
    }
  }

  void _updateCountdown(double dt) {
    countdownTimer -= dt;
    final int newVal = max(0, countdownTimer.ceil());
    if (newVal != countdownValue) {
      countdownValue = newVal;
      if (newVal > 0) AudioService.instance.playCountdownBeep();
    }
    if (countdownTimer <= 0) {
      phase = FightPhase.fighting;
      roundTimer = 99.0;
      countdownValue = 0;
      AudioService.instance.playFightStart();
    }
  }

  void _updateFighting(double dt) {
    if (p1.health <= 0 || p2.health <= 0 || roundTimer <= 0) {
      _endRound();
      return;
    }

    roundTimer -= dt;
    _handleKeyboardInput();
    bot?.update(dt);

    p1.fightUpdate(dt, opponent: p2);
    p2.fightUpdate(dt, opponent: p1);

    _resolveOverlap();
    _updateFacing();
    _checkHits();
  }

  void _resolveOverlap() {
    const double minDist = 56.0;
    final double dx = p2.position.x - p1.position.x;
    if (dx.abs() < minDist) {
      final double push = (minDist - dx.abs()) / 2 + 1;
      if (p1.position.x <= p2.position.x) {
        p1.position.x -= push;
        p2.position.x += push;
      } else {
        p1.position.x += push;
        p2.position.x -= push;
      }
      p1.position.x = p1.position.x.clamp(40, gameWidth - 40);
      p2.position.x = p2.position.x.clamp(40, gameWidth - 40);
    }
  }

  void _updateFacing() {
    if (!p1.isAttacking && p1.currentAction != FighterAction.knockdown) {
      p1.facingRight = p1.position.x < p2.position.x;
    }
    if (!p2.isAttacking && p2.currentAction != FighterAction.knockdown) {
      p2.facingRight = p2.position.x < p1.position.x;
    }
  }

  void _checkHits() {
    // P1 → P2
    if (p1.isAttacking) {
      final Rect? box = p1.currentAttackHitbox;
      if (box != null && !p1.hitRegisteredThisSwing) {
        final Rect hurt = p2.worldHurtbox;
        if (box.overlaps(hurt)) {
          p1.hitRegisteredThisSwing = true;
          final bool blocked = p2.isBlocking;
          final double dmg =
              p1.currentAttackDamage * (blocked ? 0.18 : 1.0);
          p2.takeDamage(dmg, blocked: blocked);
          add(HitSpark(position: Vector2(box.center.dx, box.center.dy), blocked: blocked));
          _playHitSound(p1.currentAction, blocked: blocked);
        }
      }
    }

    // P2 → P1
    if (p2.isAttacking) {
      final Rect? box = p2.currentAttackHitbox;
      if (box != null && !p2.hitRegisteredThisSwing) {
        final Rect hurt = p1.worldHurtbox;
        if (box.overlaps(hurt)) {
          p2.hitRegisteredThisSwing = true;
          final bool blocked = p1.isBlocking;
          final double dmg =
              p2.currentAttackDamage * (blocked ? 0.18 : 1.0);
          p1.takeDamage(dmg, blocked: blocked);
          add(HitSpark(position: Vector2(box.center.dx, box.center.dy), blocked: blocked));
          _playHitSound(p2.currentAction, blocked: blocked);
        }
      }
    }
  }

  void _playHitSound(FighterAction action, {required bool blocked}) {
    if (blocked) {
      AudioService.instance.playBlock();
    } else {
      switch (action) {
        case FighterAction.punchLight:
          AudioService.instance.playPunchLight();
        case FighterAction.punchHeavy:
          AudioService.instance.playPunchHeavy();
        case FighterAction.kickLight:
          AudioService.instance.playKickLight();
        case FighterAction.kickHeavy:
          AudioService.instance.playKickHeavy();
        default:
          AudioService.instance.playPunchLight();
      }
    }
  }

  void _endRound() {
    phase = FightPhase.roundPause;
    roundPauseTimer = 3.2;

    if (p1.health <= 0 && p2.health <= 0) {
      p1Wins++;
      p2Wins++;
      roundMessage = 'DRAW!';
    } else if (p2.health <= 0 || (roundTimer <= 0 && p1.health >= p2.health)) {
      p1Wins++;
      roundMessage = p2.health <= 0 ? 'K.O.!\nP1 WINS' : 'TIME!\nP1 WINS';
      p1.setVictory();
      p2.setKnockdown();
      AudioService.instance.playKo();
    } else {
      p2Wins++;
      roundMessage = p1.health <= 0 ? 'K.O.!\nP2 WINS' : 'TIME!\nP2 WINS';
      p2.setVictory();
      p1.setKnockdown();
      AudioService.instance.playKo();
    }
  }

  void _updateRoundPause(double dt) {
    roundPauseTimer -= dt;
    if (roundPauseTimer > 0) return;

    if (p1Wins >= 2 || p2Wins >= 2) {
      phase = FightPhase.gameOver;
      final bool p1Won = p1Wins >= 2;
      roundMessage =
          '${p1Won ? p1Character.name : p2Character.name}\nWINS THE MATCH!';
      onMatchEnd?.call(p1Won, p1Won ? p1Character.name : p2Character.name);
    } else {
      currentRound++;
      p1.resetHealth();
      p2.resetHealth();
      _resetPositions();
      _startCountdown();
    }
  }

  void _handleKeyboardInput() {
    // P1: arrow keys + space (block)
    p1.inputLeft = _keys.contains(LogicalKeyboardKey.arrowLeft);
    p1.inputRight = _keys.contains(LogicalKeyboardKey.arrowRight);
    p1.inputJump = _keys.contains(LogicalKeyboardKey.arrowUp);
    p1.inputCrouch = _keys.contains(LogicalKeyboardKey.arrowDown);
    p1.inputBlock = _keys.contains(LogicalKeyboardKey.space);

    // P2 (vsPlayer): WASD + P (block)
    if (gameMode == GameMode.vsPlayer) {
      p2.inputLeft = _keys.contains(LogicalKeyboardKey.keyA);
      p2.inputRight = _keys.contains(LogicalKeyboardKey.keyD);
      p2.inputJump = _keys.contains(LogicalKeyboardKey.keyW);
      p2.inputCrouch = _keys.contains(LogicalKeyboardKey.keyS);
      p2.inputBlock = _keys.contains(LogicalKeyboardKey.keyP);
    }
  }

  // Touch-driven attack methods
  void p1PunchLight() {
    if (phase == FightPhase.fighting) p1.doAttack(FighterAction.punchLight);
  }
  void p1PunchHeavy() {
    if (phase == FightPhase.fighting) p1.doAttack(FighterAction.punchHeavy);
  }
  void p1KickLight() {
    if (phase == FightPhase.fighting) p1.doAttack(FighterAction.kickLight);
  }
  void p1KickHeavy() {
    if (phase == FightPhase.fighting) p1.doAttack(FighterAction.kickHeavy);
  }
  void p2PunchLight() {
    if (phase == FightPhase.fighting) p2.doAttack(FighterAction.punchLight);
  }
  void p2PunchHeavy() {
    if (phase == FightPhase.fighting) p2.doAttack(FighterAction.punchHeavy);
  }
  void p2KickLight() {
    if (phase == FightPhase.fighting) p2.doAttack(FighterAction.kickLight);
  }
  void p2KickHeavy() {
    if (phase == FightPhase.fighting) p2.doAttack(FighterAction.kickHeavy);
  }

  @override
  KeyEventResult onKeyEvent(
      KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    _keys
      ..clear()
      ..addAll(keysPressed);

    if (event is KeyDownEvent && phase == FightPhase.fighting) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.keyZ:
          p1PunchLight();
        case LogicalKeyboardKey.keyX:
          p1PunchHeavy();
        case LogicalKeyboardKey.keyC:
          p1KickLight();
        case LogicalKeyboardKey.keyV:
          p1KickHeavy();
      }
      if (gameMode == GameMode.vsPlayer) {
        switch (event.logicalKey) {
          case LogicalKeyboardKey.keyU:
            p2PunchLight();
          case LogicalKeyboardKey.keyI:
            p2PunchHeavy();
          case LogicalKeyboardKey.keyJ:
            p2KickLight();
          case LogicalKeyboardKey.keyK:
            p2KickHeavy();
        }
      }
    }
    return KeyEventResult.handled;
  }
}
