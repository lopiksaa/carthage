"""Pre-rendered images for the tray, cartridges and dock.

Heavy, static visuals are painted once per size and edition with QPainter and cached;
QML only composites them. Image ids (all prefixed "image://gc/"):

    shell/<edition>[/flat]                   cartridge body without art or text
    back/<edition>/<flat|edge>/<label>       the cartridge's back (gold contacts, logo)
    shadow/<edition>                         blurred silhouette, padded by SHADOW_PAD
    recess/<edition>                         the molded pocket a cartridge sits in
    grain/<edition>                          tileable plastic texture overlay
    header/<mode>/<source>/<edition>/<gameId>  the cartridge's top strip
    art/<gameId>[/off]                       game art (cached, else generated);
                                             /off = desaturated for not-installed

Any id may end in "?tex=…&size=…&s=…" (surface texture) or cache-busting query values.
"""

import hashlib
import random
import threading
from collections import OrderedDict
from pathlib import Path

from PySide6.QtCore import QPointF, QRectF, Qt
from PySide6.QtGui import (
    QBrush,
    QColor,
    QFont,
    QFontMetricsF,
    QImage,
    QLinearGradient,
    QPainter,
    QPainterPath,
    QPen,
    QPolygonF,
)
from PySide6.QtQuick import QQuickImageProvider
from PySide6.QtSvg import QSvgRenderer

from .theme import EDITIONS, GEOMETRY, REF_H, REF_W

SHADOW_PAD = 0.16  # fraction of card width added around the shadow image
RECESS_PAD = 0.035  # fraction of card width the pocket extends past the card



def _img(w, h):
    img = QImage(max(1, w), max(1, h), QImage.Format_ARGB32_Premultiplied)
    img.fill(Qt.transparent)
    return img


def _rounded(x, y, w, h, r):
    path = QPainterPath()
    path.addRoundedRect(QRectF(x, y, w, h), r, r)
    return path


def blur(img, radius):
    """Cheap, good-looking blur: shrink then grow with smooth scaling, twice."""
    if radius < 1:
        return img
    w, h = img.width(), img.height()
    out = img
    for step in (radius, radius * 0.6):
        f = max(1.0, step / 1.6)
        small = out.scaled(max(1, int(w / f)), max(1, int(h / f)), Qt.IgnoreAspectRatio, Qt.SmoothTransformation)
        out = small.scaled(w, h, Qt.IgnoreAspectRatio, Qt.SmoothTransformation)
    return out


_noise_cache = {}
_brushed_cache = {}


