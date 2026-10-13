"""Hardware editions and the cartridge's reference geometry.

Everything that is drawn — by Python into images and by QML live — reads its colors
and measurements from here, so the two can never disagree.
"""

from PySide6.QtCore import Property, QObject, Signal, Slot

from .colors import accent_for_plastic, contrast, hex_to_oklch, luminance, oklch_to_hex

# The cartridge is designed on a 600-wide canvas; QML scales with u = width / 600. The canvas
# includes the visible thickness: the top face ends THICKNESS units above the bottom.
REF_W = 600.0
REF_H = 878.0
THICKNESS = 12

GEOMETRY = {
    "radius": 36,  # outer corners: small, like a real cartridge (large radii read as phones)
    "thickness": THICKNESS,
    "sticker": [44, 60, 512, 714, 20],  # x, y, w, h, radius — the label: header + art + strip
    "tab": [206, 34, 188, 28, 10],  # the recessed tab on top, attached to the sticker
    "header": [44, 60, 512, 172],
    "art": [44, 232, 512, 454],
    "label": [44, 686, 512, 88],  # the black code strip
    "arrow": [248, 798, 104, 42],  # x, y, w, h — downward arrow groove
    # Latch notches in both side edges: y, height, depth.
    "notch": [708, 54, 10],
    "stickerWell": 5,
    # Drawn at the docked cartridge's scale so the back's contacts and the slot's line up.
    "pins": {"count": 11, "width": 20, "gap": 9.6, "height": 64},
}

# Light comes from the top-left for every element.
EDITIONS = {
    "dark": {
        "shellTop": "#3c3c41",
        "shellBottom": "#222226",
        "shellSide": "#0b0b0d",
        "shellHi": "#40ffffff",
        "shellLo": "#80000000",
        "groove": "#18181b",
        "stickerHead": "#1c1c1f",
        "stickerEdge": "#99000000",
        "stickerSheen": "#14ffffff",
        "artBack": "#000000",
        "labelBack": "#0b0b0c",
        "headerText": "#f4f4f4",
        "labelText": "#f0f0f0",
        "grain": 0.07,
        "tray": "#2a2a2e",
        "trayShade": "#40000000",
        "recess": "#1c1c1f",
        "recessHi": "#26ffffff",
        "engrave": "#6a6a70",
        "engraveHi": "#14ffffff",
        "trayText": "#e8e8ea",
        "trayTextDim": "#a2a2a8",
        "dockTop": "#3a3a3e",
        "dockBottom": "#202023",
        "dockHi": "#40ffffff",
        "dockSeam": "#000000",
        "dockText": "#f0f0f2",
        "dockTextDim": "#a8a8ae",
        "ledOff": "#48484c",
        "shadow": "#000000",
        "dangerText": "#ff6f66",
        "panel": "#2b2b30",
        "panelText": "#f2f2f4",
        "panelTextDim": "#a9a9b1",
        "panelBorder": "#3d3d44",
        "panelHover": "#3a3a41",
        "scrim": "#a6000000",
        "shadowStrength": 0.55,
    },
    "light": {
        "shellTop": "#ffffff",
        "shellBottom": "#dcdce1",
        "shellSide": "#a4a4ac",
        "shellHi": "#ffffffff",
        "shellLo": "#40000000",
        "groove": "#cdcdd3",
        "stickerHead": "#f3f3f6",
        "stickerEdge": "#40000000",
        "stickerSheen": "#26ffffff",
        "artBack": "#000000",
        "labelBack": "#111114",
        "headerText": "#1c1c20",
        "labelText": "#f2f2f2",
        "grain": 0.05,
        "tray": "#d9d9de",
        "trayShade": "#2a000000",
        "recess": "#c4c4ca",
        "recessHi": "#b3ffffff",
        "engrave": "#65656e",
        "engraveHi": "#ccffffff",
        "trayText": "#1e1e22",
        "trayTextDim": "#55555c",
        "dockTop": "#fbfbfc",
        "dockBottom": "#dedee2",
        "dockHi": "#ffffffff",
        "dockSeam": "#9a9aa0",
        "dockText": "#1e1e22",
        "dockTextDim": "#55555c",
        "ledOff": "#b4b4ba",
        "shadow": "#000000",
        "dangerText": "#c62f27",
        "panel": "#fbfbfc",
        "panelText": "#1c1c20",
        "panelTextDim": "#5e5e66",
        "panelBorder": "#d6d6dc",
        "panelHover": "#ececf1",
        "scrim": "#73000000",
        "shadowStrength": 0.42,
    },
}

