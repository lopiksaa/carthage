#!/usr/bin/env python3
"""Synthesize Carthage's UI sounds from one physical model of its plastic.

The model is measured from the eject recording (lab/release_2.wav, Kenney CC0):
  - a low body resonance: three close modes around 800 Hz, ~20 ms to fade 20 dB
  - bright click resonances: clusters around 4.8 kHz and 7.5–8.9 kHz, ~10 ms
  - each contact is a double tap ~8 ms apart (the part bouncing once)
Every sound below is built from `hit()` — same plastic, different pitch, weight and
timing — so they all sound like one object. The eject itself stays the recording.

Levels are matched to the eject recording (active RMS ≈ -27 dBFS; hover quieter).

Run: python tools/make_sounds.py
"""

import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
OUT = Path(__file__).resolve().parent.parent / "carthage" / "assets" / "sounds"

# (frequency Hz, relative amplitude, decay time constant ms) — measured, see docstring.
BODY = [(754, 0.66, 9.0), (797, 1.0, 9.5), (834, 0.52, 8.5)]
CLICK = [(4737, 0.46, 3.2), (4834, 0.66, 3.5), (4974, 0.45, 3.0), (5039, 0.42, 2.8),
         (7450, 0.49, 2.4), (8005, 0.46, 2.2), (8877, 0.38, 2.0)]


def hit(strength=1.0, pitch=1.0, decay=1.0, bright=1.0, body=1.0, seed=0):
    """One plastic contact: noise transient + body modes + click modes."""
    rnd = random.Random(seed)
    n = int(RATE * 0.12 * decay)
    out = [0.0] * n
    modes = [(f, a * body, d) for f, a, d in BODY] + [(f, a * bright, d) for f, a, d in CLICK]
    for f, a, d in modes:
        f *= pitch * (1 + rnd.uniform(-0.012, 0.012))  # tiny detune: no two hits identical
        tau = d / 1000 * decay
        ph = rnd.uniform(0, 2 * math.pi)
        w = 2 * math.pi * f / RATE
        for i in range(n):
            e = math.exp(-i / RATE / tau)
            if e < 1e-4:
                break
            out[i] += a * e * math.sin(w * i + ph)
    # contact transient: ~1.5 ms of high-passed noise
    lp = 0.0
    for i in range(int(RATE * 0.0015)):
        x = rnd.uniform(-1, 1)
        lp += 0.5 * (x - lp)
        out[i] += (x - lp) * 0.9 * bright * math.exp(-i / (RATE * 0.0005))
    return [v * strength for v in out]


def tap(strength=1.0, gap_ms=8.0, bounce=0.55, seed=0, **kw):
    """A contact with its bounce: a second, weaker hit ~8 ms later."""
    return mix((0, hit(strength, seed=seed, **kw), 1.0), (gap_ms, hit(strength * bounce, seed=seed + 1, **kw), 1.0))


def rub(ms, strength=0.2, center=2200, seed=0):
    """Plastic sliding against plastic: soft band-limited friction noise."""
    rnd = random.Random(seed)
    n = int(RATE * ms / 1000)
    out, low, band = [], 0.0, 0.0
    k = 2 * math.sin(math.pi * center / RATE)
    for i in range(n):
        x = rnd.uniform(-1, 1)
        high = x - low - 0.9 * band
        band += k * high
        low += k * band
        out.append(band * math.sin(math.pi * i / n) ** 2 * strength)
    return out


def mix(*layers):
    """layers: (offset_ms, samples, gain)"""
    length = max(int(RATE * off / 1000) + len(s) for off, s, _ in layers)
    buf = [0.0] * length
    for off, s, g in layers:
        start = int(RATE * off / 1000)
        for i, v in enumerate(s):
            buf[start + i] += v * g
    return buf


def finish(buf, peak):
    m = max(abs(v) for v in buf) or 1.0
    buf = [v * peak / m for v in buf]
    n = min(len(buf), int(RATE * 0.006))  # 6 ms fade-out, no click at the end
    for i in range(n):
        buf[-1 - i] *= i / n
    return buf


def write(name, buf):
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / f"{name}.wav"
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32767)) for v in buf))
    print("wrote", path)


def main():
    # Insert: the cartridge body seats (heavier, lower), then the latch snaps shut (brighter).
    write("click_in", finish(mix(
        (0, tap(1.0, pitch=0.86, decay=1.25, bright=0.7, seed=1), 1.0),
        (62, tap(0.85, gap_ms=6, pitch=1.06, decay=0.9, bright=1.15, body=0.6, seed=3), 1.0),
    ), 0.34))

    # Pressed to quit: pushing down against the spring — a damped, muffled contact.
    write("half_click", finish(tap(0.8, gap_ms=9, bounce=0.35, pitch=0.8, decay=0.75, bright=0.45, seed=5), 0.2))

    # Hover: a fingertip brushing the cartridge — one light, high tick.
    write("hover", finish(hit(0.3, pitch=1.3, decay=0.45, bright=0.9, body=0.35, seed=7), 0.11))

    # Picked up: the card unclips from its recess and slides up a little.
    write("pick", finish(mix(
        (0, tap(0.55, gap_ms=7, pitch=1.12, decay=0.7, bright=0.85, seed=9), 1.0),
        (8, rub(90, 0.35, center=2600, seed=10), 1.0),
    ), 0.25))

    # Put back: it slides into its recess and settles.
    write("place", finish(mix(
        (0, rub(70, 0.3, center=2000, seed=11), 1.0),
        (60, tap(0.9, pitch=0.9, decay=1.05, bright=0.75, seed=12), 1.0),
        (108, hit(0.35, pitch=0.93, decay=0.8, bright=0.5, seed=14), 1.0),
    ), 0.34))

    # Menu key: the key travels down (light tick) and bottoms out (dull thud).
    write("key", finish(mix(
        (0, hit(0.55, pitch=1.2, decay=0.55, bright=0.9, body=0.4, seed=15), 1.0),
        (13, hit(0.7, pitch=0.72, decay=0.9, bright=0.3, body=1.2, seed=16), 1.0),
    ), 0.17))

    # The dice: a small, hard die tumbling across the plastic — bounces coming quicker and
    # lighter as it settles, a little scrape between them, a last tap as it stops.
    bounces = [(0, 1.0), (74, 0.8), (128, 0.62), (168, 0.5), (198, 0.38), (221, 0.3), (238, 0.22)]
    write("roll", finish(mix(
        (12, rub(210, 0.12, center=3400, seed=17), 1.0),
        *[(t, hit(0.5 * k, pitch=1.55 + 0.07 * (i % 3), decay=0.5, bright=1.05, body=0.25, seed=20 + i), 1.0)
          for i, (t, k) in enumerate(bounces)],
        (262, hit(0.2, pitch=1.4, decay=0.6, bright=0.8, body=0.4, seed=30), 1.0),
    ), 0.2))


if __name__ == "__main__":
    main()
