import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

import '../config/game_config.dart';

/// Central SFX + music controller. Pre-caches short SFX so playback is
/// latency-free during combat, and manages a single looping background track.
///
/// Drop your audio files in `assets/audio/` with the names referenced below.
/// Missing files fail soft (logged, not crashed) so the game runs silent until
/// you add real audio.
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  bool sfxEnabled = true;
  bool musicEnabled = true;
  bool _cached = false;

  static const List<String> _sfx = <String>[
    'laser.wav',
    'explosion.mp3',
    'hit.wav',
    'powerup.wav',
    'coin.wav',
    'boss_roar.wav',
    'nuke.mp3',
    'click.wav',
    'level_up.wav',
  ];

  Future<void> init() async {
    if (!GameConfig.enableAudio) return;
    try {
      await FlameAudio.audioCache.loadAll(_sfx);
      _cached = true;
    } catch (e) {
      debugPrint('Audio preload skipped (add files to assets/audio/): $e');
    }
  }

  void play(String file, {double volume = 1.0}) {
    if (!GameConfig.enableAudio || !sfxEnabled || !_cached) return;
    try {
      FlameAudio.play(file, volume: volume);
    } catch (_) {/* fail soft */}
  }

  void laser() => play('laser.wav', volume: 0.4);
  void explosion() => play('explosion.mp3', volume: 0.6);
  void hit() => play('hit.wav', volume: 0.55);
  void powerUp() => play('powerup.wav', volume: 0.6);
  void coin() => play('coin.wav', volume: 0.5);
  void bossRoar() => play('boss_roar.wav', volume: 0.7);
  void nuke() => play('nuke.mp3', volume: 0.8);
  void click() => play('click.wav', volume: 0.6);
  void levelUp() => play('level_up.wav', volume: 0.7);

  void startMusic([String track = 'bgm_battle.wav']) {
    if (!GameConfig.enableAudio || !musicEnabled) return;
    try {
      FlameAudio.bgm.initialize();
      FlameAudio.bgm.play(track, volume: 0.35);
    } catch (e) {
      debugPrint('Music skipped (add $track to assets/audio/): $e');
    }
  }

  void stopMusic() {
    try {
      FlameAudio.bgm.stop();
    } catch (_) {}
  }
}
