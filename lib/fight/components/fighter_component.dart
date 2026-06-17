import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../fight_data.dart';

// ─── Action timing tables ─────────────────────────────────────────────────

class _ActionTiming {
  const _ActionTiming({
    required this.windupEnd,
    required this.activeEnd,
    required this.totalDuration,
    required this.damage,
  });
  final double windupEnd, activeEnd, totalDuration, damage;
}

const Map<FighterAction, _ActionTiming> _kTimings = <FighterAction, _ActionTiming>{
  FighterAction.punchLight: _ActionTiming(
      windupEnd: 0.06, activeEnd: 0.20, totalDuration: 0.36, damage: 8),
  FighterAction.punchHeavy: _ActionTiming(
      windupEnd: 0.14, activeEnd: 0.30, totalDuration: 0.56, damage: 18),
  FighterAction.kickLight: _ActionTiming(
      windupEnd: 0.06, activeEnd: 0.22, totalDuration: 0.40, damage: 10),
  FighterAction.kickHeavy: _ActionTiming(
      windupEnd: 0.08, activeEnd: 0.26, totalDuration: 0.50, damage: 22),
};

/// Full fighter: physics, animation, rendering.
class FighterComponent extends PositionComponent {
  FighterComponent({
    required this.characterData,
    required this.isP1,
    required bool facingRight,
  })  : _facingRight = facingRight,
        super(anchor: Anchor.bottomCenter, size: Vector2(80, 160));

  final CharacterData characterData;
  final bool isP1;

  bool get facingRight => _facingRight;
  set facingRight(bool v) => _facingRight = v;
  bool _facingRight;

  // Health
  double get health => _health;
  double _health = 100;

  // Physics
  Vector2 velocity = Vector2.zero();
  static const double _gravity = 1400;
  static const double _groundY = 300;

  // Input (set each frame by game or AI)
  bool inputLeft = false;
  bool inputRight = false;
  bool inputJump = false;
  bool inputCrouch = false;
  bool inputBlock = false;

  // Action state
  FighterAction currentAction = FighterAction.idle;
  double _actionTimer = 0;
  bool hitRegisteredThisSwing = false;
  double _hitFlash = 0;
  double _breathe = 0;

  // Walk animation
  double _walkCycle = 0;

  bool get isAirborne => position.y < _groundY;
  bool get isAttacking => _kTimings.containsKey(currentAction);
  bool get isBlocking =>
      currentAction == FighterAction.blocking && !isAirborne;

  double get currentAttackDamage {
    final _ActionTiming? t = _kTimings[currentAction];
    if (t == null) return 0;
    return t.damage * characterData.damageScale;
  }

  /// Returns world-space hitbox for the current active attack frame, or null.
  Rect? get currentAttackHitbox {
    final _ActionTiming? t = _kTimings[currentAction];
    if (t == null) return null;
    if (_actionTimer < t.windupEnd || _actionTimer > t.activeEnd) return null;

    final FighterPose p = _currentPose;
    Rect local;
    switch (currentAction) {
      case FighterAction.punchLight:
        local = p.frontFistHitbox;
      case FighterAction.punchHeavy:
        local = p.backFistHitbox;
      case FighterAction.kickLight:
      case FighterAction.kickHeavy:
        local = p.frontKickHitbox;
      default:
        return null;
    }

    final double wx = position.x;
    final double wy = position.y;
    final double sign = _facingRight ? 1 : -1;
    return Rect.fromCenter(
      center: Offset(
        wx + local.center.dx * sign,
        wy + local.center.dy,
      ),
      width: local.width,
      height: local.height,
    );
  }

  /// World-space hurtbox for this fighter.
  Rect get worldHurtbox => _currentPose.worldHurtbox(position.x, position.y);

  void resetHealth() {
    _health = characterData.maxHealth;
    _hitFlash = 0;
  }

  void resetToIdle() {
    currentAction = FighterAction.idle;
    _actionTimer = 0;
    velocity = Vector2.zero();
    _hitFlash = 0;
    hitRegisteredThisSwing = false;
  }

  void doAttack(FighterAction action) {
    // Can't start new attack if in non-cancellable state
    if (currentAction == FighterAction.knockdown ||
        currentAction == FighterAction.hitStun ||
        currentAction == FighterAction.getUp ||
        currentAction == FighterAction.victory ||
        currentAction == FighterAction.defeat) {
      return;
    }
    // Can't chain attack if already attacking
    if (isAttacking) return;

    currentAction = action;
    _actionTimer = 0;
    hitRegisteredThisSwing = false;
  }

