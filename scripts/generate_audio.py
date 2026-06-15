#!/usr/bin/env python3
"""Procedural sound-effect + music generator for Chicken Hunter: Space War.

Generates all the SFX and a looping background track as 16-bit mono WAV files
using only the Python standard library (no numpy / external tools). Re-run with:

    python3 scripts/generate_audio.py

Output goes to assets/audio/. These are real, committed game assets — the game
plays them on web and mobile via flame_audio.
"""
import math
import os
import random
import struct
import wave

SR = 22050  # sample rate
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")

random.seed(7)


def _save(name, samples):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    # Soft-clip then quantise to 16-bit.
    data = bytearray()
    for s in samples:
        s = math.tanh(s * 1.1)  # gentle saturation, no harsh clipping
        v = max(-1.0, min(1.0, s))
        data += struct.pack("<h", int(v * 32767))
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(bytes(data))
    print(f"  wrote {name}  ({len(samples)/SR:.2f}s)")


def _t(dur):
    return [i / SR for i in range(int(dur * SR))]


def sine(f, t):
    return math.sin(2 * math.pi * f * t)


def square(f, t):
    return 1.0 if math.sin(2 * math.pi * f * t) >= 0 else -1.0


def saw(f, t):
    p = (f * t) % 1.0
    return 2.0 * p - 1.0


def noise():
    return random.uniform(-1, 1)


def env(t, dur, attack=0.005, release=0.1):
    """Simple attack/decay envelope, 0..1."""
    if t < attack:
        return t / attack
    rel_start = dur - release
    if t > rel_start:
        return max(0.0, (dur - t) / release)
    return 1.0


# --------------------------------------------------------------------------
# Individual effects.
# --------------------------------------------------------------------------
def laser():
    dur = 0.18
    out = []
    for t in _t(dur):
        f = 1300 * (1 - t / dur) + 280  # falling pitch zap
        s = 0.6 * square(f, t) + 0.4 * sine(f * 2, t)
        out.append(s * env(t, dur, 0.002, 0.12) * 0.5)
    return out


def explosion():
    dur = 0.6
    out = []
    for t in _t(dur):
        decay = math.exp(-t * 6)
        rumble = sine(70 + 30 * decay, t)
        s = (0.7 * noise() + 0.5 * rumble) * decay
        out.append(s * 0.8)
    return out


def hit():
    dur = 0.08
    out = []
    for t in _t(dur):
        decay = math.exp(-t * 40)
        out.append((0.6 * noise() + 0.4 * sine(400, t)) * decay * 0.7)
    return out


def powerup():
    notes = [523, 659, 784, 1047]  # C5 E5 G5 C6
    out = []
    seg = 0.08
    for i, f in enumerate(notes):
        for t in _t(seg):
            s = 0.5 * sine(f, t) + 0.3 * square(f, t)
            out.append(s * env(t, seg, 0.005, 0.04) * 0.5)
    return out


def coin():
    out = []
    for f in (988, 1319):  # B5, E6
        seg = 0.07
        for t in _t(seg):
            out.append(sine(f, t) * env(t, seg, 0.003, 0.05) * 0.5)
    return out


def boss_roar():
    dur = 0.9
    out = []
    for t in _t(dur):
        vib = 1 + 0.04 * sine(6, t)
        growl = 0.6 * saw(55 * vib, t) + 0.3 * sine(40, t)
        s = (growl + 0.3 * noise()) * env(t, dur, 0.05, 0.3)
        out.append(s * 0.7)
    return out


def nuke():
    dur = 1.3
    out = []
    for t in _t(dur):
        decay = math.exp(-t * 2.2)
        sweep = 600 * math.exp(-t * 3) + 50
        s = 0.6 * noise() * decay + 0.6 * sine(sweep, t) * decay
        s += 0.4 * sine(45, t) * math.exp(-t * 1.5)  # deep boom
        out.append(s * 0.85)
    return out


def click():
    dur = 0.04
    out = []
    for t in _t(dur):
        out.append((0.5 * square(900, t) + 0.3 * noise()) * env(t, dur, 0.001, 0.02) * 0.4)
    return out


def level_up():
    notes = [523, 659, 784, 1047, 1319]
    out = []
    seg = 0.09
    for f in notes:
        for t in _t(seg):
            s = 0.5 * sine(f, t) + 0.25 * sine(f * 2, t)
            out.append(s * env(t, seg, 0.005, 0.05) * 0.5)
    return out


def bgm_battle():
    """A short, seamless-looping chiptune: driving bass + arpeggio + light beat."""
    bpm = 132
    beat = 60.0 / bpm
    bars = 8
    total = beat * 4 * bars
    # i–VI–III–VII style progression in A minor.
    roots = [220.0, 174.61, 130.81, 196.0]  # A3 F3 C3 G3
    arp_offsets = [1.0, 1.5, 2.0, 2.5]  # root, fifth-ish, octave, etc.
    out = []
    n = int(total * SR)
    for i in range(n):
        t = i / SR
        bar = int(t / (beat * 4)) % len(roots)
        root = roots[bar]
        beat_t = t % beat
        sixteenth = t % (beat / 4)

        # Bass: pulse on each beat.
        bass = 0.5 * square(root / 2, t) * math.exp(-beat_t * 5)
        # Arpeggio: stepping notes every 16th.
        step = int((t / (beat / 4))) % len(arp_offsets)
        arp_f = root * 2 * arp_offsets[step]
        arp = 0.28 * saw(arp_f, t) * math.exp(-sixteenth * 9)
        # Kick + hat.
        kick = 0.6 * sine(60 * math.exp(-beat_t * 25), t) * math.exp(-beat_t * 18)
        hat = 0.12 * noise() * math.exp(-(t % (beat / 2)) * 50)

        s = (bass + arp + kick + hat) * 0.5
        # Crossfade the last 0.25s into the start for a clean loop.
        fade = 0.25
        if t > total - fade:
            s *= (total - t) / fade
        out.append(s)
    return out


def main():
    print("Generating audio into assets/audio/ ...")
    _save("laser.wav", laser())
    _save("explosion.wav", explosion())
    _save("hit.wav", hit())
    _save("powerup.wav", powerup())
    _save("coin.wav", coin())
    _save("boss_roar.wav", boss_roar())
    _save("nuke.wav", nuke())
    _save("click.wav", click())
    _save("level_up.wav", level_up())
    _save("bgm_battle.wav", bgm_battle())
    print("Done.")


if __name__ == "__main__":
    main()
