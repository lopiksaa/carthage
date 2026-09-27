"""Hardware editions (DESIGN.md §3) and the cartridge's reference geometry.

Everything that is drawn — by Python into images and by QML live — reads its colors
and measurements from here, so the two can never disagree.
"""

from PySide6.QtCore import Property, QObject, Signal, Slot

# The cartridge is designed on a 600-wide reference canvas, proportioned after a Switch 2
# cartridge (454×664). QML scales with u = width / 600. The canvas includes the cartridge's
# visible thickness: the top face ends THICKNESS units above the canvas bottom.
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
    # The latch notches in both side edges, near the end that goes into the slot: y, height,
    # depth. Angled walls, like the detents a slot's spring clips click into.
    "notch": [708, 54, 10],
    # The shallow well the sticker sits in: how far it reaches past the sticker's edge.
    "stickerWell": 5,
    # Gold contacts on the card's back — and the matching reader contacts in the dock's
    # slot, drawn at the docked cartridge's scale so the two line up.
    "pins": {"count": 11, "width": 20, "gap": 9.6, "height": 64},
}

# Light comes from the top-left for every element (DESIGN.md §3).
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
        "display": "#0e1012",
        "displayText": "#e8efec",
        "displayDim": "#8d9a96",
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
        "display": "#16191b",
        "displayText": "#e8efec",
        "displayDim": "#8d9a96",
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


def _lum(h):
    h = h.lstrip("#")[-6:]
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    f = lambda c: c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4  # noqa: E731
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)


def _contrast(a, b):
    la, lb = sorted([_lum(a), _lum(b)], reverse=True)
    return (la + 0.05) / (lb + 0.05)


def _readable(fg, bg, minimum):
    """Nudge fg away from bg's lightness until the pair reaches `minimum` contrast."""
    step = -0.03 if _lum(bg) > 0.3 else 0.03
    for _ in range(40):
        if _contrast(fg, bg) >= minimum:
            break
        fg = _shift(fg, step)
    return fg


def _fix_contrast(p):
    p["engrave"] = _readable(p["engrave"], p["recess"], 3.0)
    p["dockTextDim"] = _readable(p["dockTextDim"], p["dockBottom"], 4.5)
    p["dockText"] = _readable(p["dockText"], p["dockBottom"], 4.5)
    p["trayTextDim"] = _readable(p["trayTextDim"], p["tray"], 4.5)
    return p


# Extra plastic editions. Each keeps the readable text/panel colors of its template.
EDITIONS["pink"] = _variant("light", "#f7a8c8")
EDITIONS["mint"] = _variant("light", "#9fe3c9")
EDITIONS["neon"] = _variant("dark", "#b8f53a", tray="#1f2415")
EDITIONS["neon"].update({"dockText": "#12160a", "dockTextDim": "#2e3a14", "trayText": "#e9f7cf", "trayTextDim": "#b3c498"})
EDITIONS["atomic"] = _variant("dark", "#6b4bb8")
EDITIONS["red"] = _variant("dark", "#d8343a", tray="#2a1416")
# The Hi-Fi skin: silver aluminum faceplates over a black anodized tray (not a hardware
# color: the skin picks it). Plastic.qml draws brushed streaks instead of the pebbled grain.
EDITIONS["hifi"] = _variant("dark", "#c9cac6", tray="#101010")

for _e in ("pink", "mint", "neon", "atomic", "red", "hifi"):
    _fix_contrast(EDITIONS[_e])

# Picker order and names.
HARDWARE = [
    ("black", "dark", "Black"),
    ("white", "light", "White"),
    ("pink", "pink", "Pink"),
    ("mint", "mint", "Mint"),
    ("neon", "neon", "Neon"),
    ("atomic", "atomic", "Atomic Purple"),
    ("red", "red", "Red"),
]
_HW_TO_EDITION = {k: e for k, e, _ in HARDWARE}


# Custom plastics (the color wheel): an edition named after its color, "c_rrggbb", built the
# first time anything asks for it — from that one color, with the same lighting, contrast
# and accent rules as the built-in editions (colors.py has the color theory).
def _custom_edition(key):
    from . import colors

    plastic = "#" + key[2:]
    L = colors.hex_to_oklch(plastic)[0]
    template = "light" if L > 0.66 else "dark"
    e = _fix_contrast(_variant(template, plastic))
    e["isDark"] = template == "dark"
    return e


def _is_custom(value):
    return isinstance(value, str) and len(value) == 8 and value.startswith("c_") and all(
        ch in "0123456789abcdef" for ch in value[2:])


class _Editions(dict):
    def __missing__(self, key):
        if _is_custom(key):
            self[key] = _custom_edition(key)
            return self[key]
        raise KeyError(key)


EDITIONS = _Editions(EDITIONS)


