"""Running games, one row per filled dock slot.

Real games are started and watched through launcher.py; a background poll (never on
the UI thread) finds each game's processes. Games in the invented demo library (they
have a `sim` behavior and no executable) are simulated with timers instead, so the
scripted visual checks keep working.

A session ends in two steps so the dock can animate: `ending(gameId, reason)` fires,
the row stays (state "ended") until QML calls `release(gameId)`, and only then is it
removed. A fallback timer releases it anyway if the UI never does.

States: starting → running → closing (→ notresponding) → ended
        handoff      (given to another launcher; untracked — Eject only)
        unconfirmed  (never saw it start; Eject or keep waiting)
"""

import threading
import time

from PySide6.QtCore import (
    Property,
    QAbstractListModel,
    QByteArray,
    QModelIndex,
    QObject,
    Qt,
    QTimer,
    Signal,
    Slot,
)

from . import launcher

LAUNCHER_NAMES = {"heroic": "Heroic", "lutris": "Lutris", "battlenet": "Battle.net", "epic": "Epic Games",
                  "riot": "Riot Client"}
NOT_RESPONDING_AFTER = 10_000  # ms after Quit
DETECT_EVERY = 3  # look for games started outside Carthage every 3rd poll (~3 s)
GENERIC_PROGRAMS = {"sh", "bash", "zsh", "fish", "env", "python", "python3", "wine", "wine64", "proton",
                    "steam", "heroic", "lutris", "legendary", "gamemoderun", "mangohud", "flatpak",
                    "xdg-open", "gio", "systemd-run", "cmd", "powershell", "start", "java", "mono", "dotnet"}
CRASH_WINDOW = 5.0  # s: exiting this soon after starting counts as "closed right after starting"


def _start_timeout(handle, steam_was_running):
    k = handle["kind"]
    if k == "steam":
        return 60 if steam_was_running else 150  # a cold Steam start can take a while
    if k == "flatpak":
        return 45
    if k == "folder":
        return 120  # Windows: Battle.net may have to start (and update) before the game does
    return 2  # scope: the process exists almost immediately


class Session(QObject):
    def __init__(self, game, parent=None):
        super().__init__(parent)
        self.game = game
        self.state = "starting"
        self.started = time.time()  # when it was launched; reset when it's seen running
        self.launched = self.started
        self.handle = None  # launcher handle; None for simulated games
        self.pids = set()
        self.steam_cold = False
        self.timers = []

    @property
    def simulated(self):
        return self.handle is None

    def later(self, ms, fn):
        t = QTimer(self)
        t.setSingleShot(True)
        t.timeout.connect(fn)
        t.start(ms)
        self.timers.append(t)

    def cancel_timers(self):
        for t in self.timers:
            t.stop()
        self.timers.clear()


