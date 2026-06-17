// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js' as js;

/// Web Audio API synthesiser — generates all SFX and background music
/// procedurally (no audio files needed).
///
/// Call [init] once at startup (e.g. from AudioService.init()), then call the
/// individual methods from game code exactly as you would AudioService.
class SynthAudio {
  SynthAudio._();
  static final SynthAudio instance = SynthAudio._();

  bool sfxEnabled = true;
  bool musicEnabled = true;
  bool _injected = false;

  // ── Bootstrap ─────────────────────────────────────────────────────────────

  void init() {
    if (_injected) return;
    _injected = true;
    final script = html.ScriptElement()..text = _kJsCode;
    html.document.head!.append(script);
  }

  // ── SFX ───────────────────────────────────────────────────────────────────

  void laser() {
    if (!sfxEnabled) return;
    _call('synthLaser');
  }

  void hit() {
    if (!sfxEnabled) return;
    _call('synthHit');
  }

  void explosion() {
    if (!sfxEnabled) return;
    _call('synthExplosion');
  }

  // ── Background music ──────────────────────────────────────────────────────

  void startBgm() {
    if (!musicEnabled) return;
    _call('synthStartBgm');
  }

  void stopBgm() {
    _call('synthStopBgm');
  }

  // ── Helper ────────────────────────────────────────────────────────────────

