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

  // ── Fight SFX ─────────────────────────────────────────────────────────────

  void punchLight() {
    if (!sfxEnabled) return;
    _call('synthPunchLight');
  }

  void punchHeavy() {
    if (!sfxEnabled) return;
    _call('synthPunchHeavy');
  }

  void kickLight() {
    if (!sfxEnabled) return;
    _call('synthKickLight');
  }

  void kickHeavy() {
    if (!sfxEnabled) return;
    _call('synthKickHeavy');
  }

  void block() {
    if (!sfxEnabled) return;
    _call('synthBlock');
  }

  void ko() {
    if (!sfxEnabled) return;
    _call('synthKo');
  }

  void countdownBeep() {
    if (!sfxEnabled) return;
    _call('synthCountdownBeep');
  }

  void fightStart() {
    if (!sfxEnabled) return;
    _call('synthFightStart');
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

  function noise(c, dur) {
    var sr = c.sampleRate;
    var len = Math.floor(sr * dur);
    var buf = c.createBuffer(1, len, sr);
    var d = buf.getChannelData(0);
    for (var i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;
    var src = c.createBufferSource();
    src.buffer = buf;
    return src;
  }

  // ── Laser shot ───────────────────────────────────────────────────────────

  window.synthLaser = function () {
    var c = ctx();
    var now = c.currentTime;

    var o = osc('sawtooth', 1400);
    var g = gain(0);

    o.frequency.setValueAtTime(1400, now);
    o.frequency.exponentialRampToValueAtTime(280, now + 0.11);

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

    var src = noise(c, 0.06);
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

    var nSrc = noise(c, 1.2);
    var flt = c.createBiquadFilter();
    flt.type = 'lowpass';
    flt.frequency.setValueAtTime(800, now);
    flt.frequency.exponentialRampToValueAtTime(120, now + 0.5);
    var nGain = gain(0);
    nGain.gain.setValueAtTime(0, now);
    nGain.gain.linearRampToValueAtTime(1.1, now + 0.01);
    nGain.gain.exponentialRampToValueAtTime(0.001, now + 1.1);
    connect([nSrc, flt, nGain]);
    nSrc.start(now);
    nSrc.stop(now + 1.2);

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

  // ── Fight: Punch Light ───────────────────────────────────────────────────

  window.synthPunchLight = function () {
    var c = ctx();
    var now = c.currentTime;

    var o = osc('square', 180);
    var g = gain(0);
    o.frequency.setValueAtTime(180, now);
    o.frequency.exponentialRampToValueAtTime(60, now + 0.08);
    g.gain.setValueAtTime(0, now);
    g.gain.linearRampToValueAtTime(0.30, now + 0.004);
    g.gain.exponentialRampToValueAtTime(0.001, now + 0.10);
    connect([o, g]);
    o.start(now);
    o.stop(now + 0.11);

    var ns = noise(c, 0.05);
    var nf = c.createBiquadFilter();
    nf.type = 'bandpass';
    nf.frequency.value = 2500;
    nf.Q.value = 0.8;
    var ng = gain(0);
    ng.gain.setValueAtTime(0.18, now);
    ng.gain.exponentialRampToValueAtTime(0.001, now + 0.05);
    connect([ns, nf, ng]);
    ns.start(now);
    ns.stop(now + 0.06);
  };

  // ── Fight: Punch Heavy ───────────────────────────────────────────────────

  window.synthPunchHeavy = function () {
    var c = ctx();
    var now = c.currentTime;

    var o = osc('sawtooth', 120);
    var g = gain(0);
    o.frequency.setValueAtTime(120, now);
    o.frequency.exponentialRampToValueAtTime(35, now + 0.18);
    g.gain.setValueAtTime(0, now);
    g.gain.linearRampToValueAtTime(0.55, now + 0.006);
    g.gain.exponentialRampToValueAtTime(0.001, now + 0.22);
    var lpf = c.createBiquadFilter();
    lpf.type = 'lowpass';
    lpf.frequency.value = 600;
    connect([o, lpf, g]);
    o.start(now);
    o.stop(now + 0.24);

    var ns = noise(c, 0.12);
    var nf = c.createBiquadFilter();
    nf.type = 'lowpass';
    nf.frequency.value = 800;
    var ng = gain(0);
    ng.gain.setValueAtTime(0.35, now);
    ng.gain.exponentialRampToValueAtTime(0.001, now + 0.12);
    connect([ns, nf, ng]);
    ns.start(now);
    ns.stop(now + 0.13);
  };

  // ── Fight: Kick Light ────────────────────────────────────────────────────

  window.synthKickLight = function () {
    var c = ctx();
    var now = c.currentTime;

    var o = osc('triangle', 250);
    var g = gain(0);
    o.frequency.setValueAtTime(250, now);
    o.frequency.exponentialRampToValueAtTime(80, now + 0.10);
    g.gain.setValueAtTime(0, now);
    g.gain.linearRampToValueAtTime(0.40, now + 0.005);
    g.gain.exponentialRampToValueAtTime(0.001, now + 0.13);
    connect([o, g]);
    o.start(now);
    o.stop(now + 0.14);

    var ns = noise(c, 0.07);
    var nf = c.createBiquadFilter();
    nf.type = 'highpass';
    nf.frequency.value = 3000;
    var ng = gain(0);
    ng.gain.setValueAtTime(0.12, now);
    ng.gain.exponentialRampToValueAtTime(0.001, now + 0.07);
    connect([ns, nf, ng]);
    ns.start(now);
    ns.stop(now + 0.08);
  };

  // ── Fight: Kick Heavy ────────────────────────────────────────────────────

  window.synthKickHeavy = function () {
    var c = ctx();
    var now = c.currentTime;

    var sub = osc('sine', 100);
    var sg = gain(0);
    sub.frequency.setValueAtTime(100, now);
    sub.frequency.exponentialRampToValueAtTime(28, now + 0.22);
    sg.gain.setValueAtTime(0, now);
    sg.gain.linearRampToValueAtTime(0.80, now + 0.007);
    sg.gain.exponentialRampToValueAtTime(0.001, now + 0.26);
    connect([sub, sg]);
    sub.start(now);
    sub.stop(now + 0.28);

    var crk = osc('sawtooth', 260);
    var cg = gain(0);
    crk.frequency.setValueAtTime(260, now);
    crk.frequency.exponentialRampToValueAtTime(70, now + 0.06);
    cg.gain.setValueAtTime(0, now);
    cg.gain.linearRampToValueAtTime(0.35, now + 0.004);
    cg.gain.exponentialRampToValueAtTime(0.001, now + 0.08);
    connect([crk, cg]);
    crk.start(now);
    crk.stop(now + 0.09);
  };

  // ── Fight: Block ─────────────────────────────────────────────────────────

  window.synthBlock = function () {
    var c = ctx();
    var now = c.currentTime;
    var freqs = [700, 1100, 1700];
    freqs.forEach(function (f) {
      var o = osc('sine', f);
      var g = gain(0);
      g.gain.setValueAtTime(0, now);
      g.gain.linearRampToValueAtTime(0.08, now + 0.003);
      g.gain.exponentialRampToValueAtTime(0.001, now + 0.18);
      connect([o, g]);
      o.start(now);
      o.stop(now + 0.20);
    });

    var ns = noise(c, 0.06);
    var nf = c.createBiquadFilter();
    nf.type = 'bandpass';
    nf.frequency.value = 1200;
    nf.Q.value = 1.5;
    var ng = gain(0);
    ng.gain.setValueAtTime(0.20, now);
    ng.gain.exponentialRampToValueAtTime(0.001, now + 0.06);
    connect([ns, nf, ng]);
    ns.start(now);
    ns.stop(now + 0.07);
  };

  // ── Fight: KO ────────────────────────────────────────────────────────────

  window.synthKo = function () {
    var c = ctx();
    var now = c.currentTime;

    var ns = noise(c, 1.8);
    var nf = c.createBiquadFilter();
    nf.type = 'lowpass';
    nf.frequency.setValueAtTime(600, now);
    nf.frequency.exponentialRampToValueAtTime(80, now + 0.8);
    var ng = gain(0);
    ng.gain.setValueAtTime(0, now);
    ng.gain.linearRampToValueAtTime(0.9, now + 0.01);
    ng.gain.exponentialRampToValueAtTime(0.001, now + 1.6);
    connect([ns, nf, ng]);
    ns.start(now);
    ns.stop(now + 1.8);

    var sub = osc('sine', 80);
    var sg = gain(0);
    sub.frequency.setValueAtTime(80, now);
    sub.frequency.exponentialRampToValueAtTime(20, now + 0.6);
    sg.gain.setValueAtTime(0, now);
    sg.gain.linearRampToValueAtTime(1.2, now + 0.01);
    sg.gain.exponentialRampToValueAtTime(0.001, now + 0.65);
    connect([sub, sg]);
    sub.start(now);
    sub.stop(now + 0.70);

    // Crowd cheer sweep
    var crowd = noise(c, 1.5);
    var cf = c.createBiquadFilter();
    cf.type = 'bandpass';
    cf.frequency.setValueAtTime(400, now + 0.3);
    cf.frequency.linearRampToValueAtTime(2000, now + 1.0);
    cf.Q.value = 0.5;
    var cg = gain(0);
    cg.gain.setValueAtTime(0, now + 0.25);
    cg.gain.linearRampToValueAtTime(0.25, now + 0.6);
    cg.gain.exponentialRampToValueAtTime(0.001, now + 1.5);
    connect([crowd, cf, cg]);
    crowd.start(now + 0.25);
    crowd.stop(now + 1.6);
  };

  // ── Fight: Countdown Beep ────────────────────────────────────────────────

  window.synthCountdownBeep = function () {
    var c = ctx();
    var now = c.currentTime;
    var o = osc('sine', 880);
    var g = gain(0);
    g.gain.setValueAtTime(0, now);
    g.gain.linearRampToValueAtTime(0.35, now + 0.01);
    g.gain.setValueAtTime(0.35, now + 0.15);
    g.gain.exponentialRampToValueAtTime(0.001, now + 0.22);
    connect([o, g]);
    o.start(now);
    o.stop(now + 0.24);
  };

  // ── Fight: Fight Start ───────────────────────────────────────────────────

  window.synthFightStart = function () {
    var c = ctx();
    var now = c.currentTime;
    var freqs = [220, 330, 440, 660];
    freqs.forEach(function (f, i) {
      var t = now + i * 0.09;
      var o = osc('sawtooth', f);
      var lpf = c.createBiquadFilter();
      lpf.type = 'lowpass';
      lpf.frequency.value = 3000;
      var g = gain(0);
      g.gain.setValueAtTime(0, t);
      g.gain.linearRampToValueAtTime(0.28, t + 0.015);
      g.gain.exponentialRampToValueAtTime(0.001, t + 0.22);
      connect([o, lpf, g]);
      o.start(t);
      o.stop(t + 0.24);
    });
  };

  // ── Epic space background music ────────────────────────────────────────────

  window.synthStartBgm = function () {
    synthStopBgm();
    var c = ctx();
    var now = c.currentTime;

    _bgmMaster = gain(0);
    _bgmMaster.connect(c.destination);
    _bgmMaster.gain.setValueAtTime(0, now);
    _bgmMaster.gain.linearRampToValueAtTime(0.22, now + 4.0);

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

    var sub = c.createOscillator();
    sub.type = 'sine';
    sub.frequency.value = 55;
    var subG = gain(0.55);
    addLfo(subG.gain, 0.06, 0.12);
    sub.connect(subG);
    subG.connect(_bgmMaster);
    sub.start(now);
    _bgmNodes.push(sub);

    var padFreqs = [110, 164.81, 220, 261.63, 329.63];
    padFreqs.forEach(function (f, idx) {
      var p = c.createOscillator();
      p.type = 'triangle';
      p.frequency.value = f;
      p.detune.value = (idx % 2 === 0 ? 1 : -1) * (idx + 1) * 3;
      var pg = gain(0.10);
      addLfo(pg.gain, 0.07 + idx * 0.02, 0.025);
      p.connect(pg);
      pg.connect(_bgmMaster);
      p.start(now);
      _bgmNodes.push(p);
    });

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

    function chime() {
      if (!_bgmMaster) return;
      var t = ctx().currentTime;
      var ch = c.createOscillator();
      ch.type = 'sine';
      ch.frequency.setValueAtTime(2093, t);
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