def edition_of(value):
    """The edition for a hardware/cartridge setting value (a preset name or "c_rrggbb")."""
    return value if _is_custom(value) else _HW_TO_EDITION.get(value)

LED = {"green": "#35c46a", "amber": "#f0a232"}

# Shared by both editions: the primary action (Play) and destructive actions (Quit).
# Accent (primary buttons, selections, toggles) per edition, matched to its plastic.
# Every one keeps ≥4.5:1 contrast with white text.
ACCENTS = {
    "dark": "#0b78b8", "light": "#0b78b8", "pink": "#c2185b", "mint": "#00796b",
    "neon": "#4a7a00", "atomic": "#6b40d6", "red": "#c62828",
    "hifi": "#c2410c",  # the Walkman's orange, deep enough for white text (5.2:1)
}


def accent_for(edition):
    if _is_custom(edition):
        from . import colors

        base = colors.accent_for_plastic("#" + edition[2:])
    else:
        base = ACCENTS.get(edition, ACCENTS["dark"])
    return {"accent": base, "accentHover": _shift(base, -0.06), "accentText": "#ffffff", "danger": "#d33a31"}


PLASTIC_TEXTURE = "Plastic012A"  # ambientCG pebbled plastic (textures.py)
TEXTURE_GRAIN = "coarse"
TEXTURE_STRENGTH = 0.6


class Theme(QObject):
    changed = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._hardware = "black"
        # The chosen look: pebbled plastic, coarse, subtle. The drawer switches it on/off (smooth).
        self._texture = PLASTIC_TEXTURE

    def _get_hardware(self):
        return self._hardware

    def _set_hardware(self, value):
        if edition_of(value) and value != self._hardware:
            self._hardware = value
            self.changed.emit()

    hardware = Property(str, _get_hardware, _set_hardware, notify=changed)

    # "plastic" (the hardware color's plastic, with physical keys, switches and LCDs),
    # "classic" (the same plastic with the original flat controls) or "hifi" (aluminum; the
    # hardware color then only matters for cartridges that follow it).
    _skin = "plastic"

    def _get_skin(self):
        return self._skin

    def _set_skin(self, value):
        value = value if value in ("hifi", "classic") else "plastic"
        if value != self._skin:
            self._skin = value
            self.changed.emit()

    skin = Property(str, _get_skin, _set_skin, notify=changed)

    _card = "same"

    def _get_card(self):
        return self._card

    def _set_card(self, value):
        if value != self._card and (value == "same" or edition_of(value)):
            self._card = value
            self.changed.emit()

    cardColor = Property(str, _get_card, _set_card, notify=changed)

    @Property(str, notify=changed)
    def cardEdition(self):
        """The cartridges' plastic: the hardware's, unless a separate card color is chosen."""
        # The skin never recolors cartridges: "same" follows the hardware *color*, even in Hi-Fi.
        return edition_of(self._hardware) if self._card == "same" else edition_of(self._card)

    @Property("QVariantMap", notify=changed)
    def cp(self):
        """Palette for cartridge surfaces (shell, sticker, labels)."""
        return EDITIONS[self.cardEdition]

    @Property(bool, notify=changed)
    def dark(self):
        """Dark chrome (panels, menus) for this edition."""
        return EDITIONS[self.edition]["isDark"]

    @Slot(float, result="QVariantList")
    def tones(self, hue):
        from . import colors

        return colors.tones(hue)

    @Slot(str, result="QVariantList")
    def harmonies(self, plastic):
        from . import colors

        return colors.harmonies(plastic)

    @Slot(str, result=float)
    def hueOf(self, color):
        from . import colors

        return colors.hex_to_oklch(color)[2]

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
        return [{"value": k, "text": n, "color": EDITIONS[e]["shellTop"]} for k, e, n in HARDWARE]

    # ---- surface texture (textures.py)

    def _get_texture(self):
        return self._texture

    def _set_texture(self, value):
        if value != self._texture:
            self._texture = value
            self.changed.emit()

    texture = Property(str, _get_texture, _set_texture, notify=changed)

    @Property(str, notify=changed)
    def texQuery(self):
        """Appended to image ids so every textured image re-renders when this changes."""
        return f"?tex={self._texture}&size={TEXTURE_GRAIN}&s={TEXTURE_STRENGTH:g}"

    @Property(str, notify=changed)
    def edition(self):
        return "hifi" if self._skin == "hifi" else edition_of(self._hardware)

    @Property("QVariantMap", notify=changed)
    def p(self):
        return EDITIONS[self.edition]

    @Property(float, constant=True)
    def ratio(self):
        return REF_H / REF_W

    @Property("QVariantMap", constant=True)
    def geo(self):
        return GEOMETRY

    @Property("QVariantMap", notify=changed)
    def accent(self):
        return accent_for(self.edition)

    @Property("QVariantMap", constant=True)
    def led(self):
        return LED
