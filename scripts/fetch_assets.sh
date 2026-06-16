#!/usr/bin/env bash
#
# Downloads the real CC0 / free sprite art + sound effects used by
# Chicken Hunter: Space War from GitHub-hosted mirrors and lays them out under
# assets/ with clean, stable filenames. Assets are committed to the repo so the
# CI / GitHub Pages build needs no network access.
#
# Re-run any time:  bash scripts/fetch_assets.sh
#
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMG="$ROOT/assets/images"
AUD="$ROOT/assets/audio"

KEN="https://raw.githubusercontent.com/Makiah/Safety-of-Space/master/Assets/Sprites/Kenney%20Assets/spaceshooter/PNG"
KSND="https://raw.githubusercontent.com/Calinou/kenney-interface-sounds/master/addons/kenney_interface_sounds"
PHA="https://raw.githubusercontent.com/photonstorm/phaser3-examples/master/public/assets"

mkdir -p "$IMG/ship" "$IMG/enemies" "$IMG/bullets" "$IMG/powerups" "$IMG/fx" "$IMG/bg" "$IMG/ui" "$AUD"

ok=0; fail=0
# fetch <url> <dest>
fetch() {
  local url="$1" dest="$2"
  if curl -fsSL --retry 3 --retry-delay 2 -m 30 "$url" -o "$dest" 2>/dev/null && [ -s "$dest" ]; then
    printf '  ok   %7sB  %s\n' "$(stat -c%s "$dest")" "${dest#$ROOT/}"
    ok=$((ok+1))
  else
    printf '  FAIL            %s\n' "$url"
    rm -f "$dest"
    fail=$((fail+1))
  fi
}

echo "== Player ships =="
fetch "$KEN/playerShip1_blue.png"   "$IMG/ship/player_falcon.png"
fetch "$KEN/playerShip2_orange.png" "$IMG/ship/player_viper.png"
fetch "$KEN/playerShip3_blue.png"   "$IMG/ship/player_titan.png"
fetch "$KEN/playerShip1_red.png"    "$IMG/ship/player_phoenix.png"
fetch "$KEN/Damage/playerShip1_damage1.png" "$IMG/ship/player_damage.png"

echo "== Enemy saucers / fighters =="
fetch "$KEN/ufoGreen.png"  "$IMG/enemies/normal.png"
fetch "$KEN/ufoYellow.png" "$IMG/enemies/fast.png"
fetch "$KEN/ufoBlue.png"   "$IMG/enemies/armored.png"
fetch "$KEN/ufoRed.png"    "$IMG/enemies/laser.png"
fetch "$KEN/Enemies/enemyRed1.png"   "$IMG/enemies/kamikaze.png"
fetch "$KEN/Enemies/enemyBlack4.png" "$IMG/enemies/miniboss.png"
fetch "$KEN/Enemies/enemyBlack5.png" "$IMG/enemies/galacticboss.png"
# Spares for wave-variant reskins.
fetch "$KEN/Enemies/enemyGreen3.png" "$IMG/enemies/variant1.png"
fetch "$KEN/Enemies/enemyBlue2.png"  "$IMG/enemies/variant2.png"

echo "== Lasers / projectiles =="
fetch "$KEN/Lasers/laserBlue01.png"  "$IMG/bullets/player_blue.png"
fetch "$KEN/Lasers/laserGreen01.png" "$IMG/bullets/player_green.png"
fetch "$KEN/Lasers/laserRed01.png"   "$IMG/bullets/enemy_red.png"
fetch "$KEN/Lasers/laserBlue08.png"  "$IMG/bullets/impact.png"

echo "== Power-ups =="
fetch "$KEN/Power-ups/powerupGreen_shield.png" "$IMG/powerups/shield.png"
fetch "$KEN/Power-ups/powerupBlue_bolt.png"    "$IMG/powerups/rapid.png"
fetch "$KEN/Power-ups/pill_red.png"            "$IMG/powerups/health.png"
fetch "$KEN/Power-ups/powerupRed_star.png"     "$IMG/powerups/damage.png"
fetch "$KEN/Power-ups/powerupYellow_star.png"  "$IMG/powerups/magnet.png"
fetch "$KEN/Power-ups/pill_blue.png"           "$IMG/powerups/freeze.png"
fetch "$KEN/Power-ups/star_gold.png"           "$IMG/powerups/coin.png"

echo "== FX =="
fetch "$KEN/Effects/fire00.png" "$IMG/fx/thruster0.png"
fetch "$KEN/Effects/fire01.png" "$IMG/fx/thruster1.png"
fetch "$KEN/Effects/shield1.png" "$IMG/fx/shield.png"
fetch "$PHA/sprites/explosion.png" "$IMG/fx/explosion_sheet.png"
fetch "$PHA/particles/blue.png"    "$IMG/fx/spark_blue.png"
fetch "$PHA/particles/yellow.png"  "$IMG/fx/spark_yellow.png"

echo "== Backgrounds =="
fetch "$PHA/skies/nebula.jpg"    "$IMG/bg/nebula.jpg"
fetch "$PHA/skies/starfield.png" "$IMG/bg/starfield.png"

echo "== UI =="
fetch "$KEN/UI/playerLife1_blue.png" "$IMG/ui/life.png"

echo "== Audio (SFX) =="
fetch "$KSND/click_001.wav"        "$AUD/click.wav"
fetch "$KSND/confirmation_001.wav" "$AUD/level_up.wav"
fetch "$KSND/drop_001.wav"         "$AUD/coin.wav"
fetch "$KSND/error_001.wav"        "$AUD/boss_roar.wav"
fetch "$KSND/switch_001.wav"       "$AUD/powerup.wav"
fetch "$KSND/glass_001.wav"        "$AUD/hit.wav"
fetch "$PHA/audio/SoundEffects/blaster.mp3"   "$AUD/laser.mp3"
fetch "$PHA/audio/SoundEffects/explosion.mp3" "$AUD/explosion.mp3"
fetch "$PHA/audio/SoundEffects/p-ping.mp3"    "$AUD/nuke.mp3"

echo ""
echo "Done. ok=$ok fail=$fail"
echo "(music: keeping the existing self-generated assets/audio/bgm_battle.wav)"