  void takeDamage(double amount, {bool blocked = false}) {
    if (currentAction == FighterAction.knockdown ||
        currentAction == FighterAction.getUp) return;

    _health = (_health - amount).clamp(0, characterData.maxHealth);
    _hitFlash = 0.18;

    if (_health <= 0) {
      setKnockdown();
    } else if (!blocked) {
      currentAction = FighterAction.hitStun;
      _actionTimer = 0;
      velocity.x = (_facingRight ? -1 : 1) * 60.0;
    }
  }

  void setKnockdown() {
    currentAction = FighterAction.knockdown;
    _actionTimer = 0;
    velocity = Vector2.zero();
  }

  void setVictory() {
    currentAction = FighterAction.victory;
    _actionTimer = 0;
    velocity = Vector2.zero();
  }

  // ─── Per-frame update ──────────────────────────────────────────────────

  void fightUpdate(double dt, {required FighterComponent opponent}) {
    _breathe += dt * 2.2;
    _hitFlash = max(0, _hitFlash - dt * 4);
    _actionTimer += dt;

    _updateAction(dt);
    _applyPhysics(dt);

    // Clamp to game bounds
    position.x = position.x.clamp(40, 680);
  }

  void _applyPhysics(double dt) {
    // Gravity
    if (isAirborne) {
      velocity.y += _gravity * dt;
    }

    position.x += velocity.x * dt;
    position.y += velocity.y * dt;

    // Land on ground
    if (position.y >= _groundY) {
      position.y = _groundY;
      velocity.y = 0;
      if (currentAction == FighterAction.jumpRise ||
          currentAction == FighterAction.jumpPeak ||
          currentAction == FighterAction.jumpFall) {
        currentAction = FighterAction.idle;
        _actionTimer = 0;
      }
    }

    // Horizontal friction (when not inputting)
    if (!inputLeft && !inputRight) {
      velocity.x *= (1 - dt * 14);
      if (velocity.x.abs() < 2) velocity.x = 0;
    }
  }

  void _updateAction(double dt) {
    final double spd = characterData.speed;

    switch (currentAction) {
      case FighterAction.idle:
        _handleIdleInput(spd);
      case FighterAction.walkForward:
      case FighterAction.walkBack:
        _handleWalkInput(spd);
      case FighterAction.crouching:
        if (!inputCrouch) {
          currentAction = FighterAction.idle;
          _actionTimer = 0;
        }
      case FighterAction.jumpRise:
        if (velocity.y >= 0) {
          currentAction = FighterAction.jumpPeak;
          _actionTimer = 0;
        }
      case FighterAction.jumpPeak:
        if (velocity.y > 100) {
          currentAction = FighterAction.jumpFall;
          _actionTimer = 0;
        }
        // Allow attacks in air
        _handleWalkInput(spd * 0.5);
      case FighterAction.jumpFall:
        _handleWalkInput(spd * 0.5);
      case FighterAction.blocking:
        if (!inputBlock) {
          currentAction = FighterAction.idle;
          _actionTimer = 0;
        }
      case FighterAction.punchLight:
      case FighterAction.punchHeavy:
      case FighterAction.kickLight:
      case FighterAction.kickHeavy:
        final _ActionTiming t = _kTimings[currentAction]!;
        if (_actionTimer >= t.totalDuration) {
          currentAction = FighterAction.idle;
          _actionTimer = 0;
        }
      case FighterAction.hitStun:
        if (_actionTimer >= 0.44) {
          currentAction = FighterAction.idle;
          _actionTimer = 0;
        }
      case FighterAction.knockdown:
        if (_actionTimer >= 1.4) {
          currentAction = FighterAction.getUp;
          _actionTimer = 0;
        }
      case FighterAction.getUp:
        if (_actionTimer >= 0.8) {
          currentAction = FighterAction.idle;
          _actionTimer = 0;
        }
      case FighterAction.victory:
      case FighterAction.defeat:
        break;
      default:
        break;
    }
  }

