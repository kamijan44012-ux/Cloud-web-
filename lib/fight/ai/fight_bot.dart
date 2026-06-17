import 'dart:math';
import '../fight_data.dart';
import '../fight_game.dart';
import '../components/fighter_component.dart';

/// Simple bot AI controller for the CPU opponent.
enum _BotState { approach, attackCombo, retreat, block, jump }

class FightBot {
  FightBot({
    required this.fighter,
    required this.opponent,
    required this.game,
  });

  final FighterComponent fighter;
  final FighterComponent opponent;
  final FightGame game;

  final Random _rng = Random();
  _BotState _state = _BotState.approach;
  double _stateTimer = 0;
  double _reactionDelay = 0;
  int _comboStep = 0;

  static const double _attackRange = 110;
  static const double _closeRange = 70;

  void update(double dt) {
    if (game.phase != FightPhase.fighting) return;
    if (fighter.currentAction == FighterAction.knockdown ||
        fighter.currentAction == FighterAction.getUp ||
        fighter.currentAction == FighterAction.victory ||
        fighter.currentAction == FighterAction.defeat) {
      return;
    }

    _stateTimer -= dt;
    _reactionDelay -= dt;

    final double dist =
        (fighter.position.x - opponent.position.x).abs();
    final bool inRange = dist < _attackRange;
    final bool tooClose = dist < _closeRange;

    // React to opponent attacking
    if (_reactionDelay <= 0 && opponent.isAttacking) {
      _reactionDelay = 0.06 + _rng.nextDouble() * 0.08;
      if (inRange && _rng.nextDouble() < 0.55) {
        _enterState(_BotState.block, 0.25 + _rng.nextDouble() * 0.2);
      }
    }

    // State machine
    if (_stateTimer <= 0) {
      _chooseNextState(dist, inRange, tooClose);
    }

    _executeState(dist, inRange, tooClose);
  }

  void _chooseNextState(double dist, bool inRange, bool tooClose) {
    final double r = _rng.nextDouble();

    if (tooClose) {
      if (r < 0.4) {
        _enterState(_BotState.retreat, 0.3 + _rng.nextDouble() * 0.3);
      } else {
        _enterState(_BotState.attackCombo, 0.1);
      }
    } else if (inRange) {
      if (r < 0.55) {
        _enterState(_BotState.attackCombo, 0.2);
      } else if (r < 0.75) {
        _enterState(_BotState.block, 0.3 + _rng.nextDouble() * 0.3);
      } else {
        _enterState(_BotState.jump, 0.5);
      }
    } else {
      if (r < 0.7) {
        _enterState(_BotState.approach, 0.4 + _rng.nextDouble() * 0.4);
      } else {
        _enterState(_BotState.jump, 0.6);
      }
    }
  }

  void _enterState(_BotState s, double duration) {
    _state = s;
    _stateTimer = duration;
    _comboStep = 0;
    fighter.inputLeft = false;
    fighter.inputRight = false;
    fighter.inputBlock = false;
    fighter.inputJump = false;
  }

  void _executeState(double dist, bool inRange, bool tooClose) {
    // Reset inputs each frame
    fighter.inputLeft = false;
    fighter.inputRight = false;
    fighter.inputBlock = false;
    fighter.inputJump = false;
    fighter.inputCrouch = false;

    final bool opponentRight = opponent.position.x > fighter.position.x;

    switch (_state) {
      case _BotState.approach:
        if (opponentRight) {
          fighter.inputRight = true;
        } else {
          fighter.inputLeft = true;
        }

      case _BotState.retreat:
        if (opponentRight) {
          fighter.inputLeft = true;
        } else {
          fighter.inputRight = true;
        }

      case _BotState.attackCombo:
        if (inRange && !fighter.isAttacking) {
          _doComboAttack();
        } else if (!inRange) {
          if (opponentRight) fighter.inputRight = true;
          else fighter.inputLeft = true;
        }

      case _BotState.block:
        fighter.inputBlock = true;

      case _BotState.jump:
        if (!fighter.isAirborne) {
          fighter.inputJump = true;
          fighter.inputRight = opponentRight;
          fighter.inputLeft = !opponentRight;
        }
        // Attack at apex if in range
        if (fighter.isAirborne && dist < _attackRange + 30 && !fighter.isAttacking) {
          if (_rng.nextDouble() < 0.4) {
            game.p2PunchLight();
          }
        }
    }
  }

  void _doComboAttack() {
    final double r = _rng.nextDouble();
    _comboStep++;
    switch (_comboStep % 4) {
      case 1:
        game.p2PunchLight();
      case 2:
        if (r < 0.5) game.p2PunchLight(); else game.p2KickLight();
      case 3:
        if (r < 0.4) game.p2KickHeavy(); else game.p2PunchHeavy();
      case 0:
        game.p2KickLight();
      default:
        game.p2PunchLight();
    }
    _stateTimer = 0.35 + _rng.nextDouble() * 0.25;
  }
}