def brushed(w=512, h=128, seed=11):
    """Tileable brushed aluminum (the Hi-Fi skin): fine horizontal streaks, stored like the
    plastic grain as translucent white (brighter) or black (darker) per pixel."""
    key = (w, h, seed)
    if key in _brushed_cache:
        return _brushed_cache[key]
    import numpy as np

    rng = np.random.default_rng(seed)
    v = rng.normal(0.0, 1.0, (h, w))
    # Long horizontal blur (wrapping, so it tiles): streaks, not specks.
    for r in (1, 2, 4, 8, 16, 32):
        v = (v + np.roll(v, r, axis=1)) / 2
    v += rng.normal(0.0, 0.6, (h, 1))  # each row a little lighter or darker
    v = v / (np.abs(v).max() or 1)
    a = (np.abs(v) * 60).astype(np.uint8)
    img = np.zeros((h, w, 4), np.uint8)
    light = v > 0
    img[..., 0] = img[..., 1] = img[..., 2] = np.where(light, 255, 0).astype(np.uint8)
    img[..., 3] = a
    for c in range(3):
        img[..., c] = (img[..., c].astype(np.uint16) * a // 255).astype(np.uint8)
    q = QImage(img.tobytes(), w, h, 4 * w, QImage.Format_RGBA8888_Premultiplied).copy()
    _brushed_cache[key] = q
    return q


def noise(size=160, seed=7, strength=30):
    """Tileable matte-plastic grain: fine, soft brightness variation.

    Gaussian noise, lightly blurred (wrapping at the edges, so it tiles seamlessly), then
    stored as translucent white (brighter) or black (darker) per pixel. Low-contrast and
    even, so it reads as plastic rather than sand.
    """
    key = (size, seed, strength)
    if key in _noise_cache:
        return _noise_cache[key]
    rnd = random.Random(seed)
    n = size * size
    v = [rnd.gauss(0.0, 1.0) for _ in range(n)]
    # One pass of a wrapping 3×3 box blur softens single-pixel specks into a fine grain.
    b = [0.0] * n
    for y in range(size):
        ym, yp = ((y - 1) % size) * size, ((y + 1) % size) * size
        yc = y * size
        for x in range(size):
            xm, xp = (x - 1) % size, (x + 1) % size
            b[yc + x] = (
                v[ym + xm] + v[ym + x] + v[ym + xp]
                + v[yc + xm] + 2 * v[yc + x] + v[yc + xp]
                + v[yp + xm] + v[yp + x] + v[yp + xp]
            ) / 10.0
    data = bytearray(n * 4)
    for i, val in enumerate(b):
        a = min(255, int(abs(val) * strength * 1.8))
        c = a if val > 0 else 0  # premultiplied: white → (a,a,a,a), black → (0,0,0,a)
        data[i * 4 : i * 4 + 4] = bytes((c, c, c, a))
    img = QImage(bytes(data), size, size, QImage.Format_ARGB32_Premultiplied).copy()
    _noise_cache[key] = img
    return img


def _groove(p, path, u, depth, fill, hi, lo):
    """A recessed shape lit from the top-left: dark inner edge at top-left, bright lip at bottom-right."""
    p.save()
    p.fillPath(path, QColor(fill))
    p.setClipPath(path)
    # Inner shadow: the shape's own outline pushed toward the light's opposite side.
    shifted = QPainterPath(path)
    shifted.translate(depth * u, depth * 1.2 * u)
    pen = QPen(QColor(lo), depth * 2.4 * u)
    p.setPen(pen)
    p.setBrush(Qt.NoBrush)
    outside = QPainterPath()
    outside.addRect(path.boundingRect().adjusted(-50 * u, -50 * u, 50 * u, 50 * u))
    outside = outside.subtracted(shifted)
    p.fillPath(outside, QColor(lo))
    p.restore()
    # Bright lip on the bottom-right edge where the light hits the far wall.
    p.save()
    r = path.boundingRect()
    g = QLinearGradient(r.topLeft(), r.bottomRight())
    g.setColorAt(0.0, QColor(0, 0, 0, 0))
    g.setColorAt(0.55, QColor(0, 0, 0, 0))
    g.setColorAt(1.0, QColor(hi))
    p.setPen(QPen(QBrush(g), 1.4 * u))
    p.setBrush(Qt.NoBrush)
    p.drawPath(path)
    p.restore()



def _notches(u, inset=0.0):
    """The two latch notches (theme GEOMETRY["notch"]), as shapes to cut out of the outline."""
    y, h, d = GEOMETRY["notch"]
    out = QPainterPath()
    for side in (-1, 1):
        # Edge x (a little outside, so the cut is clean) and the notch floor, per side.
        edge = inset - 1 if side < 0 else REF_W * u - inset + 1
        floor = inset + d * u if side < 0 else REF_W * u - inset - d * u
        out.addPolygon(QPolygonF([
            QPointF(edge, y * u), QPointF(floor, (y + d) * u),
            QPointF(floor, (y + h - d) * u), QPointF(edge, (y + h) * u),
        ]))
        out.closeSubpath()
    return out


def shell_path(u, inset=0.0):
    """The whole silhouette, including the visible thickness (used for shadows)."""
    r = GEOMETRY["radius"]
    return _rounded(inset, inset, REF_W * u - 2 * inset, REF_H * u - 2 * inset, r * u).subtracted(_notches(u, inset))


def face_path(u, inset=0.0):
    """The cartridge's top face: the silhouette minus the thickness at the bottom."""
    r = GEOMETRY["radius"]
    t = GEOMETRY["thickness"]
    face = _rounded(inset, inset, REF_W * u - 2 * inset, (REF_H - t) * u - 2 * inset, r * u)
    return face.subtracted(_notches(u, inset))


def _draw_body(p, w, h, u, pal, flat=False, tex=None):
    """The plastic shell shared by front and back: side wall, face, grain, bevel.

    flat=True is for the 3D card's faces: the real 3D edge provides the thickness, so
    no side wall is baked in and the face fills the whole canvas."""
    # Thickness: the cartridge's lower side wall, seen slightly from above. Drawn first,
    # the top face covers all of it except a sliver along the bottom edge.
    if not flat:
        side = shell_path(u, 0.5)
        sg = QLinearGradient(0, h * 0.9, 0, h)
        sg.setColorAt(0, QColor(pal["shellBottom"]).darker(135))
        sg.setColorAt(1, QColor(pal["shellSide"]))
        p.fillPath(side, sg)

    face = shell_path(u, 0.5) if flat else face_path(u, 0.5)
    g = QLinearGradient(0, 0, w * 0.35, h)
    g.setColorAt(0, QColor(pal["shellTop"]))
    g.setColorAt(1, QColor(pal["shellBottom"]))
    p.fillPath(face, g)

    p.save()
    p.setClipPath(face)
    p.setOpacity(min(1.0, pal["grain"] * 3.6))
    p.fillRect(QRectF(0, 0, w, h), QBrush(tex if tex is not None else noise()))
    p.restore()

    # Bevel: a crisp highlight on the top-left rim, shade toward the bottom-right rim.
    bev = QLinearGradient(0, 0, w, h * 0.8)
    bev.setColorAt(0.0, QColor(pal["shellHi"]))
    bev.setColorAt(0.4, QColor(0, 0, 0, 0))
    bev.setColorAt(1.0, QColor(pal["shellLo"]))
    p.setPen(QPen(QBrush(bev), 4 * u))
    p.setBrush(Qt.NoBrush)
    p.drawPath(shell_path(u, 2.5 * u) if flat else face_path(u, 2.5 * u))


def render_shell(w, h, edition, flat=False, tex=None):
    pal = EDITIONS[edition]
    img = _img(w, h)
    u = w / REF_W
    p = QPainter(img)
    p.setRenderHint(QPainter.Antialiasing)

    _draw_body(p, w, h, u, pal, flat, tex)

    # The sticker's well: molded a hair deeper than the face and a hair larger than the
    # sticker, so a thin ledge shows all round it. Barely there: a faint shadow line on
    # the top-left, a faint lip on the bottom-right.
    sx, sy, sw, sh, sr = GEOMETRY["sticker"]
    g = GEOMETRY["stickerWell"]
    well = _rounded((sx - g) * u, (sy - g) * u, (sw + 2 * g) * u, (sh + 2 * g) * u, (sr + g) * u)
    _groove(p, well, u, 0.7, "#00000000", pal["shellHi"], "#48000000")

    # The recessed tab on top, joined to the sticker (drawn before the sticker so its
    # lower corners disappear under it).
    x, y, tw, th, tr = GEOMETRY["tab"]
    _groove(p, _rounded(x * u, y * u, tw * u, th * u, tr * u), u, 3, pal["groove"], pal["shellHi"], "#a0000000")

    sticker = _rounded(sx * u, sy * u, sw * u, sh * u, sr * u)
    p.save()
    p.setClipPath(sticker)
    hx, hy, hw, hh = GEOMETRY["header"]
    p.fillRect(QRectF(hx * u, hy * u, hw * u, hh * u + 1), QColor(pal["stickerHead"]))
    ax, ay, aw, ah = GEOMETRY["art"]
    p.fillRect(QRectF(ax * u, ay * u, aw * u, ah * u), QColor(pal["artBack"]))
    lx, ly, lw, lh = GEOMETRY["label"]
    p.fillRect(QRectF(lx * u, ly * u, lw * u, lh * u + 1), QColor(pal["labelBack"]))
    # Printed stickers carry a faint sheen under the same top-left light.
    sheen = QLinearGradient(sx * u, sy * u, (sx + sw * 0.8) * u, (sy + sh * 0.6) * u)
    sheen.setColorAt(0, QColor(pal["stickerSheen"]))
    sheen.setColorAt(1, QColor(0, 0, 0, 0))
    p.fillRect(QRectF(sx * u, sy * u, sw * u, sh * u), sheen)
    p.restore()
    # The sticker's edge: a hairline, darker on the top-left where it sits a hair below the rim.
    p.setPen(QPen(QColor(pal["stickerEdge"]), max(1.0, 1.6 * u)))
    p.setBrush(Qt.NoBrush)
    p.drawPath(sticker)

    ax, ay, aw, ah = GEOMETRY["arrow"]
    tri = QPainterPath()
    tri.addPolygon(QPolygonF([QPointF(ax * u, ay * u), QPointF((ax + aw) * u, ay * u), QPointF((ax + aw / 2) * u, (ay + ah) * u)]))
    tri.closeSubpath()
    _groove(p, tri, u, 3, pal["groove"], pal["shellHi"], "#a0000000")

    p.end()
    return img


def render_back(w, h, edition, label="", flat=False, tex=None):
    """The cartridge's back: plain molded plastic with the gold contacts in a recessed
    window along the bottom (the end that goes into the slot), a raised CARTHAGE
    wordmark, and a small molded code."""
    pal = EDITIONS[edition]
    img = _img(w, h)
    u = w / REF_W
    p = QPainter(img)
    p.setRenderHint(QPainter.Antialiasing)
    p.setRenderHint(QPainter.TextAntialiasing)
    _draw_body(p, w, h, u, pal, flat, tex)

    win_y = 690
    win = _rounded(128 * u, win_y * u, 344 * u, 96 * u, 14 * u)
    _groove(p, win, u, 4, "#101012" if edition == "dark" else "#2a2a2e", pal["shellHi"], "#c0000000")
    pins = GEOMETRY["pins"]
    pads = pins["count"]
    pw, gap = pins["width"] * u, pins["gap"] * u
    x0 = (REF_W * u - (pads * pw + (pads - 1) * gap)) / 2
    for i in range(pads):
        r = QRectF(x0 + i * (pw + gap), (win_y + 16) * u, pw, pins["height"] * u)
        gold = QLinearGradient(r.topLeft(), r.bottomRight())
        gold.setColorAt(0.0, QColor("#f6dc8e"))
        gold.setColorAt(0.45, QColor("#d4a642"))
        gold.setColorAt(1.0, QColor("#9c7224"))
        path = _rounded(r.x(), r.y(), r.width(), r.height(), 3 * u)
        p.fillPath(path, gold)
        p.setPen(QPen(QColor(255, 255, 255, 90), max(1.0, 1.2 * u)))
        p.drawLine(QPointF(r.left() + 3 * u, r.top() + 2 * u), QPointF(r.right() - 3 * u, r.top() + 2 * u))

    def raised_text(text, family, weight, px, cx, cy, spacing=0.0):
        font = QFont(family)
        font.setWeight(weight)
        font.setPixelSize(max(4, int(px)))
        if spacing:
            font.setLetterSpacing(QFont.AbsoluteSpacing, spacing)
        fm = QFontMetricsF(font)
        tw = fm.horizontalAdvance(text)
        base = QPointF(cx - tw / 2, cy + fm.capHeight() / 2)
        p.setFont(font)
        # Raised lettering lit from the top-left: bright edge up-left, shade down-right.
        p.setPen(QColor(pal["shellHi"]))
        p.drawText(base + QPointF(-1.2 * u, -1.2 * u), text)
        p.setPen(QColor(0, 0, 0, 110 if edition == "dark" else 60))
        p.drawText(base + QPointF(1.6 * u, 1.8 * u), text)
        p.setPen(QColor(pal["shellTop"]).darker(104))
        p.drawText(base, text)

    cx = REF_W * u / 2
    raised_text("CARTHAGE", "Nunito", QFont.Black, 62 * u, cx, 330 * u, 8 * u)
    raised_text("GAME CARD", "Nunito", QFont.ExtraBold, 26 * u, cx, 392 * u, 6 * u)
    if label:
        raised_text(label.upper(), "DM Mono", QFont.Medium, 24 * u, cx, 600 * u, 2 * u)
    p.end()
    return img


def render_shadow(w, h, edition):
    """w, h is the full padded image; the card silhouette sits inside the padding."""
    pad = w * SHADOW_PAD / (1 + 2 * SHADOW_PAD)
    cw = w - 2 * pad
    u = cw / REF_W
    img = _img(w, h)
    p = QPainter(img)
    p.setRenderHint(QPainter.Antialiasing)
    path = shell_path(u)
    path.translate(pad, pad)
    p.fillPath(path, QColor(EDITIONS[edition]["shadow"]))
    p.end()
    return blur(img, cw * 0.06)


def render_recess(w, h, edition):
    """The molded pocket in the tray. w, h include RECESS_PAD on each side."""
    pal = EDITIONS[edition]
    pad = w * RECESS_PAD / (1 + 2 * RECESS_PAD)
    cw = w - 2 * pad
    u = cw / REF_W
    img = _img(w, h)
    p = QPainter(img)
    p.setRenderHint(QPainter.Antialiasing)
    r = GEOMETRY["radius"] * u + pad
    pocket = _rounded(0.5, 0.5, w - 1, h - 1, r)
    p.fillPath(pocket, QColor(pal["recess"]))

    # Soft inner shadow cast by the top-left lip.
    layer = _img(w, h)
    lp = QPainter(layer)
    lp.setRenderHint(QPainter.Antialiasing)
    lp.fillRect(QRectF(0, 0, w, h), QColor(0, 0, 0, 255))
    lp.setCompositionMode(QPainter.CompositionMode_Clear)
    hole = QPainterPath(pocket)
    hole.translate(cw * 0.022, cw * 0.03)
    lp.fillPath(hole, Qt.black)
    lp.end()
    layer = blur(layer, cw * 0.035)
    p.save()
    p.setClipPath(pocket)
    p.setOpacity(0.55 if edition == "dark" else 0.35)
    p.drawImage(0, 0, layer)
    p.restore()

    g = QLinearGradient(0, 0, w, h)
    g.setColorAt(0.0, QColor(0, 0, 0, 0))
    g.setColorAt(0.6, QColor(0, 0, 0, 0))
    g.setColorAt(1.0, QColor(pal["recessHi"]))
    p.setPen(QPen(QBrush(g), max(1.0, cw * 0.008)))
    p.setBrush(Qt.NoBrush)
    p.drawPath(_rounded(1, 1, w - 2, h - 2, r))
    p.end()
    return img


LOGOS = Path(__file__).resolve().parent / "assets" / "logos"

# How each launcher's official logo is used in the cartridge header:
#   wordmark  the SVG already contains the name; tinted to the header text color
#   icon      the colored icon plus the name set in Nunito Black
#   viewBox   optional crop of the SVG (x, y, w, h) to use only the icon part
#   color     for one-color icons (Simple Icons): the brand color, or "text" for the header
#             text color (brands whose mark is black or white)
HEADER_LOGOS = {
    "steam": {"file": "steam.svg", "kind": "wordmark"},
    "heroic": {"file": "heroic.svg", "kind": "icon", "name": "HEROIC"},
    "lutris": {"file": "lutris.svg", "kind": "icon", "name": "LUTRIS"},
    "flatpak": {"file": "flatpak.svg", "kind": "icon", "name": "FLATPAK", "viewBox": (100, 36, 200, 228)},
    "battlenet": {"file": "battledotnet.svg", "kind": "icon", "name": "BATTLE.NET", "color": "#148eff"},
    "epic": {"file": "epicgames.svg", "kind": "icon", "name": "EPIC GAMES", "color": "text"},
    "riot": {"file": "riotgames.svg", "kind": "icon", "name": "RIOT", "color": "#eb0029"},
    "gog": {"file": "gogdotcom.svg", "kind": "icon", "name": "GOG", "color": "#86328a"},
    "ea": {"file": "ea.svg", "kind": "icon", "name": "EA", "color": "text"},
    # No free Microsoft/Xbox logo (Simple Icons removed them in v13): the name alone.
    "xbox": {"file": None, "kind": "icon", "name": "MICROSOFT STORE"},
}

_svg_lock = threading.Lock()


def _render_svg(name, w, h, view_box=None):
    img = _img(w, h)
    with _svg_lock:
        r = QSvgRenderer(str(LOGOS / name))
        if view_box:
            r.setViewBox(QRectF(*view_box))
        p = QPainter(img)
        p.setRenderHint(QPainter.Antialiasing)
        r.render(p, QRectF(0, 0, w, h))
        p.end()
    return img


def _svg_aspect(name, view_box=None):
    if view_box:
        return view_box[2] / view_box[3]
    with _svg_lock:
        s = QSvgRenderer(str(LOGOS / name)).viewBoxF()
    return s.width() / s.height() if s.height() else 1.0


def _tint(img, color):
    p = QPainter(img)
    p.setCompositionMode(QPainter.CompositionMode_SourceIn)
    p.fillRect(img.rect(), QColor(color))
    p.end()
    return img


UI_ICONS = Path(__file__).resolve().parent / "assets" / "icons" / "ui"
_ICON_ALIASES = {"image": "insert-image"}


def render_icon(w, h, name, color):
    """A bundled interface icon (Breeze, LGPL) in one color — the same on every platform."""
    name = name.removesuffix("-symbolic")
    name = _ICON_ALIASES.get(name, name)
    path = UI_ICONS / f"{name}.svg"
    img = _img(w, h)
    if not path.exists():
        return img
    with _svg_lock:
        r = QSvgRenderer(str(path))
        p = QPainter(img)
        p.setRenderHint(QPainter.Antialiasing)
        r.render(p, QRectF(0, 0, w, h))
        p.end()
    c = QColor("#" + color) if not color.startswith("#") else QColor(color)
    return _tint(img, c)


def render_header_mode(w, h, mode, source, edition, title="", logo_path=None, fallback_name=""):
    """The cartridge's top strip in any of the header modes (Change Header…):
    launcher (default) · logo (the game's own logo) · title · carthage · none, plus the
    user's own: text (typed, drawn as-is) and image (a picture they chose; logo_path)."""
    pal = EDITIONS[edition]
    if mode in ("logo", "image") and logo_path:
        img = _img(w, h)
        logo = QImage(str(logo_path))
        if not logo.isNull():
            lw, lh = w * 0.84, h * 0.72
            scaled = logo.scaled(int(lw), int(lh), Qt.KeepAspectRatio, Qt.SmoothTransformation)
            p = QPainter(img)
            p.setRenderHint(QPainter.SmoothPixmapTransform)
            p.drawImage(QPointF((w - scaled.width()) / 2, (h - scaled.height()) / 2), scaled)
            p.end()
            return img
    if mode in ("title", "carthage", "text"):
        img = _img(w, h)
        p = QPainter(img)
        p.setRenderHint(QPainter.Antialiasing)
        p.setRenderHint(QPainter.TextAntialiasing)
        text = "CARTHAGE" if mode == "carthage" else title if mode == "text" else title.upper()
        font = QFont("Nunito")
        font.setWeight(QFont.Black)
        size = h * 0.36
        font.setPixelSize(max(4, int(size)))
        font.setLetterSpacing(QFont.AbsoluteSpacing, h * (0.05 if mode == "carthage" else 0.01))
        fm = QFontMetricsF(font)
        while fm.horizontalAdvance(text) > w * 0.88 and size > h * 0.16:  # shrink long titles
            size *= 0.92
            font.setPixelSize(max(4, int(size)))
            fm = QFontMetricsF(font)
        p.setFont(font)
        p.setPen(QColor(pal["headerText"]))
        tw = min(fm.horizontalAdvance(text), w * 0.88)
        elided = fm.elidedText(text, Qt.ElideRight, w * 0.88)
        p.drawText(QPointF((w - tw) / 2, (h + fm.capHeight()) / 2), elided)
        p.end()
        return img
    if mode in ("none", "image"):  # image with no picture chosen yet: plain plastic
        return _img(w, h)
    return render_header(w, h, source, edition, fallback_name)


def render_header(w, h, source, edition, fallback_name=""):
    """The header strip of the sticker: the launcher's official logo, centered."""
    pal = EDITIONS[edition]
    img = _img(w, h)
    spec = HEADER_LOGOS.get(source)
    p = QPainter(img)
    p.setRenderHint(QPainter.Antialiasing)
    p.setRenderHint(QPainter.SmoothPixmapTransform)
    if spec and spec["kind"] == "wordmark":
        aspect = _svg_aspect(spec["file"])
        lh = h * 0.54
        lw = min(w * 0.8, lh * aspect)
        lh = lw / aspect
        logo = _tint(_render_svg(spec["file"], int(lw), int(lh)), pal["headerText"])
        p.drawImage(QPointF((w - lw) / 2, (h - lh) / 2), logo)
    else:
        name = spec["name"] if spec else fallback_name.upper()
        font = QFont("Nunito")
        font.setWeight(QFont.Black)
        font.setPixelSize(max(4, int(h * 0.36)))
        font.setLetterSpacing(QFont.AbsoluteSpacing, h * 0.012)
        fm = QFontMetricsF(font)
        has_icon = bool(spec and spec.get("file"))
        ih = h * 0.52 if has_icon else 0
        iw = ih * _svg_aspect(spec["file"], spec.get("viewBox")) if has_icon else 0
        gap = h * 0.1 if has_icon else 0
        # Long names (BATTLE.NET, EPIC GAMES) shrink until logo and name fit side by side.
        size = h * 0.36
        while iw + gap + fm.horizontalAdvance(name) > w * 0.84 and size > h * 0.2:
            size *= 0.94
            font.setPixelSize(max(4, int(size)))
            fm = QFontMetricsF(font)
        tw = fm.horizontalAdvance(name)
        total = min(w * 0.88, iw + gap + tw)
        x = (w - total) / 2
        if has_icon:
            icon = _render_svg(spec["file"], int(iw), int(ih), spec.get("viewBox"))
            if spec.get("color"):
                icon = _tint(icon, pal["headerText"] if spec["color"] == "text" else spec["color"])
            p.drawImage(QPointF(x, (h - ih) / 2), icon)
        p.setFont(font)
        p.setPen(QColor(pal["headerText"]))
        baseline = (h + fm.capHeight()) / 2
        p.drawText(QPointF(x + iw + gap, baseline), name)
    p.end()
    return img



def _hue(text, salt):
    return int(hashlib.sha1((text + salt).encode()).hexdigest()[:6], 16) % 360


def render_generated_art(w, h, title):
    """Placeholder cover: a two-tone gradient with soft shapes and the title."""
    img = _img(w, h)
    p = QPainter(img)
    p.setRenderHint(QPainter.Antialiasing)
    h1 = _hue(title, "a")
    h2 = (h1 + 40 + _hue(title, "b") % 80) % 360
    g = QLinearGradient(0, 0, w, h)
    g.setColorAt(0, QColor.fromHsv(h1, 170, 235))
    g.setColorAt(1, QColor.fromHsv(h2, 200, 120))
    p.fillRect(QRectF(0, 0, w, h), g)

    rnd = random.Random(title)
    for _ in range(5):
        r = rnd.uniform(0.2, 0.6) * w
        cx, cy = rnd.uniform(0, w), rnd.uniform(0, h)
        c = QColor.fromHsv((h1 + rnd.randrange(0, 60)) % 360, 120, 255, rnd.randrange(25, 70))
        p.setPen(Qt.NoPen)
        p.setBrush(c)
        p.drawEllipse(QPointF(cx, cy), r, r)
    p.fillRect(QRectF(0, h * 0.68, w, h * 0.32), QColor(0, 0, 0, 70))

    font = QFont("Nunito")
    font.setWeight(QFont.Black)
    font.setPixelSize(max(6, int(w * 0.12)))
    p.setFont(font)
    rect = QRectF(w * 0.07, h * 0.08, w * 0.86, h * 0.6)
    p.setPen(QColor(0, 0, 0, 110))
    p.drawText(rect.translated(w * 0.012, w * 0.016), Qt.AlignLeft | Qt.AlignTop | Qt.TextWordWrap, title.upper())
    p.setPen(QColor(255, 255, 255))
    p.drawText(rect, Qt.AlignLeft | Qt.AlignTop | Qt.TextWordWrap, title.upper())
    p.end()
    return img


def not_installed(img):
    """Desaturate and dim art for not-installed cards."""
    gray = img.convertToFormat(QImage.Format_Grayscale8).convertToFormat(QImage.Format_ARGB32_Premultiplied)
    p = QPainter(gray)
    p.fillRect(gray.rect(), QColor(0, 0, 0, 90))
    p.end()
    return gray


CACHE_BYTES = 256 * 2**20  # drawn images kept for reuse


class ImageProvider(QQuickImageProvider):
    def __init__(self, library, art=None):
        super().__init__(QQuickImageProvider.Image)
        self._library = library
        self._art = art  # ArtManager, or None (demo library)
        self.header_custom = None  # gameId → (custom text, custom image path); set by app.py
        self._cache = OrderedDict()
        self._bytes = 0
        self._lock = threading.Lock()

    def clear(self):
        with self._lock:
            self._cache.clear()
            self._bytes = 0

    def requestImage(self, image_id, size, requested):
        w = requested.width() if requested.width() > 0 else 300
        h = requested.height() if requested.height() > 0 else int(w * REF_H / REF_W)
        key = (image_id, w, h)
        with self._lock:
            if key in self._cache:
                self._cache.move_to_end(key)
                return self._cache[key]
        img = self._render(image_id, w, h)
        with self._lock:
            if key not in self._cache:
                self._cache[key] = img
                self._bytes += img.sizeInBytes()
            # Oldest first, by count and by size: a store page's big cartridge alone can
            # take several MB, so browsing many pages would otherwise pile up.
            while len(self._cache) > 600 or (self._bytes > CACHE_BYTES and len(self._cache) > 1):
                self._bytes -= self._cache.popitem(last=False)[1].sizeInBytes()
        return img

    def _render(self, image_id, w, h):
        # Optional parameters after "?": tex (texture id), size (grain size), s (strength).
        image_id, _, query = image_id.partition("?")
        params = dict(kv.split("=", 1) for kv in query.split("&") if "=" in kv)
        tex = None
        if "tex" in params:
            from .textures import overlay  # late import: textures uses render.noise

            tex = overlay(params["tex"], params.get("size", "medium"), float(params.get("s", "1")))
        parts = image_id.split("/")
        kind = parts[0]
        if kind == "shell":  # shell/<edition>[/flat]
            return render_shell(w, h, parts[1], flat=len(parts) > 2 and parts[2] == "flat", tex=tex)
        if kind == "back":  # back/<edition>/<flat|edge>/<label>
            return render_back(w, h, parts[1], "/".join(parts[3:]), flat=parts[2] == "flat", tex=tex)
        if kind == "shadow":
            return render_shadow(w, h, parts[1])
        if kind == "recess":
            return render_recess(w, h, parts[1])
        if kind == "header":  # header/<source>/<edition>  or  header/<mode>/<source>/<edition>/<gameId>
            if len(parts) >= 5:
                mode, source, edition, gid = parts[1], parts[2], parts[3], "/".join(parts[4:])
                logo = self._art.logo_path(gid) if (mode == "logo" and self._art) else None
                title = self._library.title_for(gid) or ""
                if mode in ("text", "image") and self.header_custom:
                    custom_text, custom_image = self.header_custom(gid)
                    title = (custom_text or title) if mode == "text" else title
                    logo = custom_image if mode == "image" else logo
                return render_header_mode(w, h, mode, source, edition, title,
                                          logo, self._library.source_name(source))
            return render_header(w, h, parts[1], parts[2], self._library.source_name(parts[1]))
        if kind == "icon":  # icon/<name>/<rrggbb[aa]>: a bundled UI icon, tinted
            return render_icon(w, h, parts[1], parts[2] if len(parts) > 2 else "000000")
        if kind == "brushed":  # brushed: the Hi-Fi skin's aluminum streaks
            return brushed()
        if kind == "grain":  # grain/<edition>?tex=…: the tileable overlay itself
            return tex if tex is not None else noise()
        if kind == "art":
            img = None
            path = self._art.path_for(parts[1]) if self._art else None
            if path:
                loaded = QImage(str(path))
                if not loaded.isNull():
                    img = loaded.scaled(w, h, Qt.KeepAspectRatioByExpanding, Qt.SmoothTransformation)
                    img = img.copy((img.width() - w) // 2, (img.height() - h) // 2, w, h)
                    img = img.convertToFormat(QImage.Format_ARGB32_Premultiplied)
            if img is None:
                title = self._library.title_for(parts[1]) or parts[1]
                img = render_generated_art(w, h, title)
            if len(parts) > 2 and parts[2] == "off":
                img = not_installed(img)
            return img
        return _img(w, h)