EDITIONS["dark"]["isDark"] = True
EDITIONS["light"]["isDark"] = False


def _shift(hexcolor, lightness=0.0, saturation=0.0):
    """Adjust a color's HSL lightness/saturation by absolute amounts (-1..1)."""
    import colorsys

    h = hexcolor.lstrip("#")[-6:]
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    hh, ll, ss = colorsys.rgb_to_hls(r, g, b)
    ll = min(1, max(0, ll + lightness))
    ss = min(1, max(0, ss + saturation))
    r, g, b = colorsys.hls_to_rgb(hh, ll, ss)
    return "#%02x%02x%02x" % (round(r * 255), round(g * 255), round(b * 255))


def _variant(template, plastic, tray=None):
    """A colored hardware edition: the template's labels, text and panels, with every plastic
    surface derived from one plastic color (lit from the top-left like the rest)."""
    p = dict(EDITIONS[template])
    tray = tray or _shift(plastic, 0.12 if template == "light" else -0.22, -0.15)
    p.update({
        "shellTop": _shift(plastic, 0.07),
        "shellBottom": _shift(plastic, -0.08),
        "shellSide": _shift(plastic, -0.30),
        "groove": _shift(plastic, -0.12),
        "tray": tray,
        "recess": _shift(tray, -0.07),
        "dockTop": _shift(plastic, 0.05),
        "dockBottom": _shift(plastic, -0.10),
        "dockSeam": _shift(plastic, -0.35),
        "ledOff": _shift(plastic, -0.18),
        "engrave": _shift(tray, -0.38 if template == "light" else 0.30),
    })
    return p


def _readable(fg, bg, minimum):
    """Nudge fg away from bg's lightness until the pair reaches `minimum` contrast."""
    step = -0.03 if luminance(bg) > 0.3 else 0.03
    for _ in range(40):
        if contrast(fg, bg) >= minimum:
            break
        fg = _shift(fg, step)
    return fg


def _readable_on(fg, backgrounds, minimum):
    """fg readable (≥ minimum) on every one of `backgrounds` (a gradient's ends): nudged toward
    whichever of white or black can get there, even if that means crossing to the other side
    (mid-tone plastics need dark text)."""
    def worst(c):
        return min(contrast(c, b) for b in backgrounds)
    if worst(fg) >= minimum:
        return fg
    step = 0.03 if worst("#ffffff") >= worst("#000000") else -0.03
    for _ in range(60):
        if worst(fg) >= minimum:
            break
        fg = _shift(fg, step)
    return fg


def _fix_contrast(p):
    p["engrave"] = _readable(p["engrave"], p["recess"], 3.0)
    # The plastic is a gradient (the sidebar and dock span all of it): readable on both ends.
    p["dockText"] = _readable_on(p["dockText"], (p["dockTop"], p["dockBottom"]), 4.5)
    # Mid-tone plastics where no text color reaches 4.5:1 on both ends: the failing end of the
    # gradient moves (a little deeper or lighter) until the text does. Cartridge shells keep
    # their own colors.
    light_text = luminance(p["dockText"]) > 0.5
    for _ in range(30):
        top_ok = contrast(p["dockText"], p["dockTop"]) >= 4.5
        bottom_ok = contrast(p["dockText"], p["dockBottom"]) >= 4.5
        if top_ok and bottom_ok:
            break
        step = -0.02 if light_text else 0.02
        if not top_ok:
            p["dockTop"] = _shift(p["dockTop"], step)
        if not bottom_ok:
            p["dockBottom"] = _shift(p["dockBottom"], step)
    p["dockTextDim"] = _readable_on(p["dockTextDim"], (p["dockTop"], p["dockBottom"]), 4.5)
    if min(contrast(p["dockTextDim"], b) for b in (p["dockTop"], p["dockBottom"])) < 4.5:
        p["dockTextDim"] = p["dockText"]  # no room for a dimmer readable shade
    p["trayTextDim"] = _readable_on(p["trayTextDim"], (p["tray"],), 4.5)
    if contrast(p["trayTextDim"], p["tray"]) < 4.5:
        p["trayTextDim"] = p["trayText"]
    return p


EDITIONS["pink"] = _variant("light", "#f7a8c8")
EDITIONS["mint"] = _variant("light", "#9fe3c9")
EDITIONS["neon"] = _variant("dark", "#b8f53a", tray="#1f2415")
EDITIONS["neon"].update({"dockText": "#12160a", "dockTextDim": "#2e3a14", "trayText": "#e9f7cf", "trayTextDim": "#b3c498"})
EDITIONS["atomic"] = _variant("dark", "#6b4bb8")
EDITIONS["red"] = _variant("dark", "#d8343a", tray="#2a1416")

