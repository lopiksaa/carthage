"""User preferences, saved to ~/.config/carthage/settings.json."""

import copy
import json
import os

from PySide6.QtCore import Property, QObject, QTimer, Signal


def _same_kind(default, value):
    """A saved value is only used if it has the default's type (a float accepts an int)."""
    if isinstance(default, float):
        return isinstance(value, (int, float)) and not isinstance(value, bool)
    return type(value) is type(default)


class Settings(QObject):
    """User preferences, saved to ~/.config/carthage/settings.json (debounced)."""

    changed = Signal()

    DEFAULTS = {
        "tiltEnabled": True, "soundsEnabled": True, "showTitles": True, "cardWidth": 150,
        "soundVolume": 0.3, "hardware": "black", "texturedPlastic": True, "preferOfficialArt": False,
        "sortMode": "recent", "filterMode": "all", "hidden": [], "noSlot": [],
        "titles": {}, "headers": {}, "headerTexts": {}, "sgdbIds": {},
        # Only the eject uses a recording (the chosen one); the rest are modeled on it
        # (tools/make_sounds.py).
        "soundChoice": {"release": "release_2.wav"},
        "cardColor": "same", "testCartridge": False, "related": {}, "installedFirst": False,
        "checkUpdates": True, "setupDone": False, "hideAdult": True,
        "favorites": [], "crtEffects": True,
        # The favorites shelf above the tray: off unless turned on (Menu → Library).
        "favoritesShelf": False,
        # The store's other stores (GOG, Microsoft Store, EA, Battle.net) via IsThereAnyDeal.
        "otherStores": False,
        # Discord Rich Presence ("Choosing a Game" / "Browsing Store"), off unless asked for.
        "discordPresence": False,
        # The version whose "What's new" was last seen ("" = before this existed).
        "lastVersion": "",
        # The skin: "plastic" (keys, switches, LCDs), "classic" (the original flat controls)
        # or "hifi" (aluminum, VFD, tape keys).
        "skin": "plastic",
    }

    def __init__(self, parent=None):
        super().__init__(parent)
        from .chrome import REAL_CONFIG_HOME

        self._path = REAL_CONFIG_HOME / "carthage" / "settings.json"
        self._values = dict(self.DEFAULTS)
        # No settings file yet: Carthage has never run here (the setup wizard shows).
        self.first_run = not self._path.exists()
        try:
            saved = json.loads(self._path.read_text(encoding="utf-8"))
            for key, value in saved.items():
                if key in self.DEFAULTS and _same_kind(self.DEFAULTS[key], value):
                    self._values[key] = value
        except (OSError, ValueError):
            pass
        self._save_timer = QTimer(self)
        self._save_timer.setSingleShot(True)
        self._save_timer.setInterval(400)
        self._save_timer.timeout.connect(self._save)
        self.changed.connect(self._save_timer.start)

    def _save(self):
        # Scripted test runs (GC_DEMO) never touch the user's real settings.
        if os.environ.get("GC_DEMO"):
            return
        try:
            self._path.parent.mkdir(parents=True, exist_ok=True)
            tmp = self._path.with_suffix(".tmp")
            tmp.write_text(json.dumps(self._values, indent=2), encoding="utf-8")
            os.replace(tmp, self._path)
        except OSError:
            pass

    def reset(self):
        """Everything back to the defaults (setup stays done)."""
        self._values = copy.deepcopy(self.DEFAULTS) | {k: self._values[k] for k in ("setupDone", "lastVersion")}
        self.changed.emit()

    def get(self, name):
        return self._values[name]

    def set(self, name, value):
        if self._values.get(name) != value:
            self._values[name] = value
            self.changed.emit()

    def _prop(name, typ, notify):  # noqa: N805 — small property factory
        def get(self):
            return self._values[name]

        def set_(self, value):
            self.set(name, value)

        return Property(typ, get, set_, notify=notify)

    tiltEnabled = _prop("tiltEnabled", bool, changed)
    soundsEnabled = _prop("soundsEnabled", bool, changed)
    showTitles = _prop("showTitles", bool, changed)
    cardWidth = _prop("cardWidth", int, changed)
    soundVolume = _prop("soundVolume", float, changed)
    hardware = _prop("hardware", str, changed)
    cardColor = _prop("cardColor", str, changed)
    testCartridge = _prop("testCartridge", bool, changed)
    installedFirst = _prop("installedFirst", bool, changed)
    checkUpdates = _prop("checkUpdates", bool, changed)
    hideAdult = _prop("hideAdult", bool, changed)
    otherStores = _prop("otherStores", bool, changed)
    discordPresence = _prop("discordPresence", bool, changed)
    skin = _prop("skin", str, changed)
    favoritesShelf = _prop("favoritesShelf", bool, changed)
    crtEffects = _prop("crtEffects", bool, changed)
    texturedPlastic = _prop("texturedPlastic", bool, changed)
    preferOfficialArt = _prop("preferOfficialArt", bool, changed)
    soundChoice = _prop("soundChoice", "QVariantMap", changed)
    del _prop
