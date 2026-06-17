# Image assets

The game currently renders **all** graphics programmatically (ships, chickens,
bosses, bullets, power-ups, particles) using Flutter's `Canvas`, so it runs with
**zero image files**. This keeps the APK tiny and the art fully recolourable for
seasonal events.

To swap in hand-drawn cartoon art later, drop sprite sheets here and load them
through Flame's `Sprite` / `SpriteAnimation` in the relevant component's
`onLoad()`. Suggested set:

| File                  | Used by                         |
|-----------------------|---------------------------------|
| `ship_falcon.png`     | `PlayerShip` (per ship id)      |
| `chicken_normal.png`  | `EnemyChicken`                  |
| `chicken_*.png`       | one per `EnemyType`             |
| `boss_galactic.png`   | `BossChicken`                   |
| `powerup_*.png`       | `PowerUp`                       |
| `bullet_*.png`        | `Bullet` per weapon             |
| `explosion_sheet.png` | `Explosion` (animation frames)  |

Keep textures power-of-two and use a texture atlas for best performance on
low-end devices.
