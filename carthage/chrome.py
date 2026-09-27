"""App chrome (toolbar, menus, dialogs) with its own look, independent of the desktop theme.

Carthage deliberately doesn't inherit the desktop's widget style, colors, icons or fonts.
It uses KDE's Breeze style, the Breeze
Light/Dark color schemes (following the hardware edition), Breeze icons and Nunito.

Why this takes more than QIcon.setThemeName(): on Plasma, KDE's own libraries (the Qt
platform theme, KIconThemes, KColorScheme) read the desktop settings straight from
`kdeglobals` and re-apply them after startup. So Carthage runs with a private config
home holding its *own* kdeglobals. Only the user's animation speed is copied over, so
Carthage still honors that accessibility setting. The real ~/.config is untouched.
"""

import configparser
import os
import subprocess
import sys
from pathlib import Path

from PySide6.QtCore import QLibraryInfo
from PySide6.QtGui import QColor, QFont, QFontDatabase, QIcon, QPalette

IS_LINUX = sys.platform.startswith("linux")
SCHEMES = {
    False: Path("/usr/share/color-schemes/BreezeLight.colors"),
    True: Path("/usr/share/color-schemes/BreezeDark.colors"),
}
# Breeze when the system's Qt has it, else Fusion. Carthage draws most controls itself.
KDE_LOOK = (IS_LINUX and SCHEMES[False].exists() and SCHEMES[True].exists()
            and (Path(QLibraryInfo.path(QLibraryInfo.LibraryPath.QmlImportsPath)) / "org/kde/breeze").is_dir())
STYLE = "org.kde.breeze" if KDE_LOOK else "Fusion"
FONT_FAMILY = "Nunito"  # rounded and friendly (bundled, OFL)
FONT_SIZE = 10.5
FONTS_DIR = Path(__file__).resolve().parent / "assets" / "fonts"

# The user's real config home, captured before it's redirected. Carthage's own settings
# live under REAL_CONFIG_HOME / "carthage".
REAL_CONFIG_HOME = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
PRIVATE_HOME = REAL_CONFIG_HOME / "carthage" / "look"


def _color(cfg, group, key, fallback="#ff00ff"):
    try:
        r, g, b = (int(v) for v in cfg[group][key].split(",")[:3])
        return QColor(r, g, b)
    except (KeyError, ValueError):
        return QColor(fallback)


def _palette(cfg):
    pal = QPalette()
    roles = {
        QPalette.Window: ("Colors:Window", "BackgroundNormal"),
        QPalette.WindowText: ("Colors:Window", "ForegroundNormal"),
        QPalette.Base: ("Colors:View", "BackgroundNormal"),
        QPalette.AlternateBase: ("Colors:View", "BackgroundAlternate"),
        QPalette.Text: ("Colors:View", "ForegroundNormal"),
        QPalette.PlaceholderText: ("Colors:View", "ForegroundInactive"),
        QPalette.Button: ("Colors:Button", "BackgroundNormal"),
        QPalette.ButtonText: ("Colors:Button", "ForegroundNormal"),
        QPalette.Highlight: ("Colors:Selection", "BackgroundNormal"),
        QPalette.HighlightedText: ("Colors:Selection", "ForegroundNormal"),
        QPalette.ToolTipBase: ("Colors:Tooltip", "BackgroundNormal"),
        QPalette.ToolTipText: ("Colors:Tooltip", "ForegroundNormal"),
        QPalette.Link: ("Colors:View", "ForegroundLink"),
        QPalette.LinkVisited: ("Colors:View", "ForegroundVisited"),
    }
    for role, (group, key) in roles.items():
        pal.setColor(role, _color(cfg, group, key))
    for role in (QPalette.WindowText, QPalette.Text, QPalette.ButtonText):
        pal.setColor(QPalette.Disabled, role, _color(cfg, "Colors:View", "ForegroundInactive"))
    return pal


def animation_factor():
    return _user_animation_factor() if IS_LINUX else 1.0


def _user_animation_factor():
    """The desktop's animation-speed setting (an accessibility preference) — kept."""
    try:
        out = subprocess.run(
            ["kreadconfig6", "--file", "kdeglobals", "--group", "KDE", "--key", "AnimationDurationFactor"],
            capture_output=True, text=True, timeout=2,
        ).stdout.strip()
        return float(out) if out else 1.0
    except (OSError, ValueError, subprocess.TimeoutExpired):
        return 1.0


def _font_spec(size, weight=400):
    # QFont::toString() format as KDE writes it.
    return f"{FONT_FAMILY},{size},-1,5,{weight},0,0,0,0,0,0,0,0,0,0,1"


def _write_private_kdeglobals(dark=False):
    PRIVATE_HOME.mkdir(parents=True, exist_ok=True)
    scheme = SCHEMES[bool(dark)].read_text(encoding="utf-8")
    factor = _user_animation_factor()
    settings = f"""
[General]
ColorScheme={"BreezeDark" if dark else "BreezeLight"}
font={_font_spec(FONT_SIZE)}
menuFont={_font_spec(FONT_SIZE)}
toolBarFont={_font_spec(FONT_SIZE - 0.5)}
smallestReadableFont={_font_spec(8.5)}
fixed=DM Mono,{FONT_SIZE},-1,5,500,0,0,0,0,0,0,0,0,0,0,1

[Icons]
Theme=breeze

[KDE]
AnimationDurationFactor={factor}
widgetStyle=Breeze
"""
    # Scheme first (its [General]/[KDE] groups are overridden by ours, which come later).
    (PRIVATE_HOME / "kdeglobals").write_text(scheme + "\n" + settings, encoding="utf-8")


def _fontconfig_with_bundled_fonts():
    """Make the bundled fonts visible to everything from the first frame (the platform
    theme resolves fonts before the app could register them itself)."""
    conf = PRIVATE_HOME / "fonts.conf"
    conf.write_text(f"""<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <include ignore_missing="yes">/etc/fonts/fonts.conf</include>
  <dir>{FONTS_DIR}</dir>
</fontconfig>
""", encoding="utf-8")
    os.environ["FONTCONFIG_FILE"] = str(conf)


def before_app():
    """Call before QApplication exists. The private KDE settings only matter with the KDE look."""
    if not KDE_LOOK:
        return
    _write_private_kdeglobals(dark=False)
    _fontconfig_with_bundled_fonts()
    os.environ["XDG_CONFIG_HOME"] = str(PRIVATE_HOME)


def apply(app, dark):
    """Switch the chrome between Breeze Light and Breeze Dark at runtime."""
    path = SCHEMES[bool(dark)]
    if not KDE_LOOK:  # elsewhere: the style's own palette
        return
    app.setProperty("KDE_COLOR_SCHEME_PATH", str(path))
    cfg = configparser.ConfigParser(interpolation=None, strict=False)
    cfg.optionxform = str
    cfg.read(path, encoding="utf-8")
    app.setPalette(_palette(cfg))


def setup(app):
    """Call before loading QML."""
    if KDE_LOOK:
        QIcon.setThemeName("breeze")
    for f in sorted(FONTS_DIR.glob("*.ttf")):
        QFontDatabase.addApplicationFont(str(f))
    font = QFont(FONT_FAMILY)
    font.setPointSizeF(FONT_SIZE)
    app.setFont(font)
