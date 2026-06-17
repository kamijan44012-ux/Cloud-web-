import 'package:flutter/material.dart';

// ─── Enums ────────────────────────────────────────────────────────────────

enum GameMode { vsBot, vsPlayer }

enum FightPhase { countdown, fighting, roundPause, gameOver }

enum FighterAction {
  idle,
  walkForward,
  walkBack,
  crouching,
  jumpRise,
  jumpPeak,
  jumpFall,
  punchLight,
  punchHeavy,
  kickLight,
  kickHeavy,
  blocking,
  hitStun,
  knockdown,
  getUp,
  victory,
  defeat,
}

// ─── Pose System ──────────────────────────────────────────────────────────
// Joints relative to fighter's ground-center.
// +x = toward opponent; y=0 at ground, y<0 = upward.

class FighterPose {
  const FighterPose({
    required this.hip,
    required this.spineTop,
    required this.head,
    required this.lShoulder,
    required this.lElbow,
    required this.lFist,
    required this.rShoulder,
    required this.rElbow,
    required this.rFist,
    required this.lHip,
    required this.lKnee,
    required this.lFoot,
    required this.rHip,
    required this.rKnee,
    required this.rFoot,
  });

  final Offset hip, spineTop, head;
  final Offset lShoulder, lElbow, lFist;
  final Offset rShoulder, rElbow, rFist;
  final Offset lHip, lKnee, lFoot;
  final Offset rHip, rKnee, rFoot;

  FighterPose lerp(FighterPose b, double t) => FighterPose(
        hip: Offset.lerp(hip, b.hip, t)!,
        spineTop: Offset.lerp(spineTop, b.spineTop, t)!,
        head: Offset.lerp(head, b.head, t)!,
        lShoulder: Offset.lerp(lShoulder, b.lShoulder, t)!,
        lElbow: Offset.lerp(lElbow, b.lElbow, t)!,
        lFist: Offset.lerp(lFist, b.lFist, t)!,
        rShoulder: Offset.lerp(rShoulder, b.rShoulder, t)!,
        rElbow: Offset.lerp(rElbow, b.rElbow, t)!,
        rFist: Offset.lerp(rFist, b.rFist, t)!,
        lHip: Offset.lerp(lHip, b.lHip, t)!,
        lKnee: Offset.lerp(lKnee, b.lKnee, t)!,
        lFoot: Offset.lerp(lFoot, b.lFoot, t)!,
        rHip: Offset.lerp(rHip, b.rHip, t)!,
        rKnee: Offset.lerp(rKnee, b.rKnee, t)!,
        rFoot: Offset.lerp(rFoot, b.rFoot, t)!,
      );

  // World-space hurtbox (symmetric body box)
  Rect worldHurtbox(double wx, double wy) =>
      Rect.fromLTRB(wx - 30, wy - 148, wx + 30, wy - 18);

  // Attack hitboxes in local pose space
  Rect get frontFistHitbox =>
      Rect.fromCenter(center: rFist, width: 36, height: 36);
  Rect get backFistHitbox =>
      Rect.fromCenter(center: lFist, width: 36, height: 36);
  Rect get frontKickHitbox =>
      Rect.fromCenter(center: rFoot, width: 38, height: 30);
}

// ─── Named Poses ──────────────────────────────────────────────────────────

class Poses {
  Poses._();

  static const FighterPose idle = FighterPose(
    hip: Offset(0, -82),
    spineTop: Offset(-5, -116),
    head: Offset(-3, -140),
    rHip: Offset(12, -82), rKnee: Offset(22, -44), rFoot: Offset(30, -4),
    lHip: Offset(-12, -82), lKnee: Offset(-18, -46), lFoot: Offset(-24, -6),
    rShoulder: Offset(14, -116), rElbow: Offset(28, -96), rFist: Offset(36, -110),
    lShoulder: Offset(-24, -116), lElbow: Offset(-26, -94), lFist: Offset(-14, -110),
  );

  static const FighterPose walkA = FighterPose(
    hip: Offset(4, -84),
    spineTop: Offset(-1, -118),
    head: Offset(1, -142),
    rHip: Offset(16, -84), rKnee: Offset(32, -48), rFoot: Offset(40, -4),
    lHip: Offset(-8, -84), lKnee: Offset(-6, -48), lFoot: Offset(2, -8),
    rShoulder: Offset(16, -118), rElbow: Offset(24, -102), rFist: Offset(28, -116),
    lShoulder: Offset(-18, -118), lElbow: Offset(-30, -102), lFist: Offset(-34, -116),
  );

