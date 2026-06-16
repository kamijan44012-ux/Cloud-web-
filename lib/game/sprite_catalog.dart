import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';

import '../models/enemy_type.dart';
import '../models/power_up_type.dart';

/// Loads and holds every game sprite + the explosion animation once, up front.
/// Components read sprites from [instance] in their render methods instead of
/// drawing shapes. All images live under assets/images/ (Flame's image-cache
/// prefix), so load paths are relative to that folder.
class SpriteCatalog {
  SpriteCatalog._();
  static final SpriteCatalog instance = SpriteCatalog._();

  bool _loaded = false;
  bool get isLoaded => _loaded;

  // Ships.
  late final Map<String, Sprite> ships;
  late final Sprite playerDamage;

  // Projectiles + impact.
  late final Sprite laserPlayer;
  late final Sprite laserPlayerAlt;
  late final Sprite laserEnemy;
  late final Sprite impact;

  // FX.
  late final Sprite thruster0;
  late final Sprite thruster1;
  late final Sprite shield;
  late final Sprite sparkBlue;
  late final Sprite sparkYellow;
  late final SpriteAnimation explosion; // 5x5 @ 64px

  // Background.
  late final Sprite nebula;
  late final Sprite starfield;

  // Enemies + power-ups, keyed by type.
  final Map<EnemyType, Sprite> enemies = <EnemyType, Sprite>{};
  final List<Sprite> enemyVariants = <Sprite>[];
  final Map<PowerUpType, Sprite> powerups = <PowerUpType, Sprite>{};

  Future<void> load(Images images) async {
    if (_loaded) return;

    Future<Sprite> s(String p) async => Sprite(await images.load(p));

    ships = <String, Sprite>{
      'falcon': await s('ship/player_falcon.png'),
      'viper': await s('ship/player_viper.png'),
      'titan': await s('ship/player_titan.png'),
      'phoenix': await s('ship/player_phoenix.png'),
    };
    playerDamage = await s('ship/player_damage.png');

    laserPlayer = await s('bullets/player_blue.png');
    laserPlayerAlt = await s('bullets/player_green.png');
    laserEnemy = await s('bullets/enemy_red.png');
    impact = await s('bullets/impact.png');

    thruster0 = await s('fx/thruster0.png');
    thruster1 = await s('fx/thruster1.png');
    shield = await s('fx/shield.png');
    sparkBlue = await s('fx/spark_blue.png');
    sparkYellow = await s('fx/spark_yellow.png');

    nebula = await s('bg/nebula.jpg');
    starfield = await s('bg/starfield.png');

    enemies[EnemyType.normal] = await s('enemies/normal.png');
    enemies[EnemyType.fast] = await s('enemies/fast.png');
    enemies[EnemyType.armored] = await s('enemies/armored.png');
    enemies[EnemyType.laser] = await s('enemies/laser.png');
    enemies[EnemyType.kamikaze] = await s('enemies/kamikaze.png');
    enemies[EnemyType.miniBoss] = await s('enemies/miniboss.png');
    enemies[EnemyType.galacticBoss] = await s('enemies/galacticboss.png');
    enemyVariants
      ..add(await s('enemies/variant1.png'))
      ..add(await s('enemies/variant2.png'));

    powerups[PowerUpType.shield] = await s('powerups/shield.png');
    powerups[PowerUpType.rapidFire] = await s('powerups/rapid.png');
    powerups[PowerUpType.health] = await s('powerups/health.png');
    powerups[PowerUpType.doubleDamage] = await s('powerups/damage.png');
    powerups[PowerUpType.magnet] = await s('powerups/magnet.png');
    powerups[PowerUpType.timeFreeze] = await s('powerups/freeze.png');
    powerups[PowerUpType.coinBurst] = await s('powerups/coin.png');

    // Explosion sprite-sheet → 25-frame one-shot animation.
    final sheetImg = await images.load('fx/explosion_sheet.png');
    final SpriteSheet sheet = SpriteSheet(image: sheetImg, srcSize: Vector2.all(64));
    final List<Sprite> frames = <Sprite>[];
    for (int r = 0; r < 5; r++) {
      for (int c = 0; c < 5; c++) {
        frames.add(sheet.getSprite(r, c));
      }
    }
    explosion = SpriteAnimation.spriteList(frames, stepTime: 0.03, loop: false);

    _loaded = true;
  }

  Sprite ship(String id) => ships[id] ?? ships['falcon']!;

  /// Enemy sprite for a type, optionally reskinned for deeper wave tiers.
  Sprite enemy(EnemyType type, {int variant = 0}) {
    if (variant > 0 && !EnemyStats.table[type]!.isBoss && enemyVariants.isNotEmpty) {
      return enemyVariants[(variant - 1) % enemyVariants.length];
    }
    return enemies[type] ?? enemies[EnemyType.normal]!;
  }
}