for _e in ("dark", "light", "pink", "mint", "neon", "atomic", "red"):
    _fix_contrast(EDITIONS[_e])


# An edition from one plastic color, as the color picker makes them: light or dark chrome
# by the color's lightness, every other surface derived from it (colors.py).
def _plastic_edition(plastic):
    L = hex_to_oklch(plastic)[0]
    template = "light" if L > 0.66 else "dark"
    e = _fix_contrast(_variant(template, plastic))
    e["isDark"] = template == "dark"
    return e


# Presets made from one plastic color.
_PLASTIC_PRESETS = {
    "warmgrey": "#8e877d", "lightgrey": "#a3a5ab", "offwhite": "#ebe7de", "orange": "#e0772b",
    "forest": "#2f5f48", "teal": "#23807e", "sky": "#86c3ea", "lavender": "#b9a8e3",
}
for _k, _c in _PLASTIC_PRESETS.items():
    EDITIONS[_k] = _plastic_edition(_c)

# The hardware colors offered in Settings, in this order: neutrals dark to light, then
# colors around the wheel.
HARDWARE = [
    ("black", "dark", "Black"),
    ("warmgrey", "warmgrey", "Warm Grey"),
    ("lightgrey", "lightgrey", "Light Grey"),
    ("offwhite", "offwhite", "Off-White"),
    ("white", "light", "White"),
    ("red", "red", "Red"),
    ("orange", "orange", "Orange"),
    ("neon", "neon", "Neon"),
    ("mint", "mint", "Mint"),
    ("forest", "forest", "Forest"),
    ("teal", "teal", "Teal"),
    ("sky", "sky", "Sky"),
    ("lavender", "lavender", "Lavender"),
    ("atomic", "atomic", "Atomic Purple"),
    ("pink", "pink", "Pink"),
]
_HW_TO_EDITION = {k: e for k, e, _ in HARDWARE}
# The eight colours Settings suggests (for the theme and the cartridges); the rest stay valid
# for settings saved before, and the colour picker reaches anything.
SUGGESTED = ["black", "white", "red", "orange", "neon", "teal", "sky", "atomic"]

# The cartridge colour that goes with each suggested theme colour (Pick for me): a neutral
# console gets a lively cartridge, a colourful one its opposite on the colour wheel or a neutral.
CARTRIDGE_FOR = {
    "black": "red", "white": "orange", "red": "white", "orange": "teal",
    "neon": "atomic", "teal": "orange", "sky": "white", "atomic": "neon",
}


def suggested_cartridge(hardware, plastic):
    """The suggested cartridge colour for any theme colour: the pair above for the eight, and
    for any other colour (older presets, the colour picker) the suggested colour nearest its
    opposite on the wheel (a neutral one is treated like black or white)."""
    import colorsys

    if hardware in CARTRIDGE_FOR:
        return CARTRIDGE_FOR[hardware]
    c = (plastic or "#808080").lstrip("#")[-6:]
    h, light, sat = colorsys.rgb_to_hls(*(int(c[i:i + 2], 16) / 255 for i in (0, 2, 4)))
    if sat < 0.2:
        return CARTRIDGE_FOR["black" if light < 0.5 else "white"]

    def hue(value):
        p = EDITIONS[_HW_TO_EDITION[value]]["shellTop"].lstrip("#")[-6:]
        return colorsys.rgb_to_hls(*(int(p[i:i + 2], 16) / 255 for i in (0, 2, 4)))[0]

    opposite = (h + 0.5) % 1
    colourful = [v for v in SUGGESTED if v not in ("black", "white")]
    return min(colourful, key=lambda v: min(abs(hue(v) - opposite), 1 - abs(hue(v) - opposite)))

# Each preset's one plastic colour, for building it in the other mode.
_PLASTIC = {"dark": "#3c3c41", "light": "#f4f4f6", "pink": "#f7a8c8", "mint": "#9fe3c9", "neon": "#b8f53a",
            "atomic": "#6b4bb8", "red": "#d8343a", **_PLASTIC_PRESETS}


# Custom plastics: an edition named "c_rrggbb", built on first use from that one color.
def _custom_edition(key):
    return _plastic_edition("#" + key[2:])


