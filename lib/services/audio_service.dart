import 'package:flutter/foundation.dart';

import 'synth_audio.dart';

/// Central SFX + music controller.
/// On web: delegates to [SynthAudio] which synthesises all audio via the
/// Web Audio API — no asset files required.
/// On other platforms: SynthAudio is a no-op stub.
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  SynthAudio get _synth => SynthAudio.instance;

  bool get sfxEnabled => _synth.sfxEnabled;
  set sfxEnabled(bool v) => _synth.sfxEnabled = v;

  bool get musicEnabled => _synth.musicEnabled;
  set musicEnabled(bool v) => _synth.musicEnabled = v;

  Future<void> init() async {
    if (kIsWeb) {
      _synth.init();
    }
  }

  void laser()    => _synth.laser();
  void hit()      => _synth.hit();
  void explosion()=> _synth.explosion();
  void powerUp()  {}
  void coin()     {}
  void bossRoar() {}
  void nuke()     => _synth.explosion();
  void click()    {}
  void levelUp()  {}

  void startMusic([String _track = 'bgm_battle.wav']) => _synth.startBgm();
  void stopMusic() => _synth.stopBgm();

  // Fight game sounds
  void playPunchLight()    => _synth.punchLight();
  void playPunchHeavy()    => _synth.punchHeavy();
  void playKickLight()     => _synth.kickLight();
  void playKickHeavy()     => _synth.kickHeavy();
  void playBlock()         => _synth.block();
  void playKo()            => _synth.ko();
  void playCountdownBeep() => _synth.countdownBeep();
  void playFightStart()    => _synth.fightStart();
}
