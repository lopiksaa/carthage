"""Color theory for custom plastics: OKLCH math, plastic tones and harmonies.

OKLCH (Björn Ottosson's OKLab in polar form) is used instead of HSL because it's
perceptually even: the same L looks equally light for yellow and for blue, and rotating
the hue keeps the lightness the eye sees. HSL would make a "complementary" yellow for a
blue plastic glare, and a "same lightness" blue look almost black next to a yellow.

Decisions (so they can be revisited):
- A custom color is a hue plus one of five plastic tones (Pastel … Dark). Fully saturated
  colors read as cheap toys on plastic; real consoles use muted, shaded versions.
- Cartridge recommendations for a hardware color use the classic harmonies (analogous,
  complementary, split-complementary, triadic) plus black and white, at a lightness that
  differs from the hardware's (figure/ground: cartridges must stand off the tray), with
  complementary pairs toned down so two opposites don't vibrate at full strength.
"""

import math

TONES = [  # (name, L, C) in OKLCH
    ("Pastel", 0.88, 0.07),
    ("Light", 0.80, 0.11),
    ("Medium", 0.68, 0.14),
    ("Deep", 0.52, 0.13),
    ("Dark", 0.38, 0.09),
]


def _lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _gam(c):
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def hex_to_oklch(h):
    h = h.lstrip("#")[-6:]
    r, g, b = (_lin(int(h[i:i + 2], 16) / 255) for i in (0, 2, 4))
    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l, m, s = (x ** (1 / 3) if x > 0 else 0 for x in (l, m, s))
    L = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
    a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
    bb = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
    return L, math.hypot(a, bb), math.degrees(math.atan2(bb, a)) % 360


def _oklch_to_rgb(L, C, H):
    a, b = C * math.cos(math.radians(H)), C * math.sin(math.radians(H))
    l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    return (4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)


def oklch_to_hex(L, C, H):
    """The closest displayable color: chroma is reduced until it fits in sRGB."""
    for _ in range(40):
        rgb = _oklch_to_rgb(L, C, H)
        if all(-0.0005 <= c <= 1.0005 for c in rgb):
            break
        C *= 0.93
    r, g, b = (round(max(0.0, min(1.0, _gam(max(0.0, c)))) * 255) for c in _oklch_to_rgb(L, C, H))
    return f"#{r:02x}{g:02x}{b:02x}"


def tones(hue):
    """The five plastic tones of a hue: [{name, color}]."""
    return [{"name": n, "color": oklch_to_hex(L, C, hue)} for n, L, C in TONES]


def harmonies(h):
    """Recommended cartridge colors for a hardware color: [{group, name, color}]."""
    L0, C0, H0 = hex_to_oklch(h)
    out = []
    if C0 >= 0.035:
        # Cartridges sit on the tray: give them a clearly different lightness.
        L = max(0.36, L0 - 0.22) if L0 > 0.6 else min(0.86, L0 + 0.22)
        C = min(max(C0, 0.08), 0.15)
        for group, name, dh, k in [
            ("Calm", "Analogous", 30, 1.0), ("Calm", "Analogous", -30, 1.0),
            ("Bold", "Complementary", 180, 0.8), ("Bold", "Split", 150, 0.9), ("Bold", "Split", -150, 0.9),
            ("Playful", "Triadic", 120, 1.0), ("Playful", "Triadic", -120, 1.0),
        ]:
            out.append({"group": group, "name": name, "color": oklch_to_hex(L, C * k, (H0 + dh) % 360)})
    else:
        # Black or white hardware has no hue to harmonize with: any clear color works, so
        # offer an even spread around the wheel at a medium plastic tone.
        for i, name in enumerate(["Red", "Orange", "Yellow", "Green", "Teal", "Blue", "Violet"]):
            out.append({"group": "Any color", "name": name, "color": oklch_to_hex(0.66, 0.13, (25 + i * 51) % 360)})
    out.append({"group": "Classic", "name": "Black", "color": "#3c3c41"})
    out.append({"group": "Classic", "name": "White", "color": "#ffffff"})
    return out


def accent_for_plastic(h, contrast_with_white=4.5):
    """A button/selection color of the plastic's hue that keeps white text readable."""
    _, C0, H0 = hex_to_oklch(h)
    C = min(max(C0, 0.10), 0.16)
    L = 0.55
    for _ in range(30):
        c = oklch_to_hex(L, C, H0)
        if _contrast(c, "#ffffff") >= contrast_with_white:
            return c
        L -= 0.02
    return c


def _lum(h):
    h = h.lstrip("#")[-6:]
    r, g, b = (_lin(int(h[i:i + 2], 16) / 255) for i in (0, 2, 4))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def _contrast(a, b):
    la, lb = sorted([_lum(a), _lum(b)], reverse=True)
    return (la + 0.05) / (lb + 0.05)
