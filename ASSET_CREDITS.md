# Asset Credits

All third-party art and audio in this game is free to use. Assets are fetched by
`scripts/fetch_assets.sh` from GitHub-hosted mirrors and committed under `assets/`.

## Sprite art — Kenney "Space Shooter Redux" (CC0 1.0 / Public Domain)
Author: **Kenney** (https://kenney.nl) · License: **CC0 1.0** (no attribution required,
included as courtesy). Fetched via mirror repo `Makiah/Safety-of-Space`.
Used for: player ships (`assets/images/ship/`), enemy saucers & fighters
(`assets/images/enemies/`), lasers (`assets/images/bullets/`), power-up icons
(`assets/images/powerups/`), thruster/shield FX (`assets/images/fx/`), UI life icon
(`assets/images/ui/`).

## UI / feedback SFX — Kenney "Interface Sounds" (CC0 1.0)
Author: **Kenney** · License: **CC0 1.0**. Fetched from `Calinou/kenney-interface-sounds`.
Used for: `click.wav`, `level_up.wav` (confirmation), `coin.wav` (drop),
`boss_roar.wav` (error), `powerup.wav` (switch), `hit.wav` (glass).

## Combat SFX, explosion animation, nebula, particles — `photonstorm/phaser3-examples`
Fetched from the public Phaser 3 examples asset bundle.
Files: `laser.mp3`, `explosion.mp3`, `nuke.mp3` (p-ping), `fx/explosion_sheet.png`,
`fx/spark_blue.png`, `fx/spark_yellow.png`, `bg/nebula.jpg`, `bg/starfield.png`.
⚠ **License note:** the Phaser examples asset bundle is a MIXED-license collection — these
specific items are NOT guaranteed CC0. They are fine for a free/demo build, but **before any
commercial / store release, replace them with confirmed-CC0 equivalents** (e.g. Kenney
"Sci-Fi Sounds" / a CC0 explosion sheet) or verify each item's individual license.

## Background music
`assets/audio/bgm_battle.wav` is **procedurally generated** by `scripts/generate_audio.py`
(original to this project, no third-party rights).

---
To refresh or re-source assets, edit and re-run `scripts/fetch_assets.sh`.