  static const FighterPose walkB = FighterPose(
    hip: Offset(-2, -82),
    spineTop: Offset(-5, -116),
    head: Offset(-3, -140),
    rHip: Offset(10, -82), rKnee: Offset(18, -46), rFoot: Offset(24, -4),
    lHip: Offset(-14, -82), lKnee: Offset(-8, -50), lFoot: Offset(4, -6),
    rShoulder: Offset(14, -116), rElbow: Offset(28, -102), rFist: Offset(32, -116),
    lShoulder: Offset(-22, -116), lElbow: Offset(-20, -100), lFist: Offset(-12, -116),
  );

  static const FighterPose punchLightWindup = FighterPose(
    hip: Offset(-2, -82),
    spineTop: Offset(-8, -116),
    head: Offset(-7, -140),
    rHip: Offset(10, -82), rKnee: Offset(22, -44), rFoot: Offset(28, -4),
    lHip: Offset(-14, -82), lKnee: Offset(-18, -46), lFoot: Offset(-24, -4),
    rShoulder: Offset(14, -116), rElbow: Offset(16, -98), rFist: Offset(12, -112),
    lShoulder: Offset(-26, -116), lElbow: Offset(-28, -98), lFist: Offset(-18, -112),
  );

  static const FighterPose punchLightExtend = FighterPose(
    hip: Offset(6, -80),
    spineTop: Offset(8, -118),
    head: Offset(7, -142),
    rHip: Offset(18, -80), rKnee: Offset(26, -44), rFoot: Offset(34, -2),
    lHip: Offset(-6, -80), lKnee: Offset(-10, -44), lFoot: Offset(-14, -4),
    rShoulder: Offset(20, -118), rElbow: Offset(54, -118), rFist: Offset(74, -118),
    lShoulder: Offset(-16, -118), lElbow: Offset(-22, -102), lFist: Offset(-16, -116),
  );

  static const FighterPose punchHeavyWindup = FighterPose(
    hip: Offset(-8, -82),
    spineTop: Offset(-18, -114),
    head: Offset(-17, -138),
    rHip: Offset(4, -82), rKnee: Offset(18, -44), rFoot: Offset(24, -4),
    lHip: Offset(-20, -82), lKnee: Offset(-26, -46), lFoot: Offset(-32, -4),
    lShoulder: Offset(-36, -114), lElbow: Offset(-52, -104), lFist: Offset(-62, -116),
    rShoulder: Offset(6, -114), rElbow: Offset(12, -100), rFist: Offset(10, -116),
  );

  static const FighterPose punchHeavyExtend = FighterPose(
    hip: Offset(12, -80),
    spineTop: Offset(22, -116),
    head: Offset(21, -140),
    rHip: Offset(24, -80), rKnee: Offset(36, -44), rFoot: Offset(44, -2),
    lHip: Offset(0, -80), lKnee: Offset(4, -44), lFoot: Offset(2, -4),
    lShoulder: Offset(6, -116), lElbow: Offset(64, -114), lFist: Offset(84, -114),
    rShoulder: Offset(24, -116), rElbow: Offset(28, -102), rFist: Offset(28, -116),
  );

  static const FighterPose kickLightExtend = FighterPose(
    hip: Offset(0, -82),
    spineTop: Offset(-8, -118),
    head: Offset(-6, -142),
    lHip: Offset(-12, -82), lKnee: Offset(-16, -46), lFoot: Offset(-20, -4),
    rHip: Offset(12, -82), rKnee: Offset(52, -82), rFoot: Offset(66, -84),
    lShoulder: Offset(-24, -118), lElbow: Offset(-30, -104), lFist: Offset(-28, -118),
    rShoulder: Offset(14, -118), rElbow: Offset(22, -106), rFist: Offset(22, -120),
  );

  static const FighterPose kickHeavyExtend = FighterPose(
    hip: Offset(0, -82),
    spineTop: Offset(-10, -118),
    head: Offset(-8, -142),
    lHip: Offset(-12, -82), lKnee: Offset(-14, -48), lFoot: Offset(-18, -4),
    rHip: Offset(12, -82), rKnee: Offset(44, -118), rFoot: Offset(56, -148),
    lShoulder: Offset(-24, -118), lElbow: Offset(-32, -104), lFist: Offset(-32, -118),
    rShoulder: Offset(14, -118), rElbow: Offset(20, -106), rFist: Offset(20, -120),
  );

  static const FighterPose blocking = FighterPose(
    hip: Offset(0, -76),
    spineTop: Offset(-3, -106),
    head: Offset(-1, -128),
    lHip: Offset(-12, -76), lKnee: Offset(-16, -42), lFoot: Offset(-22, -4),
    rHip: Offset(12, -76), rKnee: Offset(20, -42), rFoot: Offset(26, -4),
    lShoulder: Offset(-22, -106), lElbow: Offset(-4, -114), lFist: Offset(-2, -126),
    rShoulder: Offset(12, -106), rElbow: Offset(10, -116), rFist: Offset(2, -128),
  );