  void _handleIdleInput(double spd) {
    if (inputBlock && !isAirborne) {
      currentAction = FighterAction.blocking;
      _actionTimer = 0;
      return;
    }
    if (inputCrouch && !isAirborne) {
      currentAction = FighterAction.crouching;
      _actionTimer = 0;
      return;
    }
    if (inputJump && !isAirborne) {
      velocity.y = -characterData.jumpPower;
      currentAction = FighterAction.jumpRise;
      _actionTimer = 0;
      if (inputLeft) velocity.x = -spd * 0.7;
      if (inputRight) velocity.x = spd * 0.7;
      return;
    }
    if (inputLeft) {
      velocity.x = -spd;
      _walkCycle += 0.04;
      currentAction = FighterAction.walkBack;
    } else if (inputRight) {
      velocity.x = spd;
      _walkCycle += 0.04;
      currentAction = FighterAction.walkForward;
    }
  }

  void _handleWalkInput(double spd) {
    if (inputBlock && !isAirborne) {
      currentAction = FighterAction.blocking;
      _actionTimer = 0;
      velocity.x = 0;
      return;
    }
    if (inputJump && !isAirborne) {
      velocity.y = -characterData.jumpPower;
      currentAction = FighterAction.jumpRise;
      _actionTimer = 0;
      velocity.x = inputLeft ? -spd * 0.7 : (inputRight ? spd * 0.7 : 0);
      return;
    }
    if (inputLeft) {
      velocity.x = -spd;
      _walkCycle += 0.04;
    } else if (inputRight) {
      velocity.x = spd;
      _walkCycle += 0.04;
    } else if (!isAirborne) {
      currentAction = FighterAction.idle;
      _actionTimer = 0;
    }
  }

  // ─── Pose resolution ─────────────────────────────────────────────────

  FighterPose get _currentPose {
    switch (currentAction) {
      case FighterAction.idle:
        final double bob = sin(_breathe) * 2;
        return FighterPose(
          hip: Poses.idle.hip + Offset(0, bob * 0.4),
          spineTop: Poses.idle.spineTop + Offset(0, bob * 0.3),
          head: Poses.idle.head + Offset(0, bob * 0.2),
          lShoulder: Poses.idle.lShoulder + Offset(0, bob * 0.3),
          lElbow: Poses.idle.lElbow + Offset(0, bob * 0.2),
          lFist: Poses.idle.lFist,
          rShoulder: Poses.idle.rShoulder + Offset(0, bob * 0.3),
          rElbow: Poses.idle.rElbow + Offset(0, bob * 0.2),
          rFist: Poses.idle.rFist,
          lHip: Poses.idle.lHip,
          lKnee: Poses.idle.lKnee,
          lFoot: Poses.idle.lFoot,
          rHip: Poses.idle.rHip,
          rKnee: Poses.idle.rKnee,
          rFoot: Poses.idle.rFoot,
        );

      case FighterAction.walkForward:
      case FighterAction.walkBack:
        final double t = (sin(_walkCycle * pi * 2) + 1) / 2;
        return Poses.walkA.lerp(Poses.walkB, t);

      case FighterAction.crouching:
        return Poses.blocking.lerp(Poses.idle, 0.4);

      case FighterAction.jumpRise:
      case FighterAction.jumpPeak:
      case FighterAction.jumpFall:
        return Poses.jumpPeak;

      case FighterAction.punchLight:
        final _ActionTiming t = _kTimings[FighterAction.punchLight]!;
        if (_actionTimer < t.windupEnd) {
          return Poses.idle.lerp(
              Poses.punchLightWindup, _actionTimer / t.windupEnd);
        }
        if (_actionTimer < t.activeEnd) {
          return Poses.punchLightWindup.lerp(Poses.punchLightExtend,
              (_actionTimer - t.windupEnd) / (t.activeEnd - t.windupEnd));
        }
        return Poses.punchLightExtend.lerp(
            Poses.idle,
            (_actionTimer - t.activeEnd) / (t.totalDuration - t.activeEnd));

      case FighterAction.punchHeavy:
        final _ActionTiming t = _kTimings[FighterAction.punchHeavy]!;
        if (_actionTimer < t.windupEnd) {
          return Poses.idle.lerp(
              Poses.punchHeavyWindup, _actionTimer / t.windupEnd);
        }
        if (_actionTimer < t.activeEnd) {
          return Poses.punchHeavyWindup.lerp(Poses.punchHeavyExtend,
              (_actionTimer - t.windupEnd) / (t.activeEnd - t.windupEnd));
        }
        return Poses.punchHeavyExtend.lerp(
            Poses.idle,
            (_actionTimer - t.activeEnd) / (t.totalDuration - t.activeEnd));

      case FighterAction.kickLight:
        final _ActionTiming t = _kTimings[FighterAction.kickLight]!;
        if (_actionTimer < t.windupEnd) {
          return Poses.idle.lerp(
              Poses.kickLightExtend, _actionTimer / t.windupEnd);
        }
        if (_actionTimer < t.activeEnd) {
          return Poses.kickLightExtend;
        }
        return Poses.kickLightExtend.lerp(
            Poses.idle,
            (_actionTimer - t.activeEnd) / (t.totalDuration - t.activeEnd));

      case FighterAction.kickHeavy:
        final _ActionTiming t = _kTimings[FighterAction.kickHeavy]!;
        if (_actionTimer < t.windupEnd) {
          return Poses.idle.lerp(
              Poses.kickHeavyExtend, _actionTimer / t.windupEnd);
        }
        if (_actionTimer < t.activeEnd) {
          return Poses.kickHeavyExtend;
        }
        return Poses.kickHeavyExtend.lerp(
            Poses.idle,
            (_actionTimer - t.activeEnd) / (t.totalDuration - t.activeEnd));

      case FighterAction.blocking:
        return Poses.idle.lerp(Poses.blocking, min(1.0, _actionTimer / 0.06));

      case FighterAction.hitStun:
        final double t = min(1.0, _actionTimer / 0.44);
        return Poses.hitStun.lerp(Poses.idle, t);

      case FighterAction.knockdown:
        final double t = min(1.0, _actionTimer / 0.3);
        return Poses.hitStun.lerp(Poses.knockdown, t);

      case FighterAction.getUp:
        final double t = min(1.0, _actionTimer / 0.8);
        return Poses.knockdown.lerp(Poses.idle, t);

      case FighterAction.victory:
        final double t = min(1.0, _actionTimer / 0.4);
        return Poses.idle.lerp(Poses.victory, t);

      case FighterAction.defeat:
        return Poses.knockdown;

      default:
        return Poses.idle;
    }
  }

