# 🐔 Chicken Hunter: Space War

A fast-paced 2D space shooter built with **Flutter + Flame**. Drag your ship
around the screen while it auto-fires at endless waves of space chickens, fight
mini-bosses and giant galactic chicken bosses, collect power-ups, and grind a
deep meta-game of coins, gems, XP, weapons, ships, missions, a battle pass, and
more.

> **Status:** production-grade *architecture* and a fully playable core game.
> Graphics are rendered programmatically (no asset files required), so it builds
> and runs immediately. Drop in your own art/audio and Firebase/AdMob keys to
> ship. See [What's included vs. what you add](#whats-included-vs-what-you-add).

---

## ✨ Features

### Gameplay
- **Drag-to-move, auto-fire** ship control — one-thumb friendly.
- **7 enemy types**, each with distinct AI: normal, fast, armored, laser-shooter,
  kamikaze, mini-boss, and the giant galactic boss (multi-phase bullet-hell).
- **5 weapons**: Pulse Laser, Plasma Cannon, Rocket Pod (AOE), Lightning Gun
  (pierce), and the **Nuclear Strike** ultimate (charges by kills).
- **7 power-ups**: shield, rapid fire, repair, magnet, double damage, time
  freeze, coin burst.
- **Endless wave system** with boss every 5th wave and a giant boss every 10th,
  scaling difficulty + rewards.

### Progression & meta
- Coins, gems, XP, player levels with level-up rewards.
- Weapon upgrades, ship-system upgrades, unlockable ships (4 ships).
- Daily login rewards (7-day streak), daily/weekly **missions**, permanent
  **achievements**, 30-tier seasonal **battle pass** (free + premium tracks).
- Global **leaderboard**, **cloud save** (anonymous auth + Firestore).

### Monetisation
- **AdMob**: banner, interstitial (throttled), rewarded (revive, 2× coins,
  free gems).
- **In-app purchases**: gem packs, remove ads, starter pack, battle pass.

### Tech
- Offline-first save; cloud sync layered on top (last-write-wins).
- Firebase Analytics + Remote Config for live-ops tuning.
- Performance budget knobs for low-end devices (particles, star density).

---

## 🚀 Quick start

```bash
# 1. Install Flutter 3.19+  (https://docs.flutter.dev/get-started/install)
flutter --version

# 2. Materialise the generated native glue (Gradle wrapper, default mipmap
#    densities, etc.) WITHOUT touching the committed lib/ or android configs.
#    This is a one-time step because binary files (gradle-wrapper.jar, raster
#    icons) can't live in source nicely.
flutter create --org com.chickenhunter --project-name chicken_hunter_space_war .

# 3. Get packages
flutter pub get

# 4. Run on a connected Android device / emulator
flutter run
```

> `flutter create .` is non-destructive: it only adds missing scaffolding and
> leaves all the game code, Gradle, and manifest customisations in this repo
> intact. A themed vector launcher icon is already provided.

The game runs fully offline out of the box (test AdMob IDs, Firebase disabled-
safe). To wire real backend/monetisation, follow:

- **[FIREBASE_SETUP.md](FIREBASE_SETUP.md)** — cloud save, auth, leaderboard,
  analytics, remote config.
- **[DEPLOYMENT.md](DEPLOYMENT.md)** — signing, AdMob/IAP setup, and Play Store
  release.
- **[ARCHITECTURE.md](ARCHITECTURE.md)** — how the code is organised and why.

---

## 🌐 Play in the browser (GitHub Pages)

A GitHub Actions workflow (`.github/workflows/deploy-web.yml`) builds the Flutter
**web** version and publishes it to GitHub Pages on every push to the main dev
branch.

**One-time setup:** in the repo, go to **Settings → Pages → Build and deployment**
and set **Source** to **GitHub Actions**. After the next push (or a manual run
from the **Actions** tab), the game is live at:

```
https://<your-username>.github.io/<repo-name>/
```

The workflow auto-detects the repo name for the correct base path, generates the
`web/` scaffolding, and builds with the CanvasKit renderer for smooth particle
performance. Mobile-only plugins (AdMob, Play Billing) are automatically
disabled on web via `kIsWeb`, so the browser build is clean and ad-free.

---

## 🗂 Project structure

```
lib/
  main.dart                  # bootstrap: services, providers, runApp
  config/                    # game config, palette, tunables
  models/                    # pure data: player, enemies, weapons, ships, etc.
  systems/                   # meta-game logic (wallet, missions, battle pass…)
  services/                  # Firebase, AdMob, IAP, audio, cloud save
  game/                      # the Flame engine
    chicken_hunter_game.dart # main game loop / orchestration
    components/              # ship, enemies, bosses, bullets, power-ups, fx
    managers/                # wave + buff managers
  ui/                        # Flutter screens & widgets (menu, shop, HUD…)
assets/                      # images / audio / data (placeholders + docs)
android/                     # Android Gradle + manifest config
```

---

## 🎮 Controls

| Action            | Input                                  |
|-------------------|----------------------------------------|
| Move ship         | Drag anywhere on the battlefield        |
| Fire              | Automatic                               |
| Ultimate (Nuke)   | Tap the ☢ button when fully charged     |
| Pause             | Top-left pause icon                     |

---

## What's included vs. what you add

| Included (works now)                              | You add for release                         |
|---------------------------------------------------|---------------------------------------------|
| Full gameplay, all systems, all screens           | Hand-drawn sprites & audio (optional)       |
| Programmatic graphics + particle FX                | `google-services.json` (Firebase)           |
| Test AdMob unit IDs                                | Real AdMob app + unit IDs                    |
| IAP product IDs + flow                             | Products created in Play Console             |
| Offline save                                       | Release keystore + signing                   |
| Firebase service code (disabled-safe)              | `flutterfire configure` run                  |

---

## 🧪 Tooling

```bash
flutter analyze        # static analysis (analysis_options.yaml)
flutter test           # unit tests (add under test/)
flutter build apk --release
flutter build appbundle --release   # for Play Store
```

Built with the Flame engine. Have fun hunting chickens across the galaxy. 🐔🚀