  void _call(String fn) {
    try {
      js.context.callMethod(fn, <dynamic>[]);
    } catch (_) {}
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Embedded JavaScript — all Web Audio API logic lives here.
// ─────────────────────────────────────────────────────────────────────────────

const String _kJsCode = r'''
(function () {
  var _ctx = null;
  var _bgmMaster = null;
  var _bgmNodes = [];
  var _pulseTimer = null;

  function ctx() {
    if (!_ctx) {
      _ctx = new (window.AudioContext || window.webkitAudioContext)();
    }
    if (_ctx.state === 'suspended') _ctx.resume();
    return _ctx;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  function osc(type, freq) {
    var o = ctx().createOscillator();
    o.type = type;
    o.frequency.value = freq;
    return o;
  }

  function gain(val) {
    var g = ctx().createGain();
    g.gain.value = val;
    return g;
  }

  function connect(chain, dest) {
    for (var i = 0; i < chain.length - 1; i++) chain[i].connect(chain[i + 1]);
    chain[chain.length - 1].connect(dest || ctx().destination);
  }

  // ── Laser shot ───────────────────────────────────────────────────────────

  window.synthLaser = function () {
    var c = ctx();
    var now = c.currentTime;

    var o = osc('sawtooth', 1400);
    var g = gain(0);

    // Frequency sweep: 1400 Hz → 280 Hz in 0.11 s
    o.frequency.setValueAtTime(1400, now);
    o.frequency.exponentialRampToValueAtTime(280, now + 0.11);

    // Amplitude envelope: quick attack, short decay
    g.gain.setValueAtTime(0, now);
    g.gain.linearRampToValueAtTime(0.22, now + 0.006);
    g.gain.exponentialRampToValueAtTime(0.001, now + 0.14);

    connect([o, g]);
    o.start(now);
    o.stop(now + 0.15);
  };

  // ── Enemy hit ────────────────────────────────────────────────────────────

  window.synthHit = function () {
    var c = ctx();
    var now = c.currentTime;

    // Metallic "thwack" — square wave pitch drop
    var o = osc('square', 220);
    var g = gain(0);

    o.frequency.setValueAtTime(220, now);
    o.frequency.exponentialRampToValueAtTime(60, now + 0.07);

    g.gain.setValueAtTime(0, now);
    g.gain.linearRampToValueAtTime(0.28, now + 0.004);
    g.gain.exponentialRampToValueAtTime(0.001, now + 0.09);

    connect([o, g]);
    o.start(now);
    o.stop(now + 0.10);

    // Short noise crackle layer
    var sr = c.sampleRate;
    var len = Math.floor(sr * 0.06);
    var buf = c.createBuffer(1, len, sr);
    var d = buf.getChannelData(0);
    for (var i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;
    var src = c.createBufferSource();
    src.buffer = buf;
    var flt = c.createBiquadFilter();
    flt.type = 'bandpass';
    flt.frequency.value = 2000;
    flt.Q.value = 0.6;
    var gn = gain(0);
    gn.gain.setValueAtTime(0.15, now);
    gn.gain.exponentialRampToValueAtTime(0.001, now + 0.06);
    connect([src, flt, gn]);
    src.start(now);
    src.stop(now + 0.07);
  };

  // ── Big explosion ─────────────────────────────────────────────────────────

  window.synthExplosion = function () {
    var c = ctx();
    var now = c.currentTime;
    var sr = c.sampleRate;

    // --- Noise burst (mid-range crunch) ---
    var nLen = Math.floor(sr * 1.2);
    var nBuf = c.createBuffer(1, nLen, sr);
    var nDat = nBuf.getChannelData(0);
    for (var i = 0; i < nLen; i++) nDat[i] = Math.random() * 2 - 1;
    var noise = c.createBufferSource();
    noise.buffer = nBuf;

    var flt = c.createBiquadFilter();
    flt.type = 'lowpass';
    flt.frequency.setValueAtTime(800, now);
    flt.frequency.exponentialRampToValueAtTime(120, now + 0.5);

    var nGain = gain(0);
    nGain.gain.setValueAtTime(0, now);
    nGain.gain.linearRampToValueAtTime(1.1, now + 0.01);
    nGain.gain.exponentialRampToValueAtTime(0.001, now + 1.1);

    connect([noise, flt, nGain]);
    noise.start(now);
    noise.stop(now + 1.2);

    // --- Sub bass punch (deep boom) ---
    var sub = osc('sine', 90);
    var subG = gain(0);
    sub.frequency.setValueAtTime(90, now);
    sub.frequency.exponentialRampToValueAtTime(28, now + 0.45);
    subG.gain.setValueAtTime(0, now);
    subG.gain.linearRampToValueAtTime(1.2, now + 0.008);
    subG.gain.exponentialRampToValueAtTime(0.001, now + 0.50);
    connect([sub, subG]);
    sub.start(now);
    sub.stop(now + 0.55);

    // --- Mid crack (sharp transient) ---
    var crk = osc('triangle', 300);
    var crkG = gain(0);
    crk.frequency.setValueAtTime(300, now);
    crk.frequency.exponentialRampToValueAtTime(80, now + 0.12);
    crkG.gain.setValueAtTime(0, now);
    crkG.gain.linearRampToValueAtTime(0.5, now + 0.005);
    crkG.gain.exponentialRampToValueAtTime(0.001, now + 0.14);
    connect([crk, crkG]);
    crk.start(now);
    crk.stop(now + 0.15);
  };

  // ── Epic space background music ────────────────────────────────────────────
  // A-minor feel: deep drones, slow moving pads, shimmer highs, bass pulses.

  window.synthStartBgm = function () {
    synthStopBgm();
    var c = ctx();
    var now = c.currentTime;

    _bgmMaster = gain(0);
    _bgmMaster.connect(c.destination);
    _bgmMaster.gain.setValueAtTime(0, now);
    _bgmMaster.gain.linearRampToValueAtTime(0.22, now + 4.0); // slow fade-in

    // Helper — attach a slow LFO to a gain's .gain param
    function addLfo(targetParam, rate, depth) {
      var l = c.createOscillator();
      l.type = 'sine';
      l.frequency.value = rate;
      var lg = c.createGain();
      lg.gain.value = depth;
      l.connect(lg);
      lg.connect(targetParam);
      l.start(now);
      _bgmNodes.push(l);
    }

    // — Deep sub drone (A1 = 55 Hz) ——————————————————————————————
    var sub = c.createOscillator();
    sub.type = 'sine';
    sub.frequency.value = 55;
    var subG = gain(0.55);
    addLfo(subG.gain, 0.06, 0.12);
    sub.connect(subG);
    subG.connect(_bgmMaster);
    sub.start(now);
    _bgmNodes.push(sub);

    // — Main chord pad (A-minor voicing: A2 E3 A3 C4 E4) —————————————
    var padFreqs = [110, 164.81, 220, 261.63, 329.63];
    padFreqs.forEach(function (f, idx) {
      var p = c.createOscillator();
      p.type = 'triangle';
      p.frequency.value = f;
      // Slight detuning for warmth
      p.detune.value = (idx % 2 === 0 ? 1 : -1) * (idx + 1) * 3;
      var pg = gain(0.10);
      addLfo(pg.gain, 0.07 + idx * 0.02, 0.025);
      p.connect(pg);
      pg.connect(_bgmMaster);
      p.start(now);
      _bgmNodes.push(p);
    });

    // — High shimmer strings (A4 E5 A5 = 440, 659, 880) ——————————————
    var shimFreqs = [440, 659.26, 880, 1046.50];
    shimFreqs.forEach(function (f, idx) {
      var s = c.createOscillator();
      s.type = 'sine';
      s.frequency.value = f;
      var sg = gain(0.022);
      addLfo(sg.gain, 0.09 + idx * 0.03, 0.012);
      s.connect(sg);
      sg.connect(_bgmMaster);
      s.start(now);
      _bgmNodes.push(s);
    });

    // — Vibrato on shimmer via pitch LFO ——————————————————————————
    // Already covered by detuning + gain LFOs above.

    // — Rhythmic bass pulse every ~1.4 s ——————————————————————————
    function pulse() {
      if (!_bgmMaster) return;
      var t = ctx().currentTime;
      var pb = c.createOscillator();
      pb.type = 'sine';
      pb.frequency.setValueAtTime(80, t);
      pb.frequency.exponentialRampToValueAtTime(35, t + 0.35);
      var pg = gain(0);
      pg.gain.setValueAtTime(0, t);
      pg.gain.linearRampToValueAtTime(0.40, t + 0.012);
      pg.gain.exponentialRampToValueAtTime(0.001, t + 0.40);
      pb.connect(pg);
      pg.connect(_bgmMaster);
      pb.start(t);
      pb.stop(t + 0.42);
      _pulseTimer = setTimeout(pulse, 1400);
    }
    _pulseTimer = setTimeout(pulse, 800);

    // — Occasional high chime (every ~6 s) ————————————————————————
    function chime() {
      if (!_bgmMaster) return;
      var t = ctx().currentTime;
      var ch = c.createOscillator();
      ch.type = 'sine';
      ch.frequency.setValueAtTime(2093, t); // C7
      var cg = gain(0);
      cg.gain.setValueAtTime(0, t);
      cg.gain.linearRampToValueAtTime(0.09, t + 0.01);
      cg.gain.exponentialRampToValueAtTime(0.001, t + 1.2);
      ch.connect(cg);
      cg.connect(_bgmMaster);
      ch.start(t);
      ch.stop(t + 1.3);
      setTimeout(chime, 5000 + Math.random() * 4000);
    }
    setTimeout(chime, 3000);
  };

  window.synthStopBgm = function () {
    if (_pulseTimer) { clearTimeout(_pulseTimer); _pulseTimer = null; }
    if (_bgmMaster) {
      var t = ctx().currentTime;
      _bgmMaster.gain.cancelScheduledValues(t);
      _bgmMaster.gain.setValueAtTime(_bgmMaster.gain.value, t);
      _bgmMaster.gain.linearRampToValueAtTime(0, t + 1.5);
      var captured = { nodes: _bgmNodes.slice(), master: _bgmMaster };
      _bgmNodes = [];
      _bgmMaster = null;
      setTimeout(function () {
        captured.nodes.forEach(function (n) { try { n.stop(); } catch (e) {} });
      }, 1600);
    }
  };
})();
''';