def _is_custom(value):
    return isinstance(value, str) and len(value) == 8 and value.startswith("c_") and all(
        ch in "0123456789abcdef" for ch in value[2:])


def _mix(c1, c2, k):
    a, b = c1.lstrip("#")[-6:], c2.lstrip("#")[-6:]
    return "#" + "".join("%02x" % round(int(a[i:i + 2], 16) * (1 - k) + int(b[i:i + 2], 16) * k) for i in (0, 2, 4))


def _mode_edition(plastic, mode):
    """Any plastic colour in either mode (Settings → Appearance: the mode and the colour are
    chosen apart). The room is the mode's, deep or pale, with a touch of the colour; the
    hardware keeps the colour itself, its text made readable on it."""
    tray = _mix(plastic, "#151519" if mode == "dark" else "#f1f1f4", 0.84)
    p = _variant(mode, plastic, tray=tray)
    p["trayText"] = _readable_on(p["trayText"], (tray,), 7.0)
    p = _fix_contrast(p)
    p["isDark"] = mode == "dark"
    return p


class _Editions(dict):
    def __missing__(self, key):
        # "<edition>~<mode>": an edition shown in the other mode than its own.
        if isinstance(key, str) and "~" in key:
            base, mode = key.split("~", 1)
            if mode in ("dark", "light") and (base in _PLASTIC or _is_custom(base)):
                self[key] = _mode_edition(_PLASTIC.get(base) or "#" + base[2:], mode)
                return self[key]
        if _is_custom(key):
            self[key] = _custom_edition(key)
            return self[key]
        raise KeyError(key)


EDITIONS = _Editions(EDITIONS)


def edition_of(value, mode=""):
    """The edition for a hardware/cartridge setting value (a preset name or "c_rrggbb"), in
    `mode` ("dark" / "light"; "" = the colour's own)."""
    e = value if _is_custom(value) else _HW_TO_EDITION.get(value)
    if e and mode in ("dark", "light") and EDITIONS[e]["isDark"] != (mode == "dark"):
        return f"{e}~{mode}"
    return e

LED = {"green": "#35c46a", "amber": "#f0a232"}

# Accents keep ≥4.5:1 contrast with white text.
ACCENTS = {
    "dark": "#0b78b8", "light": "#0b78b8", "pink": "#c2185b", "mint": "#00796b",
    "neon": "#4a7a00", "atomic": "#6b40d6", "red": "#c62828",
}


def accent_for(edition):
    edition = edition.split("~", 1)[0]  # the same accent in either mode
    if _is_custom(edition) or edition in _PLASTIC_PRESETS:
        base = accent_for_plastic(_PLASTIC_PRESETS.get(edition) or "#" + edition[2:])
    else:
        base = ACCENTS.get(edition, ACCENTS["dark"])
    return {"accent": base, "accentHover": _shift(base, -0.06), "accentText": "#ffffff", "danger": "#d33a31"}


# Glass (the default look): frosted panes over a backdrop of soft colour fields. Values from the
# design handoff (design/carthage-handoff, HANDOFF.md "Glass tokens"); dark hardware takes the
# graphite set, light hardware the off-white one.
def _rgba(r, g, b, a):
    return "#%02x%02x%02x%02x" % (round(a * 255), r, g, b)


