"""Games, the library model and the tray's search/filter/sort model.

`real_games()` reads every launcher (sources/). `fake_games()` is the invented demo
library used by `--fake` and scripted checks; each fake game has a `sim` behavior so
every dock state can be seen without real launches:

    normal    starts, runs, quits after ~1.5 s
    stubborn  ignores Quit, so "isn't responding" appears after 10 s
    crash     exits 2 s after starting
    handoff   hands off to another launcher (untracked → Eject Card)
"""

import os
import re
import time
from dataclasses import dataclass, field

from PySide6.QtCore import (
    Property,
    QAbstractListModel,
    QByteArray,
    QModelIndex,
    QSortFilterProxyModel,
    Qt,
    Signal,
    Slot,
)

# source key → (name on the cartridge, icon name)
SOURCES = {
    "steam": ("STEAM", "steam"),
    "heroic": ("HEROIC", "com.heroicgameslauncher.hgl"),
    "battlenet": ("BATTLE.NET", "applications-games"),
    "epic": ("EPIC GAMES", "applications-games"),
    "riot": ("RIOT", "applications-games"),
    "lutris": ("LUTRIS", "lutris"),
    "flatpak": ("FLATPAK", "applications-games"),
    "legendary": ("LEGENDARY", "applications-games"),
    "bottles": ("BOTTLES", "applications-games"),
    "itch": ("ITCH", "applications-games"),
    "retroarch": ("RETROARCH", "applications-games"),
    "desktop": ("PC", "applications-games"),
    "custom": ("CUSTOM", "applications-games"),
    "other": ("GAME", "applications-games"),
    "carthage": ("CARTHAGE", "applications-games"),
}

_ROMAN = {"ii": "2", "iii": "3", "iv": "4", "v": "5", "vi": "6", "vii": "7", "viii": "8", "ix": "9", "x": "10"}
_LEADING = {"the", "a", "an"}


def title_code(title):
    """Short cartridge code: 'Clair Obscur: Expedition 33' → 'CLOB:E33', 'Dead by Daylight' → 'DBD'."""
    parts = re.split(r"\s*(?::| - | – | — )\s*", title, maxsplit=1)

    def words(s):
        # "Garry's" is one word, not "Garry" + "s".
        return re.findall(r"[A-Za-z0-9]+", s.replace("'", "").replace("’", ""))

    def numbers(ws):
        return [w if w.isdigit() else _ROMAN[w.lower()] for w in ws if w.isdigit() or (w.lower() in _ROMAN and w.isupper())]

    def code_main(s):
        ws = words(s)
        nums = numbers(ws)
        ws = [w for w in ws if not (w.isdigit() or (w.lower() in _ROMAN and w.isupper()))]
        while len(ws) > 1 and ws[0].lower() in _LEADING:
            ws = ws[1:]
        if not ws:
            core = ""
        elif len(ws) == 1:
            core = ws[0][:4]
        elif len(ws) == 2:
            core = ws[0][:2] + ws[1][:2]
        else:
            core = "".join(w[0] for w in ws[:4])
        return (core + "".join(nums)).upper()

    def code_sub(s):
        ws = words(s)
        nums = numbers(ws)
        ws = [w for w in ws if not (w.isdigit() or (w.lower() in _ROMAN and w.isupper()))]
        return ("".join(w[0] for w in ws[:3]) + "".join(nums)).upper()

    code = code_main(parts[0])
    if len(parts) > 1 and parts[1]:
        code += ":" + code_sub(parts[1])
    return code[:10] or "GAME"


@dataclass
class Game:
    game_id: str
    title: str
    source: str
    ext_id: str
    installed: bool = True
    sim: str = "normal"
    no_slot: bool = False
    last_played: int = 0
    added: int = 0
    playtime: int = 0  # minutes
    executable: str = ""  # how to launch it: a URL (steam://, heroic://, lutris:) or a command
    install_dir: str = ""
    cover: str = ""  # a local cover image, if the launcher has one (Lutris)
    developer: str = ""
    publisher: str = ""
    released: int = 0  # unix time
    code: str = field(default="")

    def __post_init__(self):
        self.code = self.code or title_code(self.title)


