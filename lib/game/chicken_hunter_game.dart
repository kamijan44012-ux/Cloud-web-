import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../config/palette.dart';
import '../models/enemy_type.dart';
import '../models/mission.dart';
import '../models/power_up_type.dart';
import '../models/ship_data.dart';
import '../models/weapon_data.dart';
import '../services/audio_service.dart';
import '../systems/achievement_system.dart';
import '../systems/battle_pass.dart';
import '../systems/mission_system.dart';
import '../systems/player_controller.dart';
import 'components/bullets/bullet.dart';
import 'components/effects/explosion.dart';
import 'components/effects/floating_text.dart';
import 'components/effects/hyperspace.dart';
import 'components/enemies/boss_chicken.dart';
import 'components/enemies/enemy_chicken.dart';
import 'components/nebula_background.dart';
import 'components/planet.dart';
import 'components/player_ship.dart';
import 'components/powerups/power_up.dart';
import 'components/star_field.dart';
import 'managers/buff_manager.dart';
import 'managers/wave_manager.dart';
import 'sprite_catalog.dart';

enum RunState { playing, paused, over }

/// The top-level Flame game. It owns the run loop: spawning waves, resolving
/// collisions, tracking the run's score/coins, and reporting results back to
/// the meta systems (player wallet, missions, achievements, battle pass).
///
/// The Flutter UI overlays the HUD on top and reads these [ValueNotifier]s, so
/// the engine never imports widgets and stays testable in isolation.
class ChickenHunterGame extends FlameGame with DragCallbacks, HasCollisionDetection {
  ChickenHunterGame({
    required this.player,
    required this.missions,
    required this.achievements,
    required this.battlePass,
    required this.onRunOver,
  });

  final PlayerController player;
  final MissionSystem missions;
  final AchievementSystem achievements;
  final BattlePassSystem battlePass;
  final void Function(RunResult result) onRunOver;

  // ---- HUD-facing reactive state -------------------------------------------
  final ValueNotifier<int> score = ValueNotifier<int>(0);
  final ValueNotifier<int> runCoins = ValueNotifier<int>(0);
  final ValueNotifier<int> wave = ValueNotifier<int>(0);
  final ValueNotifier<double> healthFraction = ValueNotifier<double>(1);
  final ValueNotifier<double> nukeCharge = ValueNotifier<double>(0); // 0..1
  final ValueNotifier<RunState> state = ValueNotifier<RunState>(RunState.playing);
  final ValueNotifier<Map<PowerUpType, double>> activeBuffs =
      ValueNotifier<Map<PowerUpType, double>>(<PowerUpType, double>{});

  // ---- Engine state ---------------------------------------------------------
  final WaveManager _waves = WaveManager();
  final BuffManager buffs = BuffManager();
  final Random _rng = Random();
  late PlayerShip _ship;
  late ShipData _shipData;

  int _killsThisRun = 0;
  int _bossKillsThisRun = 0;
  int _powerUpsThisRun = 0;
  double _waveBanner = 0;

  // Inter-wave hyperjump transition.
  double _transition = 0;
  bool _pendingWave = false;
  double _planetTimer = 12;
  final ValueNotifier<String> banner = ValueNotifier<String>('');

  /// Every 3 waves the chickens get a fresh "skin" (hue + pattern).
  int get _variant => _waves.wave ~/ 3;

  // Snapshot of loadout taken at run start (so mid-run upgrades don't apply).
  late WeaponType equippedWeapon;
  late int weaponLevel;

  bool get isFrozen => buffs.timeFreeze;
  Vector2 get playerPosition => _ship.position;

  // Screen-shake state. Components call shake() on impacts; render() applies it.
  double _shake = 0;
  void shake(double intensity) => _shake = max(_shake, intensity);

  @override
  Color backgroundColor() => Palette.spaceTop;

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
    _shipData = ShipData.byId(player.data.selectedShipId);
    equippedWeapon = player.data.equippedWeapon;
    weaponLevel = player.data.weaponLevel(equippedWeapon).clamp(1, 99);

    final double healthBonus = 1 + player.data.shipUpgradeLevel('health') * 0.1;
    final double maxHealth = _shipData.baseHealth * healthBonus;