GLASS = {
    "dark": {
        "text": "#F4F5F7", "text2": "#C9CCD3", "title": "#E6E8EC",
        "keyText": "#F4F5F7", "keyDim": "#C9CCD3", "keyOff": "#8E919A",
        "tint": _rgba(26, 28, 36, .48), "sheen": _rgba(255, 255, 255, .08),
        "edge": _rgba(255, 255, 255, .26), "ring": _rgba(255, 255, 255, .09), "shadow": _rgba(0, 0, 0, .50),
        "field": _rgba(0, 0, 0, .24), "well": _rgba(255, 255, 255, .035),
        "mouth": _rgba(0, 0, 0, .55), "readout": _rgba(0, 0, 0, .28),
        "warn": "#F2B544", "accent": "#3F9BEA",
        # Panels (menus, dialogs) float over busy cartridge art: a denser tint keeps text readable.
        "panelTint": _rgba(26, 28, 36, .80), "hover": "#3A3D48",
        # Over scrolling cartridge art (dock, sidebar) the handoff's .48 let text fall to 2.7:1;
        # this keeps text and text-2 at ≥ 4.5:1 over the brightest art (measured).
        "busyTint": _rgba(26, 28, 36, .73),  # (opaque: code fades it with Qt.alpha)
        "bg": "#0D0E12",  # (night: a little deeper than the handoff's #121318)
        "fields": [_rgba(116, 198, 70, .34), _rgba(139, 79, 217, .40), _rgba(60, 140, 220, .36), _rgba(226, 120, 80, .22)],
    },
    "light": {
        "text": "#15161A", "text2": "#45484F", "title": "#2B2D33",
        "keyText": "#15161A", "keyDim": "#4A4D55", "keyOff": "#989BA3",
        "tint": _rgba(255, 255, 255, .52), "sheen": _rgba(255, 255, 255, .40),
        "edge": _rgba(255, 255, 255, .95), "ring": _rgba(255, 255, 255, .60), "shadow": _rgba(60, 64, 90, .24),
        "field": _rgba(255, 255, 255, .45), "well": _rgba(255, 255, 255, .28),
        "mouth": _rgba(0, 0, 0, .55), "readout": _rgba(0, 0, 0, .28),
        "warn": "#7A4E00", "accent": "#1272C4",
        "panelTint": _rgba(255, 255, 255, .80), "hover": "#E1E4EC",
        "busyTint": _rgba(255, 255, 255, .66),
        "bg": "#F3F5F9",  # (day: a little brighter than the handoff's #ECEEF3)
        "fields": [_rgba(160, 222, 110, .42), _rgba(184, 150, 240, .42), _rgba(120, 180, 240, .42), _rgba(250, 170, 140, .32)],
    },
}
# Where the four fields sit: centre and radii as fractions of the window; each fades out at 70 %.
GLASS_FIELDS = [(0.14, 0.34, 0.38, 0.46), (0.84, 0.22, 0.34, 0.44), (0.58, 0.96, 0.46, 0.50), (0.46, 0.52, 0.30, 0.36)]


def glass_for(edition, dark=None):
    """The glass tokens for a hardware edition. A colourful hardware tints the backdrop's
    fields toward its own colour, so the choice still shows through the glass."""
    import colorsys

    pal = EDITIONS[edition]
    base = pal["shellTop"].lstrip("#")[-6:]
    r, g, b = (int(base[i:i + 2], 16) for i in (0, 2, 4))
    is_dark = pal["isDark"] if dark is None else dark
    t = dict(GLASS["dark" if is_dark else "light"])
    _h, light, sat = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    if sat > 0.18 and 0.08 < light < 0.95:
        # A colourful hardware colours the whole look (neutrals keep the handoff's values): the
        # ground takes a third of it (darkened or lightened to stay a ground), the fields move
        # most of the way to it and glow a little more, and the glass takes a faint tint.
        dark = is_dark

        def mix(c1, c2, k):
            return tuple(round(a + (b - a) * k) for a, b in zip(c1, c2))

        def hexa(argb):
            return tuple(int(argb[i:i + 2], 16) for i in (1, 3, 5, 7))

        hw = (r, g, b)
        ground = mix(hw, (0, 0, 0), 0.72) if dark else mix(hw, (255, 255, 255), 0.78)
        bg = tuple(int(t["bg"][i:i + 2], 16) for i in (1, 3, 5))
        t["bg"] = "#%02x%02x%02x" % mix(bg, ground, 0.35)
        fields = []
        for f in t["fields"]:
            fa, *frgb = hexa(f)
            fields.append("#%02x%02x%02x%02x" % ((min(255, round(fa * 1.35)),) + mix(frgb, hw, 0.85)))
        t["fields"] = fields
        ta, *trgb = hexa(t["tint"])
        t["tint"] = "#%02x%02x%02x%02x" % ((ta,) + mix(trgb, ground, 0.22))
        t["accent"] = accent_for(edition)["accent"]
    t["centres"] = [list(c) for c in GLASS_FIELDS]
    return t


# The Glass theme's ground (ground.html): Settings → Appearance → Background (the style),
# Background Colors (a preset) and Advanced (its colours one by one, and every other variable).
# The glass itself takes a tint of the ground's first colour, as glass would.
def glass_colour(hue):
    """The colour of a hue (0–359, OKLCH) the glass is tinted with; "" for clear glass."""
    return oklch_to_hex(0.62, 0.15, hue) if 0 <= hue < 360 else ""


def glass_edition(hue, mode):
    """The edition the glass is drawn with: clear glass is the mode's own neutral one."""
    if not 0 <= hue < 360:
        return "light" if mode == "light" else "dark"
    return edition_of("c_" + glass_colour(hue)[1:], mode)