_FAKE = [
    ("Starfall Odyssey", "steam", True, "normal"),
    ("Moss & Lantern", "steam", True, "normal"),
    ("Neon Drift II", "steam", False, "normal"),
    ("The Quiet Harbor", "steam", True, "normal"),
    ("Ironbound: Siege of Vael", "steam", True, "stubborn"),
    ("Pixel Parade", "steam", True, "normal"),
    ("Hollow Pines", "heroic", True, "handoff"),
    ("Tidebreaker", "lutris", True, "normal"),
    ("Garden Sprites", "flatpak", True, "normal"),
    ("Skyward Postman", "steam", True, "normal"),
    ("Dungeon Bakery", "steam", False, "normal"),
    ("Retro Racer DX", "steam", True, "normal"),
    ("Aurora Protocol", "steam", True, "crash"),
    ("Cozy Burrow", "steam", True, "normal"),
    ("Paper Knights", "heroic", True, "handoff"),
    ("Void Salvage", "steam", False, "normal"),
    ("Lighthouse Keeper", "steam", True, "normal"),
    ("Mech Tactics: Frontier", "epic", True, "normal"),
    ("Harvest Moonlight", "riot", True, "normal"),
    ("Frostbyte", "lutris", True, "normal"),
    ("Sunset Arcade", "steam", False, "normal"),
    ("Clockwork Fox", "steam", True, "normal"),
    ("Deep Sky Radio", "battlenet", True, "normal"),
    ("Lantern Launcher", "flatpak", True, "normal"),
]


TEST_CARTRIDGE_ID = "carthage_test"


def test_cartridge():
    """A pretend game: goes through insert → playing → quit → eject without launching
    anything (no executable, so sessions.py simulates it)."""
    return Game(game_id=TEST_CARTRIDGE_ID, title="Test Cartridge", source="carthage", ext_id="TEST01",
                sim="normal", last_played=int(time.time()), developer="Carthage", code="TEST")


# Launchers that couldn't be read on the last load ({"Steam": "the error"}): the UI says so.
source_errors = {}


def _read(name, fn):
    """One launcher's games; a failure is logged and remembered, never fatal for the rest."""
    import logging

    try:
        found = fn()
        logging.getLogger("carthage.library").info("%s: %d games", name, len(found))
        return found
    except Exception as e:  # noqa: BLE001 — any launcher's odd files must not empty the library
        logging.getLogger("carthage.library").exception("Couldn't read %s", name)
        source_errors[name] = f"{type(e).__name__}: {e}"
        return []


def real_games():
    """The user's actual library, read straight from each launcher's own files. Each launcher
    is read on its own, so one that fails doesn't hide the others."""
    from .sources import desktop, heroic, lutris, manual, steam

    source_errors.clear()
    games = []
    for g in _read("Steam", steam.load):
        games.append(Game(
            game_id=f"steam_{g['appid']}", title=g["name"], source="steam", ext_id=str(g["appid"]),
            installed=g["installed"], last_played=g["last_played"], playtime=g["playtime"],
            added=g["added"], install_dir=g["install_dir"],
            developer=g.get("developer", ""), publisher=g.get("publisher", ""), released=g.get("released", 0),
            executable=f"steam://rungameid/{g['appid']}",
        ))
    for g in _read("Heroic", heroic.load):
        games.append(Game(
            game_id=g["id"], title=g["name"], source="heroic", ext_id=g["short_id"],
            installed=g["installed"], executable=g["launch"], developer=g.get("developer", ""),
            install_dir=g.get("install_dir", ""),
        ))
    if os.name == "nt":
        from .sources import battlenet, epic, riot

        for label, source, module in (("Battle.net", "battlenet", battlenet), ("Epic Games", "epic", epic),
                                      ("Riot Client", "riot", riot)):
            for g in _read(label, module.load):
                games.append(Game(
                    game_id=g["id"], title=g["name"], source=source, ext_id=g["short_id"],
                    executable=g["launch"], install_dir=g["install_dir"],
                ))
    for g in _read("Lutris", lutris.load):
        games.append(Game(
            game_id=g["id"], title=g["name"], source="lutris", ext_id=g["short_id"],
            installed=g["installed"], last_played=g["last_played"], playtime=g["playtime"],
            added=g["added"], executable=g["launch"], cover=g["cover"],
            install_dir=g.get("install_dir", ""),
        ))
    for g in _read("installed apps", desktop.load):
        games.append(Game(
            game_id=g["id"], title=g["name"], source=g["source"], ext_id=g["short_id"],
            executable=g["launch"],
        ))
    for g in _read("added games", manual.load):
        games.append(Game(
            game_id=g["id"], title=g["name"], source="custom", ext_id=g["short_id"],
            added=g["added"], executable=g["launch"],
        ))
    return games