  // ─── Rendering ───────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    final FighterPose pose = _currentPose;
    final Color body = characterData.bodyColor;
    final Color accent = characterData.accentColor;
    final Color glow = characterData.glowColor;

    canvas.save();

    // Mirror when facing left
    if (!_facingRight) {
      canvas.scale(-1, 1);
    }

    // Draw shadow on ground
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, -2), width: 60, height: 10),
      Paint()..color = const Color(0x44000000),
    );

    _drawFighter(canvas, pose, body, accent, glow);

    // Hit flash overlay
    if (_hitFlash > 0) {
      _drawFighter(
        canvas,
        pose,
        Colors.white.withOpacity(_hitFlash * 4),
        Colors.white.withOpacity(_hitFlash * 4),
        Colors.white,
      );
    }

    canvas.restore();
  }

  void _drawFighter(Canvas canvas, FighterPose p, Color body, Color accent,
      Color glowColor) {
    final bool isActive = isAttacking &&
        _actionTimer > (_kTimings[currentAction]?.windupEnd ?? 999) &&
        _actionTimer < (_kTimings[currentAction]?.activeEnd ?? 0);

    // Back limbs (L = back side when facing right)
    _drawLimb(canvas, p.lHip, p.lKnee, 15, body, accent, glowColor, isActive);
    _drawLimb(canvas, p.lKnee, p.lFoot, 12, body, accent, glowColor, isActive);
    _drawBoot(canvas, p.lFoot, body, accent);

    _drawLimb(canvas, p.lShoulder, p.lElbow, 13, body, accent, glowColor,
        isActive && currentAction == FighterAction.punchHeavy);
    _drawLimb(canvas, p.lElbow, p.lFist, 11, body, accent, glowColor,
        isActive && currentAction == FighterAction.punchHeavy);
    _drawFist(canvas, p.lFist, accent, glowColor,
        isActive && currentAction == FighterAction.punchHeavy);

    // Torso
    _drawTorso(canvas, p, body, accent, glowColor);

    // Front limbs (R = front side)
    _drawLimb(canvas, p.rHip, p.rKnee, 15, body, accent, glowColor, isActive);
    _drawLimb(canvas, p.rKnee, p.rFoot, 13, body, accent, glowColor, isActive);
    _drawBoot(canvas, p.rFoot, body, accent);

    final bool frontArmActive = isActive &&
        (currentAction == FighterAction.punchLight ||
            currentAction == FighterAction.kickLight ||
            currentAction == FighterAction.kickHeavy);
    _drawLimb(canvas, p.rShoulder, p.rElbow, 13, body, accent, glowColor,
        frontArmActive);
    _drawLimb(canvas, p.rElbow, p.rFist, 11, body, accent, glowColor,
        frontArmActive);
    _drawFist(canvas, p.rFist, accent, glowColor, frontArmActive);

    // Head
    _drawHead(canvas, p.head, body, accent, glowColor);
  }

  void _drawLimb(Canvas canvas, Offset a, Offset b, double w, Color body,
      Color accent, Color glowColor, bool energized) {
    // Glow layer
    if (energized) {
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = glowColor.withOpacity(0.55)
          ..strokeWidth = w + 8
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    // Body fill
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = body
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round,
    );

    // Accent outline
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = accent.withOpacity(energized ? 0.9 : 0.55)
        ..strokeWidth = energized ? 2.5 : 1.8
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawFist(Canvas canvas, Offset center, Color accent, Color glowColor,
      bool energized) {
    if (energized) {
      canvas.drawCircle(
        center,
        16,
        Paint()
          ..color = glowColor.withOpacity(0.7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      canvas.drawCircle(
        center,
        12,
        Paint()
          ..color = accent.withOpacity(0.9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
    canvas.drawCircle(
        center, energized ? 11 : 9, Paint()..color = accent);
    if (energized) {
      canvas.drawCircle(
          center,
          7,
          Paint()
            ..color = Colors.white.withOpacity(0.8));
    }
  }

  void _drawBoot(Canvas canvas, Offset foot, Color body, Color accent) {
    final Rect boot =
        Rect.fromCenter(center: foot + const Offset(6, 0), width: 28, height: 11);
    canvas.drawRRect(
      RRect.fromRectAndRadius(boot, const Radius.circular(5)),
      Paint()..color = body,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(boot, const Radius.circular(5)),
      Paint()
        ..color = accent.withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawTorso(Canvas canvas, FighterPose p, Color body, Color accent,
      Color glowColor) {
    // Filled body polygon: shoulders → hips
    final Path torso = Path()
      ..moveTo(p.lShoulder.dx, p.lShoulder.dy)
      ..lineTo(p.rShoulder.dx, p.rShoulder.dy)
      ..lineTo(p.rHip.dx, p.rHip.dy)
      ..lineTo(p.lHip.dx, p.lHip.dy)
      ..close();

    canvas.drawPath(torso, Paint()..color = body);
    canvas.drawPath(
      torso,
      Paint()
        ..color = accent.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Chest symbol — small glowing diamond
    final Offset chest = Offset(
      (p.lShoulder.dx + p.rShoulder.dx) / 2 + 2,
      (p.lShoulder.dy + p.rShoulder.dy + p.lHip.dy + p.rHip.dy) / 4,
    );
    final double cs = 6;
    final Path diamond = Path()
      ..moveTo(chest.dx, chest.dy - cs)
      ..lineTo(chest.dx + cs * 0.6, chest.dy)
      ..lineTo(chest.dx, chest.dy + cs)
      ..lineTo(chest.dx - cs * 0.6, chest.dy)
      ..close();
    canvas.drawPath(
      diamond,
      Paint()
        ..color = accent.withOpacity(0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(diamond, Paint()..color = Colors.white.withOpacity(0.7));

    // Neck
    _drawLimb(canvas, p.spineTop, p.head + const Offset(0, 18), 12, body,
        accent, glowColor, false);
  }

  void _drawHead(Canvas canvas, Offset center, Color body, Color accent,
      Color glowColor) {
    // Helmet body
    canvas.drawCircle(center, 20, Paint()..color = body);
    canvas.drawCircle(
      center,
      20,
      Paint()
        ..color = accent.withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    // Visor
    final Rect visor = Rect.fromCenter(
        center: center + const Offset(5, 0), width: 22, height: 9);
    canvas.drawRRect(
      RRect.fromRectAndRadius(visor, const Radius.circular(4)),
      Paint()..color = accent.withOpacity(0.85),
    );
    // Visor glow
    canvas.drawRRect(
      RRect.fromRectAndRadius(visor, const Radius.circular(4)),
      Paint()
        ..color = glowColor.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // Visor glint
    canvas.drawLine(
      center + const Offset(-2, -2),
      center + const Offset(10, -2),
      Paint()
        ..color = Colors.white.withOpacity(0.5)
        ..strokeWidth = 1.5,
    );

    // Subtle head glow
    canvas.drawCircle(
      center,
      22,
      Paint()
        ..color = glowColor.withOpacity(0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  @override
  void update(double dt) {
    // Handled by FightGame via fightUpdate
  }
}