# Background colours: four hues (OKLCH) for the ground's four corners (top left, top right,
# bottom right, bottom left), their strength, and a tone (a grey ground lifted toward pewter at
# night, dimmed by day). The mode sets the lightness, so every one stays a calm ground.
GROUNDS = [  # (the first is the default)
    ("candy", "Candy", ([350, 230, 305, 40], 0.11, 0)),
    ("nebula", "Nebula", ([265, 303, 233, 340], 0.12, 0)),
    ("aurora", "Aurora", ([150, 190, 300, 250], 0.12, 0)),
    ("sunset", "Sunset", ([45, 10, 330, 80], 0.13, 0)),
    ("ocean", "Ocean", ([240, 200, 270, 215], 0.12, 0)),
    ("ember", "Ember", ([30, 55, 10, 75], 0.13, 0)),
    ("forest", "Forest", ([145, 120, 175, 100], 0.10, 0)),
    ("silver", "Silver", ([265, 265, 265, 265], 0.015, 0.5)),
]
HUE_KEYS = ("hue1", "hue2", "hue3", "hue4")  # Advanced: each colour's own hue, over the preset's

# Advanced: every variable of the ground, [key, label, from, to, default, unit, styles] (no
# styles: all of them). Saved in the groundTuning setting; missing keys are the defaults.
GROUND_TUNING = [
    ("speed", "Speed", 0, 3, 1, "×", ["mesh", "rays", "iris", "topo"]),
    ("scale", "Size", 0.4, 2.5, 1, "×", ["mesh", "rays", "iris", "topo"]),
    ("turbulence", "Turbulence", 0, 2, 1, "×", ["mesh", "iris", "topo"]),
    ("depth", "Depth", 0, 2, 1, "×", ["mesh", "iris", "topo"]),
    ("light", "Light direction", 0, 360, 130, "°", ["mesh", "rays", "iris", "topo"]),
    ("rays", "Light rays", 0, 2, 1, "×", ["rays"]),
    ("sheen", "Holographic sheen", 0, 2, 1, "×", ["iris"]),
    ("lines", "Line density", 0.3, 3, 1, "×", ["topo"]),
    ("glow", "Line glow", 0, 2, 1, "×", ["topo"]),
    ("saturation", "Color intensity", 0, 2, 1, "×", []),
    ("brightness", "Brightness", -1, 1, 0, "%", []),
    ("vignette", "Vignette", 0, 2, 1, "×", []),
    ("grain", "Grain", 0, 1, 0, "%", []),
]
_COLOUR_KEYS = HUE_KEYS + ("saturation", "brightness")


def tuning_value(tuning, key):
    for k, _n, lo, hi, default, _u, _s in GROUND_TUNING:
        if k == key:
            try:
                return min(hi, max(lo, float(tuning.get(key, default))))
            except (TypeError, ValueError):
                return default
    raise KeyError(key)


def ground_for(choice, tuning):
    """The ground's colours: the preset's hues (or Advanced's own), strength, tone and lift."""
    hues, chroma, tone = next((s for k, _n, s in GROUNDS if k == choice), GROUNDS[0][2])
    own = []
    for key, h in zip(HUE_KEYS, hues):
        try:
            own.append(float(tuning[key]) % 360 if key in tuning else h)
        except (TypeError, ValueError):
            own.append(h)
    return {"hues": own, "chroma": chroma * tuning_value(tuning, "saturation"), "tone": tone,
            "lift": tuning_value(tuning, "brightness")}


# The four corners' lightness and share of the chroma, at night and by day (ground.html palette()).
_CORNERS = {True: ((0.42, 1.05), (0.36, 1.0), (0.30, 0.9), (0.26, 0.8)),
            False: ((0.84, 0.95), (0.80, 1.0), (0.86, 0.85), (0.82, 0.9))}


def _corner(g, dark, i, hue):
    L, k = _CORNERS[dark][i]
    L += (0.16 if dark else -0.12) * g["tone"] + (0.12 if dark else 0.06) * g["lift"]
    return oklch_to_hex(max(0.0, min(0.99, L)), g["chroma"] * k, hue % 360)


def ground_colours(g, dark):
    """The ground's four colours, as ground.html's palette() makes them (for the swatches)."""
    return [_corner(g, dark, i, h) for i, h in enumerate(g["hues"])]


# The plastic texture (an ambientCG normal map, textures.py), on hardware and cartridges: one
# plastic, at one grain and depth. Appended to the textured images' ids (render.py).
PLASTIC_TEXTURE = "Plastic012A"
TEXTURE_QUERY = f"?tex={PLASTIC_TEXTURE}&size=coarse&s=0.6"