  static const FighterPose jumpPeak = FighterPose(
    hip: Offset(2, -82),
    spineTop: Offset(-4, -116),
    head: Offset(-2, -140),
    lHip: Offset(-10, -82), lKnee: Offset(-22, -60), lFoot: Offset(-20, -42),
    rHip: Offset(14, -82), rKnee: Offset(26, -60), rFoot: Offset(24, -42),
    lShoulder: Offset(-22, -116), lElbow: Offset(-28, -104), lFist: Offset(-24, -116),
    rShoulder: Offset(16, -116), rElbow: Offset(22, -104), rFist: Offset(18, -116),
  );

  static const FighterPose hitStun = FighterPose(
    hip: Offset(-6, -82),
    spineTop: Offset(-20, -112),
    head: Offset(-19, -136),
    lHip: Offset(-18, -82), lKnee: Offset(-22, -46), lFoot: Offset(-28, -4),
    rHip: Offset(6, -82), rKnee: Offset(14, -46), rFoot: Offset(20, -4),
    lShoulder: Offset(-38, -112), lElbow: Offset(-50, -100), lFist: Offset(-56, -114),
    rShoulder: Offset(0, -112), rElbow: Offset(6, -100), rFist: Offset(0, -114),
  );

  static const FighterPose knockdown = FighterPose(
    hip: Offset(0, -24),
    spineTop: Offset(-24, -52),
    head: Offset(-28, -72),
    lHip: Offset(-12, -24), lKnee: Offset(-36, -14), lFoot: Offset(-56, -4),
    rHip: Offset(10, -22), rKnee: Offset(32, -12), rFoot: Offset(50, -4),
    lShoulder: Offset(-42, -52), lElbow: Offset(-56, -40), lFist: Offset(-58, -24),
    rShoulder: Offset(-8, -52), rElbow: Offset(4, -40), rFist: Offset(8, -24),
  );

  static const FighterPose victory = FighterPose(
    hip: Offset(0, -82),
    spineTop: Offset(6, -118),
    head: Offset(4, -142),
    lHip: Offset(-12, -82), lKnee: Offset(-14, -50), lFoot: Offset(-18, -4),
    rHip: Offset(14, -82), rKnee: Offset(18, -50), rFoot: Offset(24, -4),
    lShoulder: Offset(-22, -118), lElbow: Offset(-44, -138), lFist: Offset(-44, -156),
    rShoulder: Offset(18, -118), rElbow: Offset(40, -138), rFist: Offset(40, -156),
  );
}

// ─── Character Data ────────────────────────────────────────────────────────

class CharacterData {
  const CharacterData({
    required this.id,
    required this.name,
    required this.bodyColor,
    required this.accentColor,
    required this.glowColor,
    required this.speed,
    required this.jumpPower,
    required this.maxHealth,
    required this.damageScale,
    required this.description,
  });

  final String id;
  final String name;
  final Color bodyColor;
  final Color accentColor;
  final Color glowColor;
  final double speed;
  final double jumpPower;
  final double maxHealth;
  final double damageScale;
  final String description;

  static const CharacterData shadow = CharacterData(
    id: 'shadow',
    name: 'SHADOW',
    bodyColor: Color(0xFF0D1B3E),
    accentColor: Color(0xFF00CCFF),
    glowColor: Color(0xFF0099DD),
    speed: 220,
    jumpPower: 560,
    maxHealth: 100,
    damageScale: 1.0,
    description: 'Balanced · Master of technique',
  );

  static const CharacterData blaze = CharacterData(
    id: 'blaze',
    name: 'BLAZE',
    bodyColor: Color(0xFF2D0800),
    accentColor: Color(0xFFFF6600),
    glowColor: Color(0xFFCC3300),
    speed: 190,
    jumpPower: 520,
    maxHealth: 120,
    damageScale: 1.3,
    description: 'Power · Heavy hits, iron body',
  );

  static const CharacterData storm = CharacterData(
    id: 'storm',
    name: 'STORM',
    bodyColor: Color(0xFF1A0033),
    accentColor: Color(0xFFFFEE00),
    glowColor: Color(0xFFBBAA00),
    speed: 260,
    jumpPower: 600,
    maxHealth: 80,
    damageScale: 0.88,
    description: 'Speed · Lightning reflex',
  );

  static const List<CharacterData> all = <CharacterData>[shadow, blaze, storm];
}
