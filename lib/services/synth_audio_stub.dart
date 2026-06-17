/// Non-web stub — all methods are no-ops.
class SynthAudio {
  SynthAudio._();
  static final SynthAudio instance = SynthAudio._();
  void init() {}
  void laser() {}
  void hit() {}
  void explosion() {}
  void punchLight() {}
  void punchHeavy() {}
  void kickLight() {}
  void kickHeavy() {}
  void block() {}
  void ko() {}
  void countdownBeep() {}
  void fightStart() {}
  void startBgm() {}
  void stopBgm() {}
  bool sfxEnabled = true;
  bool musicEnabled = true;
}