def fake_games():
    count = int(os.environ.get("GC_FAKE_COUNT", "0") or 0)
    now = int(time.time())
    games = []
    for i, (title, source, installed, sim) in enumerate(_FAKE):
        g = Game(
            game_id=f"fake{i}",
            title=title,
            source=source,
            ext_id=str(1_200_000 + i * 7919) if source == "steam" else title_code(title).lower(),
            installed=installed,
            sim=sim,
            last_played=now - i * 86_400 * 3 if installed else 0,
            added=now - (len(_FAKE) - i) * 86_400,
        )
        if title == "Lantern Launcher":
            g.no_slot = True
        games.append(g)
    # Stress test: GC_FAKE_COUNT=500 pads the library with generated titles.
    for i in range(len(games), count):
        games.append(Game(f"fake{i}", f"Test Game {i}", "steam", str(2_000_000 + i), installed=i % 5 != 0, added=now - i))
    return games


class GameModel(QAbstractListModel):
    ROLES = {
        Qt.UserRole + 1: b"gameId",
        Qt.UserRole + 2: b"title",
        Qt.UserRole + 3: b"source",
        Qt.UserRole + 4: b"sourceName",
        Qt.UserRole + 5: b"sourceIcon",
        Qt.UserRole + 6: b"code",
        Qt.UserRole + 7: b"extId",
        Qt.UserRole + 8: b"installed",
        Qt.UserRole + 9: b"noSlot",
        Qt.UserRole + 10: b"lastPlayed",
        Qt.UserRole + 11: b"added",
        Qt.UserRole + 12: b"hidden",
        Qt.UserRole + 13: b"playtime",
        Qt.UserRole + 14: b"developer",
        Qt.UserRole + 15: b"publisher",
        Qt.UserRole + 16: b"released",
    }
    ROLE_IDS = {name: role for role, name in ROLES.items()}
    _ATTRS = {b"gameId": "game_id", b"title": "title", b"source": "source", b"code": "code", b"extId": "ext_id",
              b"installed": "installed", b"noSlot": "no_slot", b"lastPlayed": "last_played", b"added": "added",
              b"playtime": "playtime", b"developer": "developer", b"publisher": "publisher", b"released": "released"}

    def __init__(self, games, parent=None):
        super().__init__(parent)
        self._hidden = set()
        self.no_slot_ids = {g.game_id for g in games if g.no_slot}
        self._index(games)

    title_overrides = {}
    play_log = None  # playtime.PlayLog (not for the demo library)

    def _index(self, games):
        self._games = games
        self._by_id = {g.game_id: g for g in games}
        self._rows = {g.game_id: row for row, g in enumerate(games)}

    def row_of(self, game_id):
        """The game's row here, or -1."""
        return self._rows.get(game_id, -1)

    def _apply_saved(self, g):
        self._apply_title(g)
        if self.play_log:
            self.play_log.apply(g)

    def _apply_title(self, g):
        new = self.title_overrides.get(g.game_id)
        if new:
            if not getattr(g, "original_title", None):
                g.original_title = g.title
            g.title = new
            g.code = title_code(new)
        elif getattr(g, "original_title", None):  # the override was dropped
            g.title = g.original_title
            g.code = title_code(g.title)

    def set_title_override(self, game_id, title):
        g = self._by_id.get(game_id)
        if g is None:
            return
        if title:
            self.title_overrides[game_id] = title
        else:
            self.title_overrides.pop(game_id, None)
        self._apply_title(g)
        idx = self.index(self._rows[game_id])
        self.dataChanged.emit(idx, idx)

    refreshed = Signal()

    def reset(self, games):
        """Swap in a freshly loaded library (keeps Carthage-side hidden/no-slot/name choices)."""
        for g in games:
            g.no_slot = g.game_id in self.no_slot_ids or g.no_slot
            self._apply_saved(g)
        if [g.game_id for g in games] == [g.game_id for g in self._games]:
            # Updated in place, so the views keep their scroll position and their cards.
            if games != self._games:
                self._index(games)
                self.dataChanged.emit(self.index(0), self.index(len(games) - 1))
                self.refreshed.emit()
            return
        self.beginResetModel()
        self._index(games)
        self.endResetModel()

    def rowCount(self, parent=QModelIndex()):
        return 0 if parent.isValid() else len(self._games)

    def roleNames(self):
        return {k: QByteArray(v) for k, v in self.ROLES.items()}

    def data(self, index, role=Qt.DisplayRole):
        if not index.isValid():
            return None
        g = self._games[index.row()]
        name = self.ROLES.get(role)
        if name is None:
            return g.title if role == Qt.DisplayRole else None
        if name == b"sourceName" or name == b"sourceIcon":
            return SOURCES.get(g.source, SOURCES["other"])[name == b"sourceIcon"]
        if name == b"hidden":
            return g.game_id in self._hidden
        return getattr(g, self._ATTRS[name])

    def game(self, game_id):
        return self._by_id.get(game_id)

    @staticmethod
    def source_name(source):
        return SOURCES.get(source, (source.upper(), ""))[0]

    def title_for(self, game_id):
        g = self._by_id.get(game_id)
        return g.title if g else None

    def _changed(self, game_id, role_name):
        row = self._rows.get(game_id)
        if row is not None:
            idx = self.index(row)
            self.dataChanged.emit(idx, idx, [self.ROLE_IDS[role_name]])

    def set_hidden(self, game_id, hidden):
        (self._hidden.add if hidden else self._hidden.discard)(game_id)
        self._changed(game_id, b"hidden")

    def restore(self, hidden, no_slot, titles=None):
        """Apply saved choices (settings.json)."""
        self._hidden = set(hidden)
        self.no_slot_ids = set(no_slot)
        self.title_overrides = dict(titles or {})
        for g in self._games:
            g.no_slot = g.game_id in self.no_slot_ids
            self._apply_saved(g)
        self.beginResetModel()
        self.endResetModel()

    def set_no_slot(self, game_id, value):
        (self.no_slot_ids.add if value else self.no_slot_ids.discard)(game_id)
        g = self._by_id.get(game_id)
        if g:
            g.no_slot = value
            self._changed(game_id, b"noSlot")

    def touch(self, game_id):
        # Deliberately no dataChanged: re-sorting now would move the card's recess while the
        # cartridge is out. The new order applies on the next sort or restart.
        g = self._by_id.get(game_id)
        if g:
            g.last_played = int(time.time())
            if self.play_log and self.play_log.counts(g):
                self.play_log.touch(g)

    def add_play(self, game_id, seconds):
        """A tracked session ended: count its time (games whose launcher doesn't)."""
        g = self._by_id.get(game_id)
        if g and self.play_log and self.play_log.counts(g):
            self.play_log.add(g, seconds)
            # Only these roles change, so the tray doesn't re-sort under a returning cartridge.
            self._changed(game_id, b"playtime")
            self._changed(game_id, b"lastPlayed")

    def set_playtime(self, game_id, minutes):
        g = self._by_id.get(game_id)
        if g and self.play_log and self.play_log.counts(g):
            self.play_log.set_total(g, minutes)
            self._changed(game_id, b"playtime")


