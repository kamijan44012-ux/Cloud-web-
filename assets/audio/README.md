# Audio assets

`AudioService` preloads these short SFX (fail-soft: the game runs silent until
you add them). Drop royalty-free `.wav` files here with these exact names:

```
laser.wav        explosion.wav    hit.wav
powerup.wav      coin.wav         boss_roar.wav
nuke.wav         click.wav        level_up.wav
```

Background music (looped) — add as `.mp3`:

```
bgm_battle.mp3   # in-game
```

Good free sources: freesound.org, OpenGameArt, Kenney.nl audio packs. Keep SFX
under ~100 ms and mono to minimise latency and memory on low-end devices.
