"""Settings → System → Copy Diagnostics: one plain-text report for a bug report, copied to the
clipboard. It says what Carthage needs to know about this PC and this session, and nothing
private: never a key (only whether one is set), the home folder shortened to "~", no game
renames, lists or play history.
"""

import platform
import sys
import time
from pathlib import Path

from .version import VERSION

LOG_LINES = 300  # from the end of each log


# Settings worth knowing when something goes wrong (looks and switches, not personal data).
SETTINGS = ("setupDone", "hardware", "cardColor", "look", "themeMode", "background", "groundColors", "groundTuning", "groundBlur", "gameBackground", "cardWidth", "showTitles",
            "tiltEnabled", "soundsEnabled", "soundVolume", "sortMode", "filterMode", "installedFirst", "favoritesShelf",
            "storeLayout", "otherStores", "hideAdult", "discordPresence", "checkUpdates", "testCartridge",
            "preferOfficialArt", "fontLabels", "fontTitles", "fontButtons", "fontText")
COUNTED = ("hidden", "noSlot", "favorites", "playNext", "titles", "related")


def _private(text):
    """The home folder (any spelling of it) as "~"."""
    home = str(Path.home())
    for form in {home, home.replace("\\", "/"), home.replace("\\", "\\\\")}:
        i = text.lower().find(form.lower())
        while i >= 0:
            text = text[:i] + "~" + text[i + len(form):]
            i = text.lower().find(form.lower(), i + 1)
    return text


def _tail(path, n=LOG_LINES):
    try:
        lines = Path(path).read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return "(none)"
    cut = len(lines) - n
    return ("(… %d earlier lines)\n" % cut if cut > 0 else "") + "\n".join(lines[-n:])


def _system():
    from PySide6 import __version__ as pyside
    from PySide6.QtCore import qVersion
    from PySide6.QtGui import QGuiApplication

    out = [f"Carthage {VERSION}" + (" (installed)" if getattr(sys, "frozen", False) else " (from source)"),
           f"System: {platform.platform()} ({platform.machine()})",
           f"Python {platform.python_version()} · PySide6 {pyside} · Qt {qVersion()}"]
    app = QGuiApplication.instance()
    if app:
        out.append(f"Platform: {app.platformName()}")
        for w in app.topLevelWindows():
            ri = getattr(w, "rendererInterface", None)
            if ri and w.isVisible():
                try:
                    api = ri().graphicsApi().name
                except (AttributeError, RuntimeError):
                    api = "?"
                out.append(f"Window: {w.width()}×{w.height()}, {w.visibility().name}, graphics {api}")
        for s in app.screens():
            g = s.geometry()
            out.append(f"Screen {s.name()}: {g.width()}×{g.height()} at {s.devicePixelRatio():g}× · {s.refreshRate():.0f} Hz"
                       + (" (primary)" if s == app.primaryScreen() else ""))
    return out


def report(backend):
    """The whole report as text."""
    from .library import source_errors, source_label

    lines = ["Carthage diagnostics · " + time.strftime("%Y-%m-%d %H:%M:%S %z"), ""]
    lines += _system()
    lines.append(f"Animation speed: {backend.motion:g}")

    games = backend._library._games
    counts = {}
    for g in games:
        counts[g.source] = counts.get(g.source, 0) + 1
    lines += ["", f"Library: {len(games)} games"
              + (" (demo library)" if backend._fake else "")]
    lines += [f"  {source_label(s)}: {n}" for s, n in sorted(counts.items(), key=lambda kv: -kv[1])]
    installed = sum(1 for g in games if g.installed)
    lines.append(f"  installed: {installed}, hidden: {len(backend._library._hidden)}")
    for name, err in source_errors.items():
        lines.append(f"  couldn't read {name}: {err}")

    rows = backend._sessions._rows
    lines += ["", f"Dock: {len(rows)} " + ("game" if len(rows) == 1 else "games")]
    now = time.time()
    for s in rows:
        kind = (s.handle or {}).get("kind", "simulated")
        lines.append(f"  {s.game.title} [{s.game.source}] · {s.state} · {kind} · "
                     f"{len(s.pids)} processes · launched {now - s.launched:.0f} s ago")

    st = backend._settings
    lines += ["", "Settings:"]
    lines.append("  " + ", ".join(f"{k}={st.get(k)}" for k in SETTINGS))
    lines.append("  " + ", ".join(f"{k}: {len(st.get(k) or [])}" for k in COUNTED))
    has = backend._keys.has if backend._keys else {}
    lines.append("  keys set: " + (", ".join(f"{k}={'yes' if v else 'no'}" for k, v in sorted(has.items())) or "unknown"))

    from .log import log_path

    path = log_path()
    lines += ["", "— Log (this session) —", _tail(path),
              "", "— Log (previous session) —", _tail(path.with_name(path.stem + "-previous.log"))]
    return _private("\n".join(lines)) + "\n"


def copy(backend):
    """Put the report on the clipboard. Returns it (for tests)."""
    from PySide6.QtGui import QGuiApplication

    text = report(backend)
    QGuiApplication.clipboard().setText(text)
    return text
