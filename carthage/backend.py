"""The single object QML talks to: models, settings, watchers and actions."""

import threading
from pathlib import Path

from PySide6.QtCore import Property, QObject, QTimer, QUrl, Signal, Slot

from .library import GameModel, TrayModel, real_games
from .sessions import SessionModel
from .settings import Settings
from .theme import Theme
from .version import VERSION
from .watchers import InstallWatch, LibraryWatcher

ASSETS = Path(__file__).resolve().parent / "assets"
# The feedback form (Google Forms, one "Feedback" paragraph field). The app posts to it;
# the viewform address is the fallback when that fails.
FEEDBACK_FORM = "https://docs.google.com/forms/d/e/1FAIpQLScqh7yiV38-ZCFqpeUK2DoVs00b-CDBFQp38aocNVy7UVhCjw"
FEEDBACK_FIELD = "entry.1609768458"


def _human(size):
    for unit in ("B", "KB", "MB", "GB"):
        if size < 1024 or unit == "GB":
            return f"{size:.0f} {unit}" if unit in ("B", "KB") else f"{size:.1f} {unit}"
        size /= 1024


class Backend(QObject):
    libraryError = Signal(str)
    feedbackSent = Signal(bool)  # ok
    playNextChanged = Signal()
    genresChanged = Signal()
    _genresReady = Signal("QVariantMap")  # worker → UI thread

    def __init__(self, games=None, parent=None):
        """`games`: a library to use instead of the real one (the test harness's demo library)."""
        super().__init__(parent)
        fake = games is not None
        self._fake = fake
        import os

        self._test_run = bool(os.environ.get("GC_DEMO")) and not fake
        self._theme = Theme(self)
        self._settings = Settings(self)
        games = games if fake else self._load_real()
        self._library = GameModel(games, self)
        self._tray = TrayModel(self._library, self)
        # The lists: their games stay in the tray too. Each follows the tray's search, filters
        # and order.
        self._play_next = TrayModel(self._library, self, part="list", mirror=self._tray)
        self._favorites_list = TrayModel(self._library, self, part="list", mirror=self._tray)
        # The open custom list (one model, filled with the list shown).
        self._custom_list = TrayModel(self._library, self, part="list", mirror=self._tray)
        self._shown_list = ""
        # The search page's library results: its own text and genres, not the tray's.
        self._search_library = TrayModel(self._library, self)
        self._play_next_store = []
        st = self._settings
        self._apply_favorites()
        self._apply_play_next()
        self._library.modelReset.connect(self._apply_play_next)  # a bought game becomes a library game
        self._genre_options = []
        self._top_genres = []
        self._genres_busy = False
        self._genresReady.connect(self._apply_genres)
        if not fake:
            self._library.modelReset.connect(self._load_genres)
            QTimer.singleShot(1500, self._load_genres)
        if not fake:
            from .playtime import PlayLog

            self._library.play_log = PlayLog()
            self._library.restore(st.get("hidden"), st.get("noSlot"), st.get("titles"))
            self._tray.sortMode = st.get("sortMode")
            self._tray.filterMode = st.get("filterMode")
            self._tray.changed.connect(self._save_tray)
        self._tray.installedFirst = st.get("installedFirst")
        st.changed.connect(lambda: setattr(self._tray, "installedFirst", st.get("installedFirst")))

        def apply_look():
            self._settle_mode()
            self._theme.look = st.get("look")
            self._theme.mode = st.get("themeMode")
            self._theme.groundColors = st.get("groundColors")
            self._theme.set_ground_tuning(st.get("groundTuning"))

        apply_look()
        st.changed.connect(apply_look)
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
        self._install = InstallWatch(self) if not fake else None
        from .store import Store

        self._store = Store(lambda: {int(g.ext_id) for g in self._library._games
                                     if g.source == "steam" and g.ext_id.isdigit()},
                            lambda: self._settings.get("hideAdult"), self,
                            other_stores=lambda: self._settings.get("otherStores"))
        self._store.playNextPrices.connect(self._play_next_prices)
        self._store.refreshPlayNext([e for e in self._settings.get("playNext") if isinstance(e, dict)])
        from .achievements import Achievements
        from .keys import Keys

        self._keys = Keys(self._steam_id64, self)
        self._achievements = Achievements(self._steam_id64, self)
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

    @staticmethod
    def _steam_id64():
        """The Steam account on this PC (from Steam's own files), or None."""
        from .sources import steam

        root = steam.find_root()
        return steam.steam_id64(root) if root else None

    def _settle_mode(self):
        """The mode is always chosen, dark or light: picking a colour must never change it.
        Settings from before the Mode switch (or after Reset) start in the mode their colour
        had, so nothing changes on the first start; from then on only the switch changes it."""
        st = self._settings
        if st.get("themeMode") not in ("dark", "light"):
            from .theme import EDITIONS, edition_of

            e = edition_of(st.get("hardware")) or "dark"
            st.set("themeMode", "dark" if EDITIONS[e]["isDark"] else "light")

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
        import os

        from . import chrome

        if os.environ.get("GC_DEMO") and os.environ.get("GC_MOTION"):  # test runs: 0 for still screenshots
            return float(os.environ["GC_MOTION"])

        return chrome.animation_factor()

    @Property(bool, constant=True)
    def testSilent(self):
        """Test runs (GC_DEMO) make no sound unless GC_SOUND=1: they run beside someone working."""
        import os

        return bool(os.environ.get("GC_DEMO")) and not os.environ.get("GC_SOUND")

    @Property(bool, constant=True)
    def testPlacedShow(self):
        """Test runs on a chosen screen (GC_SCREEN): the harness shows the window once it's
        there, so it never flashes up on the screen someone is using."""
        import os

        return bool(os.environ.get("GC_DEMO") and os.environ.get("GC_SCREEN"))

    @Property(bool, constant=True)
    def testNoFocus(self):
        """Test runs with GC_NOFOCUS: the window never takes the keyboard focus (so a test can
        run on another screen while someone uses this one)."""
        import os

        return bool(os.environ.get("GC_DEMO") and os.environ.get("GC_NOFOCUS"))

    @Property(bool, constant=True)
    def fake(self):
        return self._fake

    @property
    def library(self):
        return self._library

    @Property(QObject, constant=True)
    def theme(self):
        return self._theme

    @Slot(bool, result="QVariantMap")
    def chromeColors(self, dark):
        """The standard controls' fixed palette (chrome.py), for Main.qml to set on the window."""
        from . import chrome

        return chrome.colors(dark)

    @Property(QObject, constant=True)
    def settings(self):
        return self._settings

    @Property(QObject, constant=True)
    def games(self):
        return self._tray

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

    def _apply_favorites(self):
        self._favorites_list.set_list(self._settings.get("favorites"))

    # ── Genres: the store's categories for library games (genres.py) ────────────────────────

    def _load_genres(self):
        if self._genres_busy:
            return
        self._genres_busy = True
        games = [(g.game_id, g.source, g.ext_id, g.title) for g in self._library._games]

        def work():
            import logging

            from . import genres

            try:
                self._genresReady.emit(genres.lookup(games))
            except Exception:  # never let a lookup problem reach the UI
                logging.getLogger("carthage").exception("Genre lookup failed")
                self._genresReady.emit({})

        threading.Thread(target=work, daemon=True).start()

    def _apply_genres(self, result):
        self._genres_busy = False
        if not result:
            return
        for m in (self._tray, self._play_next, self._favorites_list, self._custom_list, self._search_library):
            m.set_genres(result)
        from .store import Store

        present = {t for tags in result.values() for t in tags}
        self._genre_options = [{"value": t, "text": n} for n, t in Store.CATEGORIES if t in present]
        counts = {}
        for tags in result.values():
            for t in tags:
                counts[t] = counts.get(t, 0) + 1
        names = {t: n for n, t in Store.CATEGORIES}
        self._top_genres = [{"value": t, "text": names[t], "count": c}
                            for t, c in sorted(counts.items(), key=lambda kv: -kv[1]) if t in names]
        self.genresChanged.emit()

    @Property("QVariantList", notify=genresChanged)
    def topGenres(self):
        """The library's genres, most games first: [{value: tag, text, count}]."""
        return self._top_genres

    @Property(QObject, constant=True)
    def searchLibrary(self):
        """The search page's library results (own text and genreList)."""
        return self._search_library

    @Property("QVariantList", notify=genresChanged)
    def genreOptions(self):
        """The genres the library's games have, in the store's order: [{value: tag, text}]."""
        return self._genre_options

    # ── Play Next: bookmarks from the library and the store ─────────────────────────────────

    def _steam_game_id(self, appid):
        """The library game for a Steam app id, if it's in the library."""
        appid = str(appid)
        for g in self._library._games:
            if g.source == "steam" and g.ext_id == appid:
                return g.game_id
        return None

    @staticmethod
    def _store_key(e):
        """A store entry's key: the store page's own ("steam:570", "epic:<slug>")."""
        return e.get("key") or ("steam:" + str(e.get("appid")) if e.get("appid") else "")

    def _apply_play_next(self):
        ids, store = [], []
        for e in self._settings.get("playNext"):
            if isinstance(e, str):
                ids.append(e)
            elif isinstance(e, dict) and self._store_key(e):
                gid = self._steam_game_id(e["appid"]) if e.get("appid") else None
                if gid:  # bought since: show the library cartridge
                    ids.append(gid)
                else:
                    store.append(dict(e, key=self._store_key(e)))
        self._play_next.set_list(ids)
        self._play_next_store = store
        self.playNextChanged.emit()

    @Property(QObject, constant=True)
    def achievements(self):
        """Steam achievements for the closer look (achievements.py)."""
        return self._achievements

    # ── Your own lists ──────────────────────────────────────────────────────────────────────
    listsChanged = Signal()

    def _lists(self):
        return [dict(x) for x in self._settings.get("lists") or []]

    def _save_lists(self, lists):
        self._settings.set("lists", lists)
        if self._shown_list:
            self.showList(self._shown_list)
        self.listsChanged.emit()

    @Property("QVariantList", notify=listsChanged)
    def lists(self):
        """[{id, name, count}] in the order they were made."""
        return [{"id": x["id"], "name": x["name"], "count": len(x.get("ids") or [])} for x in self._lists()]

    @Slot(str, result=str)
    def createList(self, name):
        import uuid

        name = name.strip()
        if not name:
            return ""
        lists = self._lists()
        lid = uuid.uuid4().hex[:8]
        lists.append({"id": lid, "name": name, "ids": []})
        self._save_lists(lists)
        return lid

    @Slot(str, str)
    def renameList(self, lid, name):
        lists = self._lists()
        for x in lists:
            if x["id"] == lid and name.strip():
                x["name"] = name.strip()
        self._save_lists(lists)

    @Slot(str)
    def deleteList(self, lid):
        self._save_lists([x for x in self._lists() if x["id"] != lid])

    @Slot(str, str, bool)
    def setInList(self, lid, game_id, on):
        lists = self._lists()
        for x in lists:
            if x["id"] == lid:
                ids = [g for g in x.get("ids") or [] if g != game_id]
                x["ids"] = ids + [game_id] if on else ids
        self._save_lists(lists)

    @Slot(str, str, result=bool)
    def inList(self, lid, game_id):
        return any(x["id"] == lid and game_id in (x.get("ids") or []) for x in self._lists())

    @Slot(str)
    def showList(self, lid):
        """Fills customList with this list's games."""
        self._shown_list = lid
        ids = next((x.get("ids") or [] for x in self._lists() if x["id"] == lid), [])
        self._custom_list.set_list(ids)

    @Property(QObject, constant=True)
    def customList(self):
        return self._custom_list

    @Slot(result=str)
    def steamId(self):
        """Your Steam ID (from Steam's own files), "" without Steam."""
        return str(self._steam_id64() or "")

    @Property(QObject, constant=True)
    def favoritesList(self):
        """Every favorite, in the order added, without taking them off the tray (the sidebar's list)."""
        return self._favorites_list

    @Property(QObject, constant=True)
    def playNext(self):
        """The Play Next shelf's library games, in the order they were added."""
        return self._play_next

    @Property("QVariantList", notify=playNextChanged)
    def playNextStore(self):
        """The Play Next shelf's store games that aren't in the library: each remembers the
        store it was bookmarked on (store, offers[0]) and its last known price."""
        return self._play_next_store

    def _set_play_next(self, entries):
        self._settings.set("playNext", entries)
        self._apply_play_next()

    @Slot(str, result=bool)
    def isPlayNext(self, game_id):
        return game_id in self._settings.get("playNext")

    @Slot(str, bool)
    def setPlayNext(self, game_id, on):
        entries = [e for e in self._settings.get("playNext") if e != game_id]
        if on:
            entries.append(game_id)
        self._set_play_next(entries)

    @Slot(str, int, result=bool)
    def isPlayNextStore(self, key, appid):
        """Is this store game (store page key, Steam app id or 0) on Play Next?"""
        gid = self._steam_game_id(appid) if appid else None
        if gid:
            return self.isPlayNext(gid)
        return any(isinstance(e, dict) and self._store_key(e) == key for e in self._settings.get("playNext"))

    @Slot("QVariantMap", bool)
    def setPlayNextStore(self, item, on):
        """A store game on or off Play Next, remembering the store it's shown on (`store`, and
        that store's offer first in `offers`). One that's in the library is saved as that game."""
        key = self._store_key(item)
        if not key:
            return
        gid = self._steam_game_id(item["appid"]) if item.get("appid") else None
        if gid:
            self.setPlayNext(gid, on)
            return
        entries = [e for e in self._settings.get("playNext") if not (isinstance(e, dict) and self._store_key(e) == key)]
        if on:
            entries.append({k: item.get(k) for k in ("key", "store", "appid", "name", "capsule", "header",
                                                      "price", "original", "discount", "offers") if item.get(k) is not None})
            self._store.refreshPlayNext([entries[-1]])
        self._set_play_next(entries)

    def _play_next_prices(self, prices):
        """Fresh prices for store entries ({key: {price, original, discount}}), kept for next time."""
        entries = []
        for e in self._settings.get("playNext"):
            if isinstance(e, dict) and self._store_key(e) in prices:
                e = dict(e, **prices[self._store_key(e)])
            entries.append(e)
        self._set_play_next(entries)

    @Slot(str, str)
    def setGameColor(self, game_id, value):
        """One game's own cartridge color ("" = back to the usual one)."""
        colors = dict(self._settings.get("gameColors"))
        if value:
            colors[game_id] = value
        else:
            colors.pop(game_id, None)
        self._settings.set("gameColors", colors)

    @Slot(str, result=bool)
    def isFavorite(self, game_id):
        return game_id in self._settings.get("favorites")

    @Slot(str, bool)
    def setFavorite(self, game_id, on):
        """Into Favorites (on) or out of it."""
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

    @Slot(str, bool, bool)
    def setPresence(self, screen, game_running, active=True):
        """Which screen is open, for Discord ("library" / "store"); cleared while a game runs
        or while the window isn't the active one."""
        self._presence.set(screen, game_running, active)

    @Property(QObject, constant=True)
    def keys(self):
        return self._keys

    @staticmethod
    def _feedback_text(text, email):
        """What's sent: the text, then Carthage's version and the operating system, and the
        address to answer, if one was given (the form has a single field)."""
        import platform

        out = f"{text.strip()}\n\n— Carthage {VERSION}, {platform.system()}"
        return out + f"\n— Reply to: {email.strip()}" if email.strip() else out

    @Slot(str, str)
    def sendFeedback(self, text, email):
        """Post the text to the feedback form in the background; feedbackSent says how it went."""
        import os
        import urllib.parse
        import urllib.request

        if os.environ.get("GC_DEMO"):  # test runs never send anything
            QTimer.singleShot(300, lambda: self.feedbackSent.emit(True))
            return
        data = urllib.parse.urlencode({FEEDBACK_FIELD: self._feedback_text(text, email)}).encode()

        def work():
            ok = False
            try:
                req = urllib.request.Request(FEEDBACK_FORM + "/formResponse", data=data,
                                             headers={"User-Agent": f"Carthage/{VERSION}"})
                with urllib.request.urlopen(req, timeout=15) as r:
                    ok = 200 <= r.status < 300
            except (OSError, ValueError):
                pass
            self.feedbackSent.emit(ok)

        threading.Thread(target=work, daemon=True).start()

    @Slot(str, str, result=str)
    def feedbackFormUrl(self, text, email):
        """The form in a browser, already filled in with the text."""
        import urllib.parse

        return FEEDBACK_FORM + "/viewform?usp=pp_url&" + urllib.parse.urlencode({FEEDBACK_FIELD: self._feedback_text(text, email)})

    @Slot(str)
    def openUrl(self, url):
        from PySide6.QtGui import QDesktopServices

        QDesktopServices.openUrl(QUrl(url))

    @Property(QObject, constant=True)
    def sessions(self):
        return self._sessions

    @Slot(str, result=QUrl)
    def soundUrl(self, name):
        return QUrl.fromLocalFile(str(ASSETS / "sounds" / f"{name}.wav"))

    @Slot(str, result=str)
    def launch(self, game_id):
        """Returns what the UI should show:
        slot | noslot | running | install (handed to Steam) | install-elsewhere | missing |
        notfound:<path> (its program isn't there any more)."""
        from . import launcher

        g = self._library.game(game_id)
        if g is None:
            return "missing"
        from .library import TEST_CARTRIDGE_ID

        # (Only looks at the disk, so test runs check it too.)
        gone = launcher.missing_program(g) if g.installed and g.executable and not self._fake else ""
        if gone and self._sessions.indexOf(game_id) < 0:
            import logging

            logging.getLogger("carthage").warning("%s: its program is missing (%s)", g.title, gone)
            return "notfound:" + gone
        if self._test_run and game_id != TEST_CARTRIDGE_ID:
            # A scripted test (GC_DEMO) on the real library never starts anything, whatever
            # gets clicked. The Test Cartridge launches nothing, so it may run.
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
        notes = notes_for(VERSION)
        return notes if notes and notes["slides"] else {}

    @Slot(result="QVariantMap")
    def whatsNewNotes(self):
        """This version's notes, always (Menu → What's new, and the test harness). Its fixes
        come as one last "Fixes" step, so a fix-only version still has something to show."""
        from .whatsnew import notes_for

        notes = notes_for(VERSION)
        if not notes:
            return {}
        if notes["fixed"]:
            notes["slides"].append({"kind": "fixed", "icon": "tools", "title": "Fixes",
                                    "text": "\n".join("• " + t for t in notes["fixed"])})
        return notes

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
        return [{"name": source_label(s), "source": s, "count": n} for s, n in sorted(counts.items(), key=lambda kv: -kv[1])]

    @Slot(result=bool)
    def copyDiagnostics(self):
        """Settings → System → Copy Diagnostics: the report for a bug report, on the clipboard."""
        import logging

        from . import diagnostics

        try:
            diagnostics.copy(self)
            return True
        except Exception:  # noqa: BLE001 — a broken report must not break the app; say so instead
            logging.getLogger("carthage").exception("Couldn't build the diagnostics")
            return False

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
        from .chrome import CONFIG_HOME

        safe = "".join(c if c.isalnum() or c in "-_" else "_" for c in game_id)
        return CONFIG_HOME / "carthage" / "headers" / (safe + ".png")

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
            "family": g.family,  # lent by the Steam Family, not on your own account
        }

    @Slot(str, result=str)
    def titleOf(self, game_id):
        return self._library.title_for(game_id) or ""
