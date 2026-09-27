"""The single object QML talks to: models, settings, watchers and actions."""

import threading
from pathlib import Path

from PySide6.QtCore import Property, QObject, QTimer, QUrl, Signal, Slot

from .library import GameModel, TrayModel, fake_games, real_games
from .sessions import SessionModel
from .settings import Settings
from .theme import PLASTIC_TEXTURE, Theme
from .version import VERSION
from .watchers import InstallWatch, LibraryWatcher, Status

ASSETS = Path(__file__).resolve().parent / "assets"


def _human(size):
    for unit in ("B", "KB", "MB", "GB"):
        if size < 1024 or unit == "GB":
            return f"{size:.0f} {unit}" if unit in ("B", "KB") else f"{size:.1f} {unit}"
        size /= 1024


class Backend(QObject):
    libraryError = Signal(str)

    def __init__(self, fake=False, parent=None):
        super().__init__(parent)
        self._fake = fake
        import os

        self._test_run = bool(os.environ.get("GC_DEMO")) and not fake
        self._theme = Theme(self)
        self._settings = Settings(self)
        games = fake_games() if fake else self._load_real()
        self._library = GameModel(games, self)
        self._tray = TrayModel(self._library, self)
        self._favorites = TrayModel(self._library, self, part="favorites", mirror=self._tray)
        st = self._settings
        self._apply_favorites()
        self._shelf_on = st.get("favoritesShelf")
        st.changed.connect(self._shelf_toggled)
        if not fake:
            from .playtime import PlayLog

            self._library.play_log = PlayLog()
            self._library.restore(st.get("hidden"), st.get("noSlot"), st.get("titles"))
            self._tray.sortMode = st.get("sortMode")
            self._tray.filterMode = st.get("filterMode")
            self._tray.changed.connect(self._save_tray)
        self._tray.installedFirst = st.get("installedFirst")
        st.changed.connect(lambda: setattr(self._tray, "installedFirst", st.get("installedFirst")))
        def apply_texture():
            self._theme.texture = PLASTIC_TEXTURE if st.get("texturedPlastic") else "none"

        apply_texture()
        st.changed.connect(apply_texture)
        self._sessions = SessionModel(self._library, real=not fake, parent=self)
        self._sessions.frozen = self._test_run  # tests never quit or kill real games
        self._sessions.set_related(self._settings.get("related"))
        self._sessions.played.connect(self._library.add_play)
        self._headerImageDone.connect(self._header_image_done)
        from .updater import Updater

        self._updater = Updater(lambda: not fake and self._settings.get("checkUpdates"), self)
        from .discord import Presence

        # Never from the demo library or a scripted test: those would show on the real Discord.
        self._presence = Presence(lambda: not fake and not self._test_run and self._settings.get("discordPresence"))
        self._settings.changed.connect(self._presence.refresh)
        self._status = Status(self._library, self)
        self._install = InstallWatch(self) if not fake else None
        from .store import Store

        self._store = Store(lambda: {int(g.ext_id) for g in self._library._games
                                     if g.source == "steam" and g.ext_id.isdigit()},
                            lambda: self._settings.get("hideAdult"), self,
                            other_stores=lambda: self._settings.get("otherStores"))
        from .keys import Keys
        from .sources import steam

        self._keys = Keys(lambda: steam.steam_id64(steam.find_root()) if steam.find_root() else None, self)
        self._library.modelReset.connect(self._status.changed)
        self._library.refreshed.connect(self._status.changed)
        self._art = None
        self._art_rev = {}
        if not fake:
            from .art import ArtManager

            self._art = ArtManager(self._library, lambda: self._settings.get("preferOfficialArt"), self._settings, self)
            self._art.logoReady.connect(lambda _gid: (self._bump_headers(), self.headersChanged.emit()))
            self._art.ready.connect(self._art_ready)
            self._art.regenerated.connect(self._art_regenerated)
            prefetch = lambda: self._art.prefetch([g.game_id for g in self._library._games])  # noqa: E731
            QTimer.singleShot(800, prefetch)
            self._library.modelReset.connect(lambda: QTimer.singleShot(800, prefetch))
            self._art.regenerated.connect(lambda: QTimer.singleShot(200, prefetch))
            self._prefer_official = self._settings.get("preferOfficialArt")
            self._settings.changed.connect(self._art_source_changed)
        if not fake:
            self._watch = LibraryWatcher(self)
            self._watch.loaded.connect(lambda games: self._library.reset(self._with_test(games)))
            self._test_on = self._settings.get("testCartridge")
            self._settings.changed.connect(self._test_toggled)
            self._watch.failed.connect(self.libraryError)

    def _load_real(self):
        try:
            games = real_games()
        except Exception:
            import logging

            logging.getLogger("carthage").exception("Couldn't read the library")
            games = []
        return self._with_test(games)

    @Slot(result=str)
    def libraryProblems(self):
        """Launchers that couldn't be read, for a notice ("" = all fine)."""
        from .library import source_errors

        return ", ".join(source_errors)

    @Slot(result=str)
    def logFile(self):
        from . import log

        return str(log.log_path())

    artChanged = Signal()

    def _art_ready(self, game_id):
        self._art_rev[game_id] = self._art_rev.get(game_id, 0) + 1
        self.artChanged.emit()

    _art_gen = 0

    def _art_regenerated(self):
        self._art_gen += 1
        self.artChanged.emit()

    def _art_source_changed(self):
        now = self._settings.get("preferOfficialArt")
        if now != self._prefer_official:
            self._prefer_official = now
            self._art.drop_automatic()

    @Property(int, notify=artChanged)
    def artTick(self):
        return sum(self._art_rev.values())

    @Property(int, notify=artChanged)
    def artGen(self):
        return self._art_gen

    image_provider = None  # set by app.py, so clearing the cache also drops rendered images

    @Slot(result=str)
    def cacheSize(self):
        from .art import CACHE as ART_CACHE

        total = sum(f.stat().st_size for f in ART_CACHE.parent.rglob("*") if f.is_file())
        return _human(total)

    @Slot(result=str)
    def clearCache(self):
        """Settings → Clear Cache: downloaded art and store data. Keeps hand-picked art and
        the running-games file; everything else is fetched again in the background."""
        from .sources import steam

        freed = 0
        if self._art:
            freed += self._art.clear_cache()
        freed += self._store.clear_cache()
        try:
            freed += steam.OWNED_CACHE.stat().st_size
            steam.OWNED_CACHE.unlink()
        except OSError:
            pass
        if self.image_provider:
            self.image_provider.clear()
        if not self._fake:
            self._watch.refresh_owned(force=True)
        self._art_regenerated()
        return _human(freed)

    @Slot()
    def rescan(self):
        """Maintenance: read every launcher's files again and refresh the Steam list."""
        if self._fake:
            return
        self._watch.reload()
        self._watch.refresh_owned(force=True)

    @Slot(str, result=int)
    def artRevOf(self, game_id):
        return self._art_rev.get(game_id, 0)

    @property
    def art(self):
        return self._art

    @Property(QObject, constant=True)
    def artPicker(self):
        return self._art

    def _with_test(self, games):
        from .library import test_cartridge

        if self._settings.get("testCartridge"):
            games = [test_cartridge()] + list(games)
        return games

    def _test_toggled(self):
        if self._settings.get("testCartridge") != self._test_on:
            self._test_on = self._settings.get("testCartridge")
            self._watch.reload()

    @Property(float, constant=True)
    def motion(self):
        """Animation speed factor: KDE's accessibility setting on Linux, 1 elsewhere; 0 = instant."""
        from . import chrome

        return chrome.animation_factor()

    @Property(bool, constant=True)
    def fake(self):
        return self._fake

    @property
    def library(self):
        return self._library

    @Property(QObject, constant=True)
    def theme(self):
        return self._theme

    @Property(QObject, constant=True)
    def settings(self):
        return self._settings

    @Property(QObject, constant=True)
    def games(self):
        return self._tray

    @Property(QObject, constant=True)
    def favorites(self):
        """The favorites shelf's games (the tray holds the rest)."""
        return self._favorites

    @Slot()
    def resetSettings(self):
        """Settings → Reset All Settings: every preference and per-game choice back to the
        defaults. API keys, play time and hand-picked art stay."""
        st = self._settings
        st.reset()
        self._library.restore(st.get("hidden"), st.get("noSlot"), st.get("titles"))
        self._tray.sortMode = st.get("sortMode")
        self._tray.filterMode = st.get("filterMode")
        self._apply_favorites()
        self._sessions.set_related(st.get("related"))
        self._bump_headers()
        self.headersChanged.emit()

    def _shelf_toggled(self):
        if self._settings.get("favoritesShelf") != self._shelf_on:
            self._shelf_on = self._settings.get("favoritesShelf")
            self._apply_favorites()

    def _apply_favorites(self):
        ids = self._settings.get("favorites") if self._settings.get("favoritesShelf") else []
        self._tray.set_favorites(ids)
        self._favorites.set_favorites(ids)

    @Slot(str, result=bool)
    def isFavorite(self, game_id):
        return self._settings.get("favoritesShelf") and game_id in self._settings.get("favorites")

    @Slot(str, bool)
    def setFavorite(self, game_id, on):
        """Onto the favorites shelf (on) or back into the tray."""
        favs = [g for g in self._settings.get("favorites") if g != game_id]
        if on:
            favs.append(game_id)
        self._settings.set("favorites", favs)
        self._apply_favorites()

    @Property(QObject, constant=True)
    def store(self):
        return self._store

    @Slot(int, result=str)
    def libraryIdForApp(self, appid):
        """The library game id for an owned Steam app ("" if not in the library)."""
        gid = f"steam_{appid}"
        return gid if self._library.game(gid) else ""

    @Property(QObject, constant=True)
    def installs(self):
        return self._install

    @Property(QObject, constant=True)
    def updater(self):
        return self._updater

    @Slot(str, bool)
    def setPresence(self, screen, game_running):
        """Which screen is open, for Discord ("library" / "store"); cleared while a game runs."""
        self._presence.set(screen, game_running)

    @Property(QObject, constant=True)
    def keys(self):
        return self._keys

    @Slot(str)
    def openUrl(self, url):
        from PySide6.QtGui import QDesktopServices

        QDesktopServices.openUrl(QUrl(url))

    @Property(QObject, constant=True)
    def status(self):
        return self._status

    @Property(QObject, constant=True)
    def sessions(self):
        return self._sessions

    @Slot(str, result=QUrl)
    def soundUrl(self, name):
        chosen = self._settings.get("soundChoice").get(name)
        if chosen and (ASSETS / "sounds" / "lab" / chosen).exists():
            return QUrl.fromLocalFile(str(ASSETS / "sounds" / "lab" / chosen))
        return QUrl.fromLocalFile(str(ASSETS / "sounds" / f"{name}.wav"))

    @Slot(str, result=str)
    def launch(self, game_id):
        """Returns what the UI should show:
        slot | noslot | running | install (handed to Steam) | install-elsewhere | missing."""
        from . import launcher

        g = self._library.game(game_id)
        if g is None:
            return "missing"
        if self._test_run:
            # A scripted test (GC_DEMO) on the real library never starts anything, whatever
            # gets clicked.
            import logging

            logging.getLogger("carthage").warning("Test run: not launching %s", g.title)
            return "test"
        if not g.installed:
            if self._fake or not launcher.install(g):
                return "install-elsewhere"
            return "install"
        if self._sessions.indexOf(game_id) >= 0:
            return "running"
        self._library.touch(game_id)
        if g.no_slot:
            if g.executable and not self._fake:
                launcher.launch(g)  # started, but not tracked or docked
            return "noslot"
        self._sessions.launch(g)
        return "slot"

    @Property(bool, constant=True)
    def firstRun(self):
        """Show the setup wizard: Carthage has never run on this PC (not for the demo library)."""
        return not self._fake and self._settings.first_run and not self._settings.get("setupDone")

    @Slot()
    def setupFinished(self):
        self._settings.set("setupDone", True)
        # A new install has nothing "new" to show: its first What's new is the next update.
        self._settings.set("lastVersion", VERSION)

    @Property("QVariantMap", constant=True)
    def whatsNew(self):
        """This version's notes when it's new to this PC (an update, not a first install), else {}."""
        from .whatsnew import notes_for

        if self._fake or self._test_run or self._settings.first_run or not self._settings.get("setupDone"):
            return {}
        if self._settings.get("lastVersion") == VERSION:
            return {}
        return notes_for(VERSION) or {}

    @Slot(result="QVariantMap")
    def whatsNewNotes(self):
        """This version's notes, always (Menu → What's new, and the demo harness)."""
        from .whatsnew import NOTES, notes_for

        return notes_for(VERSION) or notes_for(next(iter(NOTES))) or {}

    @Slot()
    def whatsNewSeen(self):
        self._settings.set("lastVersion", VERSION)

    @Slot(result="QVariantList")
    def launcherSummary(self):
        """[{name, count}] of the launchers that gave games, for the setup wizard."""
        from .library import source_label

        counts = {}
        for g in self._library._games:
            if g.source != "carthage":
                counts[g.source] = counts.get(g.source, 0) + 1
        return [{"name": source_label(s), "count": n} for s, n in sorted(counts.items(), key=lambda kv: -kv[1])]

    @Slot(QUrl, result=str)
    def localPath(self, url):
        """A file dialog's file:// URL as a path ("C:\\Games\\x.exe" on Windows, not "/C:/Games/x.exe")."""
        import os

        path = url.toLocalFile()
        return os.path.normpath(path) if os.name == "nt" else path

    @Slot(str, str, result=str)
    def addGame(self, name, command):
        """Add a game by hand. Returns an error message, or "" on success."""
        from .sources import manual

        name, command = name.strip(), command.strip()
        if not name:
            return "Give the game a name."
        if not command:
            return "Choose the program to start, or type a command."
        try:
            manual.add(name, command)
        except OSError as e:
            return f"Couldn't save the game ({e.strerror})."
        if not self._fake:
            self._watch.reload()
        return ""

    @Slot(str)
    def removeCustomGame(self, game_id):
        from .sources import manual

        if game_id.startswith("manual_"):
            manual.remove(game_id[len("manual_"):])
            if not self._fake:
                self._watch.reload()

    def _save_tray(self):
        self._settings.set("sortMode", self._tray.sortMode)
        self._settings.set("filterMode", self._tray.filterMode)

    @Slot(str, bool)
    def setHidden(self, game_id, hidden):
        self._library.set_hidden(game_id, hidden)
        if not self._fake:
            self._settings.set("hidden", sorted(self._library._hidden))

    @Slot(str, str)
    def rename(self, game_id, title):
        """A user-chosen name ("" goes back to the launcher's name)."""
        titles = dict(self._settings.get("titles"))
        title = title.strip()
        if title:
            titles[game_id] = title
        else:
            titles.pop(game_id, None)
        self._settings.set("titles", titles)
        self._library.set_title_override(game_id, title)

    @Slot(str)
    def demoFinishInstall(self, game_id):
        """Demo harness only: an install finishes (the library reloads, as with Steam)."""
        if not self._fake:
            return
        games = list(self._library._games)
        for g in games:
            if g.game_id == game_id:
                g.installed = True
        self._library.reset(games)

    @Slot(str, result=bool)
    def isInstalled(self, game_id):
        g = self._library._by_id.get(game_id)
        return bool(g and g.installed)

    @Slot(str, result=bool)
    def playtimeEditable(self, game_id):
        """Carthage keeps the play time for everything except Steam games."""
        g = self._library._by_id.get(game_id)
        return bool(g and self._library.play_log and self._library.play_log.counts(g))

    @Slot(str, result=str)
    def playtimeHours(self, game_id):
        g = self._library._by_id.get(game_id)
        return f"{g.playtime / 60:g}" if g and g.playtime else "0"

    @Slot(str, str, result=bool)
    def setPlaytime(self, game_id, text):
        """Hours as typed ("12", "3.5", "3,5"); False if it isn't a number."""
        try:
            hours = float(text.strip().replace(",", "."))
        except ValueError:
            return False
        if not 0 <= hours < 100_000:
            return False
        self._library.set_playtime(game_id, round(hours * 60))
        return True

    @Slot(str, result=str)
    def headerOf(self, game_id):
        return self._settings.get("headers").get(game_id, "launcher")

    @Slot(str, str)
    def setHeader(self, game_id, mode):
        headers = dict(self._settings.get("headers"))
        if mode == "launcher":
            headers.pop(game_id, None)
        else:
            headers[game_id] = mode
        self._settings.set("headers", headers)
        if mode == "logo" and self._art:
            self._art.fetch_logo(game_id)
        self._bump_headers()
        self.headersChanged.emit()

    headersChanged = Signal()
    headerImageFailed = Signal(str)  # message
    _headerImageDone = Signal(str, bool)  # worker → UI thread
    _header_tick = 0

    @staticmethod
    def _header_image_path(game_id):
        from .chrome import REAL_CONFIG_HOME

        safe = "".join(c if c.isalnum() or c in "-_" else "_" for c in game_id)
        return REAL_CONFIG_HOME / "carthage" / "headers" / (safe + ".png")

    def header_custom(self, game_id):
        """(custom text, custom image path or None) — for the image provider."""
        path = self._header_image_path(game_id)
        return self._settings.get("headerTexts").get(game_id, ""), (path if path.exists() else None)

    @Slot(str, result=str)
    def headerTextOf(self, game_id):
        return self._settings.get("headerTexts").get(game_id, "")

    @Slot(str, str)
    def setHeaderText(self, game_id, text):
        text = text.strip()
        if not text:
            self.setHeader(game_id, "launcher")
            return
        texts = dict(self._settings.get("headerTexts"))
        texts[game_id] = text
        self._settings.set("headerTexts", texts)
        self.setHeader(game_id, "text")

    @Slot(str, str)
    def setHeaderImage(self, game_id, path):
        """Copy an image file in as this game's header (a copy, so moving the original is fine)."""
        dest = self._header_image_path(game_id)

        def work():
            from PIL import Image

            try:
                img = Image.open(path)
                img.load()
                img = img.convert("RGBA")
                img.thumbnail((1200, 600))
                dest.parent.mkdir(parents=True, exist_ok=True)
                img.save(dest)
                ok = True
            except (OSError, ValueError):
                ok = False
            self._headerImageDone.emit(game_id, ok)

        threading.Thread(target=work, daemon=True).start()

    def _header_image_done(self, game_id, ok):
        if not ok:
            self.headerImageFailed.emit("That file isn't an image Carthage can read. Try a PNG or JPEG.")
            return
        if self.image_provider:
            self.image_provider.clear()
        self.setHeader(game_id, "image")

    def _bump_headers(self):
        self._header_tick += 1

    @Property(int, notify=headersChanged)
    def headerTick(self):
        return self._header_tick

    NOT_GAMES = {"sh", "bash", "fish", "zsh", "env", "sleep", "cat", "grep", "python", "python3",
                 "steam", "steamwebhelper", "reaper", "pressure-vessel-wrap", "pv-bwrap", "bwrap",
                 "srt-bwrap", "pv-adverb", "wineserver", "services.exe", "winedevice.exe",
                 "plugplay.exe", "explorer.exe", "rpcss.exe", "svchost.exe", "tabtip.exe",
                 "conhost.exe", "start.exe", "xdg-open", "gio", "flatpak", "flatpak-portal",
                 "xdg-dbus-proxy", "systemd-run", "kioworker", "kdeconnectd"}

    @Slot(str, result="QVariantList")
    def processesSince(self, game_id):
        """Candidate game processes started since this game was launched (newest first)."""
        from . import launcher

        started = self._sessions.startedAt(game_id)
        if not started:
            return []
        seen, out = set(), []
        for pid, name, _started in sorted(launcher.Snapshot().started_since(started - 2), key=lambda x: -x[2]):
            low = name.lower()
            if low in self.NOT_GAMES or low in seen or low.startswith(("kworker", "carthage")):
                continue
            seen.add(low)
            out.append({"name": name, "pid": pid})
        return out[:30]

    @Slot(str, result=str)
    def relatedOf(self, game_id):
        return self._settings.get("related").get(game_id, "")

    @Slot(str, str)
    def setRelated(self, game_id, name):
        rel = dict(self._settings.get("related"))
        if name.strip():
            rel[game_id] = name.strip()
        else:
            rel.pop(game_id, None)
        self._settings.set("related", rel)
        self._sessions.set_related(rel)

    @Slot(str, bool)
    def setNoSlot(self, game_id, value):
        self._library.set_no_slot(game_id, value)
        if not self._fake:
            self._settings.set("noSlot", sorted(self._library.no_slot_ids))

    @Slot(str, result="QVariantMap")
    def gameInfo(self, game_id):
        """Everything the closer look shows about a game, by id (for stepping with ← →)."""
        from .library import SOURCES

        g = self._library.game(game_id)
        if g is None:
            return {}
        name, icon = SOURCES.get(g.source, SOURCES["other"])
        return {
            "gameId": g.game_id, "title": g.title, "source": g.source, "sourceName": name,
            "sourceIcon": icon, "code": g.code, "extId": g.ext_id, "installed": g.installed,
            "noSlot": g.no_slot, "lastPlayed": g.last_played, "playtime": g.playtime,
            "developer": g.developer, "publisher": g.publisher, "released": g.released,
        }

    @Slot(str, result=str)
    def titleOf(self, game_id):
        return self._library.title_for(game_id) or ""
