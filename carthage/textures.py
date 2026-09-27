"""Plastic surface textures: the grain on shells, tray, dock and header.

A texture becomes a tileable *overlay*: translucent white where the surface is brighter
than average, translucent black where it's darker, so one overlay works on any plastic
color (white or black hardware).

Photo textures (ambientCG) are used through their normal maps: Carthage lights the bumps
itself from its one top-left light, so a texture never brings its own, inconsistent
lighting. See assets/textures/SOURCES.md for credits.
"""

import threading
from pathlib import Path

import numpy as np
from PIL import Image
from PySide6.QtGui import QImage

from .render import noise

TEXTURE_DIR = Path(__file__).resolve().parent / "assets" / "textures"

# Grain size → tile edge in pixels. A photo texture's whole (seamless) image is squeezed
# into one tile, so a smaller tile means finer grain.
SIZES = {"fine": 384, "medium": 640, "coarse": 1024}

# The app's light: from the top-left, a little in front (normal-map space: x right, y up).
_LIGHT = np.array([-0.55, 0.55, 0.63])
_LIGHT = _LIGHT / np.linalg.norm(_LIGHT)

_cache = {}
_lock = threading.Lock()


def _to_qimage(rgba):
    h, w, _ = rgba.shape
    return QImage(rgba.tobytes(), w, h, 4 * w, QImage.Format_RGBA8888_Premultiplied).copy()


def _overlay_from_normals(path, size, strength):
    img = Image.open(path).convert("RGB").resize((size, size), Image.LANCZOS)
    n = np.asarray(img, dtype=np.float32) / 127.5 - 1.0
    n /= np.linalg.norm(n, axis=2, keepdims=True) + 1e-6
    shade = n @ _LIGHT
    dev = shade - shade.mean()
    dev /= np.percentile(np.abs(dev), 98) + 1e-6  # normalize contrast across textures
    a = np.clip(np.abs(dev) * strength * 70, 0, 255)
    c = np.where(dev > 0, a, 0)  # premultiplied: white → (a,a,a,a), black → (0,0,0,a)
    rgba = np.stack([c, c, c, a], axis=2).astype(np.uint8)
    return _to_qimage(rgba)


def overlay(texture="grain", size="medium", strength=1.0):
    """The tileable overlay QImage for a texture."""
    key = (texture, size, round(strength, 2))
    with _lock:
        if key in _cache:
            return _cache[key]
    if texture == "none":
        img = QImage(8, 8, QImage.Format_ARGB32_Premultiplied)
        img.fill(0)
    elif texture == "grain":
        img = noise(strength=int(30 * strength))
    else:
        path = TEXTURE_DIR / f"{texture}_normal.png"
        img = _overlay_from_normals(path, SIZES.get(size, 640), strength) if path.exists() else noise()
    with _lock:
        _cache[key] = img
    return img
