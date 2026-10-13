"""insert.wav: the eject recording (release.wav, Kenney CC0) made into the insert sound — played a
little quicker and brighter (8 % up), with a short fade-in so it reads as going in, not popping out.
    python tools/make_insert_sound.py
"""
import wave
from pathlib import Path

import numpy as np

SOUNDS = Path(__file__).resolve().parent.parent / "carthage" / "assets" / "sounds"

with wave.open(str(SOUNDS / "release.wav")) as w:
    rate = w.getframerate()
    x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32)

speed = 1.08  # quicker and a touch brighter
idx = np.arange(0, len(x) - 1, speed)
y = np.interp(idx, np.arange(len(x)), x)
fade = int(rate * 0.006)
y[:fade] *= np.linspace(0, 1, fade)
y *= 0.95
with wave.open(str(SOUNDS / "insert.wav"), "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(rate)
    w.writeframes(np.clip(y, -32768, 32767).astype(np.int16).tobytes())
print("insert.wav:", round(len(y) / rate, 3), "s")