class SessionModel(QAbstractListModel):
    ROLES = {
        Qt.UserRole + 1: b"gameId",
        Qt.UserRole + 2: b"title",
        Qt.UserRole + 3: b"state",
        Qt.UserRole + 4: b"statusText",
        Qt.UserRole + 5: b"led",
        Qt.UserRole + 6: b"source",
        Qt.UserRole + 7: b"sourceName",
        Qt.UserRole + 8: b"sourceIcon",
        Qt.UserRole + 9: b"code",
        Qt.UserRole + 10: b"extId",
        Qt.UserRole + 11: b"tracked",
    }

    countChanged = Signal()
    ending = Signal(str, str)  # gameId, reason: quit | killed | crashed | ejected | exited
    stateChanged = Signal(str, str)  # gameId, new state
    frozen = False  # scripted test on the real library: never quit or kill anything
    played = Signal(str, float)  # gameId, seconds it was seen running (real games only)
    _polled = Signal(object)  # worker → UI thread

    def __init__(self, games, real=True, parent=None):
        super().__init__(parent)
        self._games = games  # GameModel, for titles, sources and external detection
        self._rows = []
        self._related = {}  # game_id → process name the game really runs as
        self._real = real
        tick = QTimer(self)
        tick.timeout.connect(self._refresh_times)
        tick.start(30_000)
        if real:
            self._busy = False
            self._polled.connect(self._apply_poll)
            self._poll_timer = QTimer(self)
            self._poll_timer.timeout.connect(self._poll)
            self._poll_timer.start(1000)
            QTimer.singleShot(0, self._recover)

    def rowCount(self, parent=QModelIndex()):
        return 0 if parent.isValid() else len(self._rows)

    def roleNames(self):
        return {k: QByteArray(v) for k, v in self.ROLES.items()}

    def data(self, index, role=Qt.DisplayRole):
        if not index.isValid():
            return None
        s = self._rows[index.row()]
        g = s.game
        name = self.ROLES.get(role, b"").decode()
        if name == "gameId":
            return g.game_id
        if name == "title":
            return g.title
        if name == "state":
            return s.state
        if name == "statusText":
            return self._status(s)
        if name == "led":
            return {"running": "green", "handoff": "green", "ended": "off"}.get(s.state, "amber")
        if name == "source":
            return g.source
        if name in ("sourceName", "sourceIcon"):
            from .library import SOURCES

            return SOURCES.get(g.source, SOURCES["other"])[0 if name == "sourceName" else 1]
        if name == "code":
            return g.code
        if name == "extId":
            return g.ext_id
        if name == "tracked":
            return s.state not in ("handoff", "unconfirmed")
        return None

    @Property(int, notify=countChanged)
    def count(self):
        return len(self._rows)

    def _status(self, s):
        if s.state == "starting":
            return "Starting Steam…" if s.steam_cold else "Starting…"
        if s.state == "running":
            mins = int((time.time() - s.started) // 60)
            return "Playing · just started" if mins < 1 else f"Playing · {mins} min"
        if s.state == "handoff":
            return f"Launched via {LAUNCHER_NAMES.get(s.game.source, 'another launcher')}"
        if s.state == "unconfirmed":
            return "Couldn't confirm it started"
        if s.state == "closing":
            return "Closing…"
        if s.state == "notresponding":
            return "Isn't responding"
        return ""

    def _row(self, game_id):
        for i, s in enumerate(self._rows):
            if s.game.game_id == game_id:
                return i, s
        return -1, None

    def _set_state(self, game_id, state):
        i, s = self._row(game_id)
        if s is None or s.state == state:
            return
        s.state = state
        idx = self.index(i)
        self.dataChanged.emit(idx, idx)
        self.stateChanged.emit(game_id, state)

    def _refresh_times(self):
        if self._rows:
            self.dataChanged.emit(self.index(0), self.index(len(self._rows) - 1))

    def _add(self, game, state="starting"):
        s = Session(game, self)
        s.state = state
        n = len(self._rows)
        self.beginInsertRows(QModelIndex(), n, n)
        self._rows.append(s)
        self.endInsertRows()
        self.countChanged.emit()
        return s

    def set_related(self, related):
        self._related = dict(related)

    @Slot(str, result=float)
    def startedAt(self, game_id):
        s = self._row(game_id)[1]
        return s.launched if s else 0.0

    @Slot(str, result=int)
    def indexOf(self, game_id):
        return self._row(game_id)[0]

    def launch(self, game):
        """Start a game in a slot. Returns False if it already has one."""
        if self._row(game.game_id)[1]:
            return False
        s = self._add(game)
        if game.executable and self._real and game.source != "carthage":
            s.steam_cold = launcher.kind_of(game.executable) == "steam" and not launcher.Snapshot().running("steam")
            s.handle = launcher.launch(game)
            if s.handle["kind"] == "handoff":
                s.later(900, lambda: self._set_state(game.game_id, "handoff"))
        else:
            self._simulate_start(s)
        return True

    @Slot(str)
    def quit(self, game_id):
        if self.frozen:
            return
        i, s = self._row(game_id)
        if not s or s.state not in ("running", "starting", "notresponding", "unconfirmed"):
            return
        s.cancel_timers()
        self._set_state(game_id, "closing")
        if s.simulated:
            self._simulate_quit(s)
            return
        handle, pids = s.handle, set(s.pids)

        def work():
            # Politely: close its windows, like pressing their ✕. No windows → SIGTERM.
            if launcher.Windows().close(pids) == 0:
                launcher.terminate(handle, pids)

        threading.Thread(target=work, daemon=True).start()
        s.later(NOT_RESPONDING_AFTER, lambda: self._set_state(game_id, "notresponding"))

    @Slot(str)
    def keepWaiting(self, game_id):
        i, s = self._row(game_id)
        if s and s.state == "notresponding":
            self._set_state(game_id, "closing")
            s.later(NOT_RESPONDING_AFTER, lambda: self._set_state(game_id, "notresponding"))

    @Slot(str)
    def forceQuit(self, game_id):
        if self.frozen:
            return
        i, s = self._row(game_id)
        if not s:
            return
        s.cancel_timers()
        self._set_state(game_id, "closing")
        if s.simulated:
            s.later(400, lambda: self._end(game_id, "killed"))
            return
        s.forced = True
        handle, pids = s.handle, set(s.pids)
        threading.Thread(target=lambda: launcher.kill(handle, pids), daemon=True).start()

    @Slot(str)
    def eject(self, game_id):
        """For untracked games: return the cartridge without touching the game."""
        self._end(game_id, "ejected")

    @Slot(str, result=bool)
    def switchTo(self, game_id):
        i, s = self._row(game_id)
        if not s or not s.pids:
            return False
        pids = set(s.pids)
        threading.Thread(target=lambda: launcher.Windows().activate(pids), daemon=True).start()
        return True

    @Slot(str, result=bool)
    def canSwitch(self, game_id):
        i, s = self._row(game_id)
        return bool(s and s.pids and s.state in ("running", "closing", "notresponding"))

    def _end(self, game_id, reason):
        i, s = self._row(game_id)
        if not s or s.state == "ended":
            return
        s.cancel_timers()
        if reason == "crashed" and time.time() - s.started > CRASH_WINDOW + 0.5:
            reason = "exited"
        if s.handle and s.handle.get("kind") == "scope":
            launcher.forget_scope(s.handle["unit"])
        if not s.simulated and s.state in ("running", "closing", "notresponding"):
            self.played.emit(game_id, time.time() - s.started)
        self._set_state(game_id, "ended")
        self.ending.emit(game_id, reason)
        s.later(3000, lambda: self.release(game_id))

    @Slot(str)
    def release(self, game_id):
        i, s = self._row(game_id)
        if s is None:
            return
        s.cancel_timers()
        self.beginRemoveRows(QModelIndex(), i, i)
        self._rows.pop(i)
        self.endRemoveRows()
        self.countChanged.emit()
        s.deleteLater()

    def _recover(self):
        """Carthage restarted while games were running: put them straight in the dock."""
        for unit, gid in launcher.live_scopes().items():
            g = self._games.game(gid)
            if g and not self._row(gid)[1]:
                s = self._add(g, "running")
                s.handle = {"kind": "scope", "unit": unit}
        self._poll()

    def _poll(self):
        if self._busy:
            return
        self._busy = True
        jobs = [(s.game.game_id, s.handle, self._related.get(s.game.game_id, ""))
                for s in self._rows if s.handle and s.state != "ended"]
        self._polls = getattr(self, "_polls", 0) + 1
        cands = self._detect_candidates() if self._polls % DETECT_EVERY == 1 else []
        need_flatpak = any(h["kind"] == "flatpak" for _, h, _r in jobs) or any(h["kind"] == "flatpak" for _, h in cands)

        def work():
            try:
                snap = launcher.Snapshot()
                flatpaks = launcher.flatpak_instances() if need_flatpak else {}
                # A game's processes: what its launch started, plus its "related process"
                # (the real game a launcher starts, which may live outside the launch's tree).
                related = {gid: snap.matching([rel]) for gid, h, rel in jobs}
                pids = {gid: launcher.pids_for(h, snap, flatpaks) | related[gid] for gid, h, rel in jobs}
                detected = {gid: h for gid, h in cands if launcher.pids_for(h, snap, flatpaks)}
                self._polled.emit({"pids": pids, "related": {g: bool(r) for g, r in related.items()},
                                   "steam": snap.steam_games(), "detected": detected})
            except Exception:
                try:
                    self._polled.emit(None)
                except RuntimeError:
                    pass  # the app is shutting down

        threading.Thread(target=work, daemon=True).start()

    @Slot(object)
    def _apply_poll(self, result):
        self._busy = False
        if not result:
            return
        now = time.time()
        for gid, pids in result["pids"].items():
            i, s = self._row(gid)
            if s is None or s.state == "ended":
                continue
            s.pids = pids
            related = self._related.get(gid)
            if related and pids and result["related"].get(gid):
                s.saw_related = True
            if s.state in ("starting", "unconfirmed", "handoff"):
                if pids and (s.state != "handoff" or result["related"].get(gid)):
                    s.started = now
                    self._set_state(gid, "running")
                elif s.state == "starting" and now - s.started > _start_timeout(s.handle, not s.steam_cold):
                    if s.handle["kind"] in ("scope", "proc") and not related:
                        self._end(gid, "crashed")
                    else:
                        self._set_state(gid, "unconfirmed")
            elif s.state == "running" and not pids:
                if related and not getattr(s, "saw_related", False) and now - s.launched < 180:
                    # The launcher closed before the game started: keep waiting for the game.
                    self._set_state(gid, "starting")
                else:
                    self._end(gid, "crashed")
            elif s.state in ("closing", "notresponding") and not pids:
                self._end(gid, "killed" if getattr(s, "forced", False) else "quit")

        for appid in result["steam"]:
            gid = f"steam_{appid}"
            if self._row(gid)[1]:
                continue
            g = self._games.game(gid)
            if g is None:
                continue
            s = self._add(g, "running")
            s.handle = {"kind": "steam", "appid": appid}

        for gid, handle in (result.get("detected") or {}).items():
            if self._row(gid)[1]:
                continue
            g = self._games.game(gid)
            if g is not None:
                s = self._add(g, "running")
                s.handle = handle

    def _detect_candidates(self):
        """[(gameId, handle)] for games that can be recognized while running without Carthage
        having started them: by install folder (Heroic, Lutris, Battle.net…), by Flatpak id,
        by the program name of a native command, or by the linked "related" process. Steam
        games are recognized separately (snap.steam_games). "Launch Without Slot" games are
        left alone: they're not meant to be docked."""
        import os
        import shlex

        out = []
        for g in self._games._games:
            if self._row(g.game_id)[1] or not g.installed or g.no_slot or g.source in ("steam", "carthage"):
                continue
            exe = g.executable or ""
            rel = self._related.get(g.game_id, "")
            if rel:
                out.append((g.game_id, {"kind": "names", "names": [rel]}))
            elif g.install_dir and len(os.path.normpath(g.install_dir).split(os.sep)) >= 3 and os.path.isdir(g.install_dir):
                out.append((g.game_id, {"kind": "folder", "dir": launcher.folder_key(g.install_dir)}))
            elif exe.startswith("flatpak run ") and len(exe.split()) > 2:
                out.append((g.game_id, {"kind": "flatpak", "app": exe.split()[2]}))
            elif g.source in ("custom", "desktop") and "://" not in exe and exe:
                try:
                    program = shlex.split(exe, posix=os.name != "nt")[0]
                except ValueError:
                    continue
                name = program.replace("\\", "/").rsplit("/", 1)[-1].strip('"')
                bare = name.lower().removesuffix(".exe")
                if len(bare) >= 3 and bare not in GENERIC_PROGRAMS:
                    out.append((g.game_id, {"kind": "names", "names": [name]}))
        return out

    def _simulate_start(self, s):
        gid = s.game.game_id

        def started():
            if s.game.sim == "crash":
                self._set_state(gid, "running")
                s.later(2000, lambda: self._end(gid, "crashed"))
            elif s.game.sim == "handoff":
                self._set_state(gid, "handoff")
            else:
                s.started = time.time()
                self._set_state(gid, "running")

        s.later(1400, started)

    def _simulate_quit(self, s):
        gid = s.game.game_id
        if s.game.sim == "stubborn":
            s.later(10_000, lambda: self._set_state(gid, "notresponding"))
        else:
            s.later(1500, lambda: self._end(gid, "quit"))
