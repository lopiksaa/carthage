"""App chrome (standard menus, fields and dialogs) with its own look, the same everywhere.

Carthage doesn't take its colors or fonts from the desktop: it uses Qt's neutral Fusion
style with a fixed light or dark palette (following the hardware edition) and the bundled
fonts. So it looks the same on every distro and desktop. The one desktop setting it keeps
is the animation speed, an accessibility preference.
"""

import os
import subprocess
import sys
from pathlib import Path

from PySide6.QtGui import QColor, QFont, QFontDatabase, QPalette

IS_LINUX = sys.platform.startswith("linux")
STYLE = "Fusion"
FONT_FAMILY = "Nunito"  # the app-wide default; the interface fonts are chosen in Ui.qml
FONT_SIZE = 10.5
FONTS_DIR = Path(__file__).resolve().parent / "assets" / "fonts"

# The user's config folder. Carthage's own settings live under CONFIG_HOME / "carthage".
CONFIG_HOME = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")

# The chrome's palettes (the values of KDE's Breeze Light and Breeze Dark), built in so no
# desktop theme can change them.
_PALETTES = {
    False: {"Window": "#eff0f1", "WindowText": "#232629", "Base": "#ffffff", "AlternateBase": "#f7f7f7",
            "Text": "#232629", "PlaceholderText": "#707d8a", "Button": "#fcfcfc", "ButtonText": "#232629",
            "Highlight": "#3daee9", "HighlightedText": "#ffffff", "ToolTipBase": "#f7f7f7",
            "ToolTipText": "#232629", "Link": "#2980b9", "LinkVisited": "#9b59b6", "Disabled": "#707d8a"},
    True: {"Window": "#202326", "WindowText": "#fcfcfc", "Base": "#141618", "AlternateBase": "#1d1f22",
           "Text": "#fcfcfc", "PlaceholderText": "#a1a9b1", "Button": "#292c30", "ButtonText": "#fcfcfc",
           "Highlight": "#3daee9", "HighlightedText": "#fcfcfc", "ToolTipBase": "#292c30",
           "ToolTipText": "#fcfcfc", "Link": "#1d99f3", "LinkVisited": "#9b59b6", "Disabled": "#a1a9b1"},
}


def _palette(dark):
    colors = _PALETTES[bool(dark)]
    pal = QPalette()
    for name, value in colors.items():
        if name != "Disabled":
            pal.setColor(getattr(QPalette, name), QColor(value))
    for role in (QPalette.WindowText, QPalette.Text, QPalette.ButtonText):
        pal.setColor(QPalette.Disabled, role, QColor(colors["Disabled"]))
    return pal


def animation_factor():
    """The desktop's animation speed (1 = normal, 0 = instant): KDE's setting, or GNOME's
    "reduce animations" switch, else 1."""
    if not IS_LINUX:
        return 1.0
    try:
        out = subprocess.run(
            ["kreadconfig6", "--file", "kdeglobals", "--group", "KDE", "--key", "AnimationDurationFactor"],
            capture_output=True, text=True, timeout=2,
        ).stdout.strip()
        if out:
            return float(out)
    except (OSError, ValueError, subprocess.TimeoutExpired):
        pass
    try:
        out = subprocess.run(
            ["gsettings", "get", "org.gnome.desktop.interface", "enable-animations"],
            capture_output=True, text=True, timeout=2,
        ).stdout.strip()
        if out == "false":
            return 0.0
    except (OSError, subprocess.TimeoutExpired):
        pass
    return 1.0


def apply(app, dark):
    """Switch the chrome between its light and dark palette."""
    app.setPalette(_palette(dark))


def setup(app):
    """Call before loading QML: the bundled fonts and the default font."""
    for f in sorted(FONTS_DIR.glob("*.ttf")):
        QFontDatabase.addApplicationFont(str(f))
    font = QFont(FONT_FAMILY)
    font.setPointSizeF(FONT_SIZE)
    app.setFont(font)