    // Load all sprite art + the explosion animation before the first frame.
    await SpriteCatalog.instance.load(images);

    add(NebulaBackground());
    add(StarField(areaSize: size));
    _spawnPlanet(initial: true); // a world already hanging in the sky
    _ship = PlayerShip(ship: _shipData, maxHealth: maxHealth);
    add(_ship);

    AudioService.instance.startMusic();
    _beginNextWave();
  }

  // ---------------------------------------------------------------------------
  // Background celestial bodies drifting past for depth.
  // ---------------------------------------------------------------------------
  void _spawnPlanet({bool initial = false, bool fromTop = false}) {
    final PlanetKind kind = PlanetKind.values[_rng.nextInt(PlanetKind.values.length)];
    final double r = 50 + _rng.nextDouble() * 70;
    final double x = _rng.nextDouble() * size.x;
    final double y = initial
        ? size.y * (0.15 + _rng.nextDouble() * 0.3)
        : (fromTop ? -r * 1.5 : -r * 1.5);
    add(Planet(
      position: Vector2(x, y),
      kind: kind,
      planetRadius: r,
      driftSpeed: fromTop ? 60 : 10 + _rng.nextDouble() * 14,
    ));
  }

  // ---------------------------------------------------------------------------
  // Drag controls — finger position becomes the ship's target.
  // ---------------------------------------------------------------------------
  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (state.value != RunState.playing) return;
    _ship.targetPosition = event.canvasEndPosition;
  }

  @override
  void onDragStart(DragStartEvent event) {
    if (state.value != RunState.playing) return;
    _ship.targetPosition = event.canvasPosition;
  }

  // ---------------------------------------------------------------------------
  // Main loop.
  // ---------------------------------------------------------------------------
  @override
  void update(double dt) {
    super.update(dt);
    if (state.value != RunState.playing) return;

    buffs.tick(dt);
    activeBuffs.value = buffs.active;
    if (_waveBanner > 0) {
      _waveBanner -= dt;
      if (_waveBanner <= 0 && _transition <= 0) banner.value = '';
    }
    if (_shake > 0) _shake = max(0, _shake - dt * 45);

    // Occasionally drift a new planet/galaxy in from the top.
    _planetTimer -= dt;
    if (_planetTimer <= 0) {
      _planetTimer = 10 + _rng.nextDouble() * 12;
      _spawnPlanet();
    }

    // During a hyperjump, hold spawning until the warp completes.
    if (_transition > 0) {
      _transition -= dt;
      if (_transition <= 0 && _pendingWave) {
        _pendingWave = false;
        banner.value = '';
        _beginNextWave();
      }
      return;
    }

    // Stream in normal-wave enemies.
    final EnemyType? toSpawn = _waves.tick(dt);
    if (toSpawn != null) _spawnEnemy(toSpawn);

    // When the field is clear, warp to the next sector (wave).
    if (_waves.waveCleared && children.whereType<EnemyChicken>().isEmpty) {
      _startHyperjump();
    }

    if (buffs.magnet) _applyMagnet(dt);

    healthFraction.value = (_ship.health / _ship.maxHealth).clamp(0.0, 1.0);
  }

  /// Plays the interplanetary warp: streaking stars, a destination planet flying
  /// in, and a "SECTOR N" banner, then starts the next wave.
  void _startHyperjump() {
    _pendingWave = true;
    _transition = 1.4;
    add(Hyperspace());
    _spawnPlanet(fromTop: true); // the planet we're arriving at
    AudioService.instance.nuke(); // reuse as a low warp whoosh
    shake(8);
    banner.value = 'WARP → SECTOR ${_waves.wave + 1}';
  }

  void _beginNextWave() {
    final EnemyType? boss = _waves.startNextWave();
    wave.value = _waves.wave;
    _waveBanner = 2.0;
    if (boss != null) banner.value = _waves.isGiantBossWave ? 'GALACTIC BOSS!' : 'BOSS INCOMING!';
    missions.report(MissionMetric.reachWave, _waves.wave);
    for (final String _ in achievements.reportWave(_waves.wave)) {/* toast handled by UI */}

    if (boss != null) {
      add(BossChicken(
        position: Vector2(size.x / 2, -80),
        stats: EnemyStats.table[boss]!.scaledFor(_waves.wave),
      ));
    }
  }

  // ---------------------------------------------------------------------------
  // Spawning helpers used by components.
  // ---------------------------------------------------------------------------
  void _spawnEnemy(EnemyType type) {
    final double x = _rng.nextDouble() * (size.x - 60) + 30;
    add(EnemyChicken(
      position: Vector2(x, -40),
      stats: EnemyStats.table[type]!.scaledFor(_waves.wave),
      variant: _variant,
    ));
  }

  void spawnEscort(Vector2 from) {
    add(EnemyChicken(
      position: from + Vector2(_rng.nextDouble() * 60 - 30, 40),
      stats: EnemyStats.table[EnemyType.fast]!.scaledFor(_waves.wave),
      variant: _variant,
    ));
  }

  void spawnPlayerBullet(Bullet bullet) => add(bullet);
  void spawnEnemyBullet(Bullet bullet) => add(bullet);

  // ---------------------------------------------------------------------------
  // Combat results.
  // ---------------------------------------------------------------------------
  void onEnemyKilled(EnemyChicken enemy) {
    _killsThisRun++;
    score.value += (enemy.stats.coinReward * 2);
    _earnCoins(enemy.stats.coinReward);
    _chargeNuke(0.02);
    missions.report(MissionMetric.killChickens, 1);
    for (final String _ in achievements.reportKills(1)) {/* UI toast */}
    add(FloatingText(
      position: enemy.position.clone(),
      text: '+${enemy.stats.coinReward}',
      color: Palette.coin,
    ));
    _maybeDropPowerUp(enemy.position, enemy.stats.type);
  }

  void onBossKilled(BossChicken boss) {
    _bossKillsThisRun++;
    score.value += boss.stats.coinReward * 4;
    _earnCoins(boss.stats.coinReward);
    _chargeNuke(0.5);
    _waves.onBossDefeated();
    shake(22);
    missions.report(MissionMetric.killBosses, 1);
    for (final String _ in achievements.reportBossKill()) {/* UI toast */}
    add(FloatingText(
      position: boss.position.clone(),
      text: 'BOSS DOWN! +${boss.stats.coinReward}',
      color: Palette.hudYellow,
      fontSize: 24,
      lifetime: 1.4,
    ));
    // Bosses always drop a treat.
    _spawnPowerUp(boss.position, PowerUpType.coinBurst);
  }

  void onEnemyEscaped(EnemyChicken enemy) {
    // Kamikaze/laser slipping past chips the player a little (keeps pressure on).
    if (enemy.stats.type == EnemyType.kamikaze) {
      _ship.takeDamage(enemy.stats.contactDamage * 0.5);
    }
  }

  void onPlayerDamaged() {
    healthFraction.value = (_ship.health / _ship.maxHealth).clamp(0.0, 1.0);
    if (!_ship.isAlive) _endRun();
  }

  /// Area-of-effect (rockets/nuke) — damages everything within [radius].
  void applyAoeDamage(Vector2 center, double radius, double damage) {
    add(Explosion(position: center.clone(), color: Palette.chickenKamikaze, maxRadius: radius));
    for (final EnemyChicken e in children.whereType<EnemyChicken>()) {
      if (e.position.distanceTo(center) <= radius) e.takeDamage(damage);
    }
    for (final BossChicken b in children.whereType<BossChicken>()) {
      if (b.position.distanceTo(center) <= radius) b.takeDamage(damage);
    }
  }

  // ---------------------------------------------------------------------------
  // Ultimate: Nuclear Strike. Clears the screen of normal enemies, big damage
  // to bosses. Charged by kills; triggered by the HUD button.
  // ---------------------------------------------------------------------------
  void _chargeNuke(double amount) {
    nukeCharge.value = (nukeCharge.value + amount).clamp(0.0, 1.0);
  }

  bool get isNukeReady => nukeCharge.value >= 1.0;

  void triggerNuke() {
    if (!isNukeReady || state.value != RunState.playing) return;
    nukeCharge.value = 0;
    AudioService.instance.nuke();
    shake(26);
    missions.report(MissionMetric.useUltimate, 1);
    // Flash + wipe.
    for (final EnemyChicken e in List<EnemyChicken>.from(children.whereType<EnemyChicken>())) {
      e.takeDamage(99999);
    }
    for (final BossChicken b in children.whereType<BossChicken>()) {
      b.takeDamage(800);
    }
    add(Explosion(
      position: size / 2,
      color: Palette.hudYellow,
      particleCount: 60,
      maxRadius: size.x,
      lifetime: 1.0,
    ));
  }

  // ---------------------------------------------------------------------------
  // Power-ups.
  // ---------------------------------------------------------------------------
  void _maybeDropPowerUp(Vector2 pos, EnemyType from) {
    // ~12% base drop chance, weighted toward useful buffs.
    if (_rng.nextDouble() > 0.12) return;
    final List<PowerUpType> pool = <PowerUpType>[
      PowerUpType.health,
      PowerUpType.rapidFire,
      PowerUpType.shield,
      PowerUpType.doubleDamage,
      PowerUpType.magnet,
      PowerUpType.coinBurst,
      PowerUpType.timeFreeze,
    ];
    _spawnPowerUp(pos, pool[_rng.nextInt(pool.length)]);
  }

  void _spawnPowerUp(Vector2 pos, PowerUpType type) =>
      add(PowerUp(position: pos.clone(), type: type));

  void collectPowerUp(PowerUp p) {
    _powerUpsThisRun++;
    missions.report(MissionMetric.collectPowerUps, 1);
    AudioService.instance.powerUp();
    final PowerUpInfo info = p.info;
    switch (p.type) {
      case PowerUpType.health:
        _ship.heal(_ship.maxHealth * 0.35);
        break;
      case PowerUpType.coinBurst:
        _earnCoins(50 + _waves.wave * 5);
        AudioService.instance.coin();
        break;
      default:
        buffs.activate(p.type, info.duration);
    }
    p.removeFromParent();
  }

  void _applyMagnet(double dt) {
    for (final PowerUp p in children.whereType<PowerUp>()) {
      p.magnetTarget = true;
      final Vector2 dir = (_ship.position - p.position)..normalize();
      p.position += dir * 360 * dt;
    }
  }

  // ---------------------------------------------------------------------------
  // Economy + lifecycle.
  // ---------------------------------------------------------------------------
  void _earnCoins(int amount) {
    runCoins.value += amount;
    missions.report(MissionMetric.collectCoins, amount);
  }

  void pause() {
    if (state.value == RunState.playing) state.value = RunState.paused;
  }

  void resume() {
    if (state.value == RunState.paused) state.value = RunState.playing;
  }

  /// Called by the revive flow (rewarded ad) to bring the player back.
  void revivePlayer() {
    _ship.revive();
    state.value = RunState.playing;
    // Clear the screen so the player isn't instantly killed again.
    for (final EnemyChicken e in List<EnemyChicken>.from(children.whereType<EnemyChicken>())) {
      e.takeDamage(99999);
    }
  }

  bool _ended = false;
  void _endRun() {
    if (_ended) return;
    _ended = true;
    state.value = RunState.over;
    AudioService.instance.stopMusic();

    final int xpEarned = _killsThisRun * 2 + _bossKillsThisRun * 40 + _waves.wave * 5;
    final RunResult result = RunResult(
      score: score.value,
      wave: _waves.wave,
      coins: runCoins.value,
      kills: _killsThisRun,
      bossKills: _bossKillsThisRun,
      powerUps: _powerUpsThisRun,
      xp: xpEarned,
    );

    // Commit to the meta game.
    player.recordRun(score: result.score, wave: result.wave, coinsEarned: result.coins);
    if (player.addXp(xpEarned) > 0) AudioService.instance.levelUp();
    battlePass.addXp(result.wave * 10 + result.bossKills * 50);
    missions.report(MissionMetric.playRuns, 1);

    onRunOver(result);
  }
}

/// Immutable summary of a finished run, handed to the game-over screen.
class RunResult {
  const RunResult({
    required this.score,
    required this.wave,
    required this.coins,
    required this.kills,
    required this.bossKills,
    required this.powerUps,
    required this.xp,
  });

  final int score;
  final int wave;
  final int coins;
  final int kills;
  final int bossKills;
  final int powerUps;
  final int xp;
}