def _cached(fn):
    """A Theme value worked out once per change: every themed item reads these, and a colour
    change had them all recomputed thousands of times (a 400 ms hitch)."""
    name = fn.__name__

    def get(self):
        memo = self._memo
        if name not in memo:
            memo[name] = fn(self)
        return memo[name]

    get.__name__ = name
    return get


class Theme(QObject):
    changed = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._hardware = "black"
        self._memo = {}

    def _announce(self):
        """Fresh values, then the news: the cache is cleared before anything bound to the theme
        reads it again (a connection to `changed` ran too late: each switch showed the last one)."""
        self._memo.clear()
        self.changed.emit()

    def _get_hardware(self):
        return self._hardware

    def _set_hardware(self, value):
        if edition_of(value) and value != self._hardware:
            self._hardware = value
            self._announce()

    hardware = Property(str, _get_hardware, _set_hardware, notify=changed)

    _card = "same"

    def _get_card(self):
        return self._card

    def _set_card(self, value):
        if value != self._card and (value in ("same", "auto") or edition_of(value)):
            self._card = value
            self._announce()

    # "same" (the theme colour), "auto" (Pick for me: the suggested colour for the theme
    # colour, or in Glass for the ground's, following it when it changes), or a colour.
    cardColor = Property(str, _get_card, _set_card, notify=changed)

    @Property(str, notify=changed)
    @_cached
    def cardValue(self):
        """The cartridge colour in use, as a colour value ("same" and "auto" worked out)."""
        if self._card == "same":
            return self._hardware
        if self._card == "auto":
            if self._look == "glass":  # to go with the ground (a grey one: like black or white)
                h = self._glass_hue()
                return suggested_cartridge(None, glass_colour(h) if h >= 0 else _PLASTIC["dark" if self.dark else "light"])
            return suggested_cartridge(self._hardware, self.plasticOf(self._hardware))
        return self._card

    @Property(str, notify=changed)
    @_cached
    def cardEdition(self):
        """The cartridges' plastic (their own colour, not the mode's)."""
        return edition_of(self.cardValue)

    @Slot(str, result=str)
    def editionFor(self, value):
        """The cartridge edition for a color setting value ("" or unknown: the usual one)."""
        return edition_of(value) or self.cardEdition

    @Slot(str, result="QVariantMap")
    def paletteFor(self, edition):
        """A cartridge palette (like cp) for any edition."""
        try:
            return EDITIONS[edition]  # (not .get: custom colours are built on first use)
        except KeyError:
            return EDITIONS[self.cardEdition]

    @Property("QVariantMap", notify=changed)
    @_cached
    def cp(self):
        """Palette for cartridge surfaces (shell, sticker, labels)."""
        return EDITIONS[self.cardEdition]

    @Property(bool, notify=changed)
    @_cached
    def dark(self):
        """Dark mode (Settings → Appearance → Mode; any colour works in either)."""
        return EDITIONS[self.edition]["isDark"]

    _mode = ""  # "dark" / "light"; "" (never chosen) = the colour's own, as before the switch

    def _get_mode(self):
        return self._mode

    def _set_mode(self, value):
        value = value if value in ("dark", "light") else ""
        if value != self._mode:
            self._mode = value
            self._announce()

    mode = Property(str, _get_mode, _set_mode, notify=changed)

    @Slot(str, result=str)
    def customValue(self, color):
        """The setting value for a custom plastic color ("#d9a34b" → "c_d9a34b")."""
        return "c_" + color.lstrip("#").lower()[-6:]

    @Slot(str, result=str)
    def plasticOf(self, value):
        """The plastic color of a setting value (preset or custom), for chips and previews."""
        e = edition_of(value)
        return EDITIONS[e]["shellTop"] if e else ""

    @Property("QVariantList", constant=True)
    def hardwareOptions(self):
        """Every preset: [{value, text, color, suggested}] (Settings shows the suggested ones)."""
        return [{"value": k, "text": n, "color": EDITIONS[e]["shellTop"], "suggested": k in SUGGESTED}
                for k, e, n in HARDWARE]

    @Property(str, constant=True)
    def texQuery(self):
        """Appended to the hardware's textured image ids."""
        return TEXTURE_QUERY

    @Property(str, constant=True)
    def cardTexQuery(self):
        """Appended to the cartridges' textured image ids."""
        return TEXTURE_QUERY

    @Property(str, notify=changed)
    @_cached
    def edition(self):
        """The look's colour in the chosen mode: the theme colour (Plastic), or for Glass a
        tint of the ground's first colour (clear over a grey ground)."""
        if self._look == "glass":
            return glass_edition(self._glass_hue(), self._mode)
        return edition_of(self._hardware, self._mode)

    def _glass_hue(self):
        g = ground_for(self._ground, self._tuning)
        # (in steps of 10°: each tint is an edition, and its images are drawn once)
        return round(g["hues"][0] / 10) * 10 % 360 if g["chroma"] >= 0.03 else -1

    _ground = GROUNDS[0][0]

    def _get_ground(self):
        return self._ground

    def _set_ground(self, value):
        value = value if any(k == value for k, _n, _s in GROUNDS) else GROUNDS[0][0]
        if value != self._ground:
            self._ground = value
            self._announce()

    groundColors = Property(str, _get_ground, _set_ground, notify=changed)

    _tuning = {}

    def set_ground_tuning(self, value):
        """Advanced (the groundTuning setting). Only its colours change the theme; WebGround
        reads the rest straight from the setting."""
        value = dict(value or {})
        before = {k: self._tuning.get(k) for k in _COLOUR_KEYS}
        self._tuning = value
        if before != {k: value.get(k) for k in _COLOUR_KEYS}:
            self._announce()

    @Property("QVariantMap", notify=changed)
    @_cached
    def ground(self):
        """The glass ground's colours, for ground.html (WebGround.qml)."""
        return ground_for(self._ground, self._tuning)

    @Property("QVariantList", notify=changed)
    @_cached
    def groundOptions(self):
        """The background colour presets: [{value, text, colors}], each as it looks now (in
        the mode, with Advanced's intensity and brightness; the preset's own hues)."""
        plain = {k: v for k, v in self._tuning.items() if k not in HUE_KEYS}
        return [{"value": k, "text": n, "colors": ground_colours(ground_for(k, plain), self.dark)}
                for k, n, _s in GROUNDS]

    @Property(bool, notify=changed)
    @_cached
    def groundCustom(self):
        """Advanced has changed a colour of the preset."""
        return any(k in self._tuning for k in HUE_KEYS)

    @Property("QVariantList", notify=changed)
    @_cached
    def groundNow(self):
        """The ground's four colours as they are now."""
        return ground_colours(ground_for(self._ground, self._tuning), self.dark)

    @Property("QVariantList", notify=changed)
    @_cached
    def groundHueTracks(self):
        """For each colour, that colour every 30° round the wheel, as the ground draws it
        (Advanced's hue sliders)."""
        g = ground_for(self._ground, self._tuning)
        return [[_corner(g, self.dark, i, h) for h in range(0, 361, 30)] for i in range(4)]

    @Property("QVariantList", constant=True)
    def groundTuningSpec(self):
        return [{"key": k, "text": n, "from": lo, "to": hi, "default": d, "unit": u, "styles": s}
                for k, n, lo, hi, d, u, s in GROUND_TUNING]

    @Property("QVariantMap", notify=changed)
    @_cached
    def p(self):
        pal = EDITIONS[self.edition]
        if self._look != "glass":
            return pal
        # Glass: text over the panes and the backdrop comes from the glass tokens.
        g = glass_for(self.edition, self.dark)
        return {**pal, "trayText": g["text"], "trayTextDim": g["text2"],
                "dockText": g["keyText"], "dockTextDim": g["keyDim"],
                "panel": g["panelTint"], "panelText": g["text"], "panelTextDim": g["text2"],
                "panelBorder": g["ring"], "panelHover": g["hover"]}

    @Property(float, constant=True)
    def ratio(self):
        return REF_H / REF_W

    @Property("QVariantMap", constant=True)
    def geo(self):
        return GEOMETRY

    _look = "glass"

    def _get_look(self):
        return self._look

    def _set_look(self, value):
        value = "plastic" if value == "plastic" else "glass"
        if value != self._look:
            self._look = value
            self._announce()

    look = Property(str, _get_look, _set_look, notify=changed)

    @Property(bool, notify=changed)
    @_cached
    def glassy(self):
        return self._look == "glass"

    @Property("QVariantMap", notify=changed)
    @_cached
    def glass(self):
        return glass_for(self.edition, self.dark)

    @Property("QVariantMap", notify=changed)
    @_cached
    def accent(self):
        return accent_for(self.edition)

    @Property("QVariantMap", constant=True)
    def led(self):
        return LED
