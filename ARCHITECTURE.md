# Architecture

This document explains how Chicken Hunter: Space War is structured and the
reasoning behind the main decisions, so the codebase scales as you add content.

## Layered design

```
┌─────────────────────────────────────────────────────────┐
│ ui/            Flutter screens & widgets (menus, HUD)     │  presentation
├─────────────────────────────────────────────────────────┤
│ game/          Flame engine: loop, components, AI         │  realtime sim
├─────────────────────────────────────────────────────────┤
│ systems/       Meta-game rules (wallet, missions, pass)   │  domain logic
├─────────────────────────────────────────────────────────┤
│ services/      Firebase, AdMob, IAP, audio, cloud save    │  integrations
├─────────────────────────────────────────────────────────┤
│ models/        Pure data + (de)serialisation             │  data
│ config/        Constants, palette, tunables               │
└─────────────────────────────────────────────────────────┘
```

Dependencies point **downward only**. The Flame `game/` layer never imports
`ui/` widgets — it communicates upward through `ValueNotifier`s and callbacks.
This keeps the engine testable in isolation and avoids rebuild storms.

## Key decisions

### State management: Provider + ChangeNotifier
The meta systems (`PlayerController`, `MissionSystem`, `BattlePassSystem`,
`AchievementSystem`) are `ChangeNotifier`s provided at the root. Screens
`watch` them and rebuild reactively. Lightweight, well-understood, no codegen.

### Single source of truth for the save
`PlayerData` is the **only** persisted object. Mutations go through
`PlayerController` guarded methods (e.g. `spendCoins`) so balances can't go
negative and so persistence + analytics hook in one place. `SaveSystem` handles
local JSON; `CloudSaveService` mirrors it to Firestore with last-write-wins.

### Data-driven content
Enemies (`EnemyStats.table`), weapons (`WeaponData.table`), ships
(`ShipData.all`), power-ups, achievements, and the battle-pass curve are all
declared as data. Adding a new chicken type or weapon is mostly a table entry
plus (for enemies) a behaviour branch. Difficulty scaling lives in
`EnemyStats.scaledFor(wave)` so the whole curve is tuned in one method.

### The game loop
`ChickenHunterGame` (a Flame `FlameGame`) owns:
- **Input**: `DragCallbacks` turn the finger position into the ship's target;
  the ship eases toward it for smooth motion.
- **Spawning**: `WaveManager` decides what/when to spawn (boss cadence, variety
  ramp). `BuffManager` tracks timed power-up effects.
- **Collisions**: Flame's `HasCollisionDetection` + `CircleHitbox`. Resolution
  lives in the entity that's hit (`onCollisionStart`), keeping each entity's
  rules local. Bullets carry their own damage/AOE/pierce flags.
- **Results**: combat events bump score/coins and report to missions &
  achievements; `RunResult` is handed to the game-over UI and committed to the
  wallet/battle pass on death.

### AI summary
- **Enemies** (`EnemyChicken`): one class, behaviour branched by `EnemyType`
  (weave, dive, tank, strafe-and-shoot, home-in kamikaze).
- **Bosses** (`BossChicken`): a small state machine cycling attack patterns
  (spread, aimed burst, radial bullet-hell, escort summon), escalating across
  3 health phases.

### Performance
- All art is canvas-drawn — no texture upload, tiny APK.
- `GameConfig.particleBudget` / `starCount` cap effects for low-end devices.
- Off-screen bullets/enemies self-despawn. HUD repaints via `ValueListenable`,
  independent of the render loop.

### Fail-soft integrations
Every service (Firebase, Ads, IAP, Audio) is guarded by a feature flag and
try/catch so a missing config or offline device degrades gracefully instead of
crashing. The game is fully playable with all integrations off.

## Testing strategy (suggested)
- **Unit-test the systems**: spending/earning, level-ups, daily streak math,
  mission progress/claim, battle-pass tier-ups. They're pure Dart, no Flutter.
- **Golden-test** key widgets (currency bar, game-over overlay).
- **Component tests** with `flame_test` for collision/damage resolution.

## Extending the game
- **New enemy**: add an `EnemyType`, an `EnemyStats` row, a behaviour branch in
  `EnemyChicken.update`, optionally a render tweak.
- **New weapon**: add a `WeaponType`, a `WeaponData` row; firing already reads
  the table. Add special projectile behaviour in `Bullet` if needed.
- **New ship**: add a `ShipData` entry — hangar/upgrades pick it up.
- **New mission/achievement**: add to the seed list / `Achievement.all`.