def source_label(source):
    """A launcher's name for menus and lists ("battlenet" → "Battle.net")."""
    special = {"desktop": "Installed Apps", "custom": "Added by You", "battlenet": "Battle.net"}
    return special.get(source) or SOURCES.get(source, (source.upper(),))[0].title()


class TrayModel(QSortFilterProxyModel):
    """Search, filter and sort for the tray.

    A cartridge sits in one place: the favorites shelf or the tray. `part` says which this
    model holds: "tray" (everything but the favorites), "favorites" (only them) or "all".
    A favorites model given `mirror` (the tray's model) follows its search, filter and sort."""

    changed = Signal()

    def __init__(self, source, parent=None, part="tray", mirror=None):
        super().__init__(parent)
        self.setSourceModel(source)
        self._text = ""
        self._filter = "all"
        self._sort = "recent"
        self._part = part
        self._favorites = set()
        self._mirror = mirror
        self.setDynamicSortFilter(True)
        self.sort(0)
        for sig in (self.rowsInserted, self.rowsRemoved, self.modelReset, self.layoutChanged):
            sig.connect(self.changed)
        if mirror is not None:
            mirror.changed.connect(self._follow)

    def _follow(self):
        self.invalidate()
        self.sort(0)
        self.changed.emit()

    def set_favorites(self, ids):
        ids = set(ids)
        if ids != self._favorites:
            self._favorites = ids
            self.invalidateFilter()
            self.changed.emit()

    def _opts(self):
        """The search / filter / sort in effect (the mirrored model's, if any)."""
        return self._mirror if self._mirror is not None else self

    def _get_text(self):
        return self._text

    def _set_text(self, value):
        if value != self._text:
            self._text = value
            self.invalidateFilter()
            self.changed.emit()

    filterText = Property(str, _get_text, _set_text, notify=changed)

    def _get_filter(self):
        return self._filter

    def _set_filter(self, value):
        if value != self._filter:
            self._filter = value
            self.invalidateFilter()
            self.changed.emit()

    filterMode = Property(str, _get_filter, _set_filter, notify=changed)

    def _get_sort(self):
        return self._sort

    def _set_sort(self, value):
        if value != self._sort:
            self._sort = value
            self.invalidate()
            self.sort(0)
            self.changed.emit()

    sortMode = Property(str, _get_sort, _set_sort, notify=changed)

    @Property(int, notify=changed)
    def count(self):
        return self.rowCount()

    @Property("QVariantList", notify=changed)
    def launchers(self):
        """[{value: "source:<key>", text}] for every launcher with games (visible ones), for
        the Show menu — most games first."""
        m = self.sourceModel()
        counts = {}
        for g in m._games:
            if g.game_id not in m._hidden and g.source != "carthage":
                counts[g.source] = counts.get(g.source, 0) + 1
        return [{"value": "source:" + s, "text": source_label(s)}
                for s, _ in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))]

    def filterAcceptsRow(self, row, parent):
        m = self.sourceModel()
        g = m._games[row]
        if g.game_id in m._hidden:
            return False
        fav = g.game_id in self._favorites
        if (self._part == "tray" and fav) or (self._part == "favorites" and not fav):
            return False
        o = self._opts()
        if g.game_id == TEST_CARTRIDGE_ID:  # a test tool: shown whatever the filter
            return not o._text or o._text.casefold() in g.title.casefold()
        if o._filter == "installed" and not g.installed:
            return False
        if o._filter == "notinstalled" and g.installed:
            return False
        if o._filter.startswith("source:") and g.source != o._filter[7:]:
            return False
        return not o._text or o._text.casefold() in g.title.casefold()

    _installed_first = False

    def _get_installed_first(self):
        return self._installed_first

    def _set_installed_first(self, value):
        if value != self._installed_first:
            self._installed_first = value
            self.invalidate()
            self.sort(0)
            self.changed.emit()

    installedFirst = Property(bool, _get_installed_first, _set_installed_first, notify=changed)

    def lessThan(self, left, right):
        m = self.sourceModel()
        a, b = m._games[left.row()], m._games[right.row()]
        o = self._opts()
        if TEST_CARTRIDGE_ID in (a.game_id, b.game_id):  # the Test Cartridge comes first
            return a.game_id == TEST_CARTRIDGE_ID
        if o._installed_first and a.installed != b.installed:
            return a.installed
        if o._sort == "az":
            return a.title.casefold() < b.title.casefold()
        if o._sort == "launcher":  # grouped by launcher (by name), then by title
            la, lb = source_label(a.source).casefold(), source_label(b.source).casefold()
            if la != lb:
                return la < lb
            return a.title.casefold() < b.title.casefold()
        if o._sort == "added":
            return a.added > b.added
        if o._sort == "playtime":
            if a.playtime != b.playtime:
                return a.playtime > b.playtime
            return a.title.casefold() < b.title.casefold()
        if a.last_played != b.last_played:
            return a.last_played > b.last_played
        return a.title.casefold() < b.title.casefold()

    @Slot(int, result=str)
    def idAt(self, row):
        return self.data(self.index(row, 0), Qt.UserRole + 1) if 0 <= row < self.rowCount() else ""

    @Slot(str, result=int)
    def rowOf(self, game_id):
        m = self.sourceModel()
        row = m.row_of(game_id)
        return -1 if row < 0 else self.mapFromSource(m.index(row)).row()
