"""Starting, watching and stopping games on Windows. Same functions as launcher_linux.py.

Launch kinds, from the game's executable:
  steam     steam://rungameid/<id>  → Steam writes the running game's id to the registry
                                      (RunningAppID); the game is the process running from
                                      steamapps\\common and everything it started
  folder    Battle.net games → "<Game> Launcher.exe --productcode=…" hands the launch to
                                      Battle.net; the game is what runs from its install folder
  handoff   heroic://… and other launcher links → given to that launcher; untracked
  proc      any other command → started here; its process tree is the game

Quit asks the game's windows to close (WM_CLOSE, like pressing their ✕); a hard kill only
happens on Force Quit. Needs psutil (bundled with the Windows build).
"""

import ctypes
import os
import subprocess
import time
from ctypes import wintypes

import psutil

from .sources import steam as _steam

_user32 = ctypes.WinDLL("user32", use_last_error=True)
WM_CLOSE = 0x0010


def kind_of(executable):
    if executable.startswith("steam://rungameid/"):
        return "steam"
    if "://" in executable.split(" ", 1)[0] or executable.startswith("lutris:"):
        return "handoff"
    return "proc"


def steam_appid(executable):
    return executable.rsplit("/", 1)[-1]


def clean_exec(exec_line):
    return exec_line.strip()


def progname(argv):
    if not argv or not argv[0]:
        return ""
    a0 = argv[0].decode(errors="replace") if isinstance(argv[0], bytes) else argv[0]
    return a0.replace("\\", "/").rsplit("/", 1)[-1]


_install_dirs = {}


def _install_dir(appid):
    """steamapps\\common\\<installdir>\\ for a Steam app, lowercased (as Snapshot.exe is); "" if unknown."""
    if appid not in _install_dirs:
        from . import vdf

        root = _steam.find_root()
        found = ""
        for lib in _steam.library_paths(root) if root else []:
            acf = lib / "steamapps" / f"appmanifest_{appid}.acf"
            try:
                name = vdf.load(acf).get("appstate", {}).get("installdir", "")
            except OSError:
                continue
            if name:
                found = _folder_key(str(lib / "steamapps" / "common" / name))
                break
        if not found:
            return ""  # not cached: it may be mid-install, so look again next time
        _install_dirs[appid] = found
    return _install_dirs[appid]


class Snapshot:
    """One pass over the running processes: parent links, names and command lines."""

    def __init__(self):
        self.parent, self.children, self.cmd, self.name, self.exe, self.started = {}, {}, {}, {}, {}, {}
        for p in psutil.process_iter(["pid", "ppid", "name", "exe", "cmdline", "create_time"]):
            i = p.info
            pid = i["pid"]
            self.parent[pid] = i["ppid"] or 0
            self.children.setdefault(i["ppid"] or 0, []).append(pid)
            self.cmd[pid] = [a.encode() for a in (i["cmdline"] or [i["name"] or ""])]
            self.name[pid] = (i["name"] or "").lower()
            self.exe[pid] = (i["exe"] or "").lower()
            self.started[pid] = i["create_time"] or 0

    def tree(self, roots):
        found, pending = set(), list(roots)
        while pending:
            pid = pending.pop()
            if pid in found or pid not in self.parent:
                continue
            found.add(pid)
            pending.extend(self.children.get(pid, []))
        return found

    @staticmethod
    def _bare(n):
        n = n.lower()
        return n[:-4] if n.endswith(".exe") else n

    def matching(self, names):
        wanted = {self._bare(n) for n in names if n}
        return self.tree([pid for pid, n in self.name.items() if self._bare(n) in wanted]) if wanted else set()

    def started_since(self, since, uid=None):
        return [(pid, self.name[pid], t) for pid, t in self.started.items() if t >= since and self.name.get(pid)]

    def steam_games(self):
        """{appid: pid} for the Steam game running now (Steam runs one at a time)."""
        appid = _steam.running_appid_windows()
        if not appid:
            return {}
        # The game's own process: the oldest one running from that game's install folder —
        # not just any steamapps\common one (Wallpaper Engine and other tools live there too).
        folder = _install_dir(appid)
        if not folder:
            return {}
        games = sorted((t, pid) for pid, t in self.started.items() if self.exe.get(pid, "").startswith(folder))
        return {str(appid): games[0][1]} if games else {}

    def in_folder(self, folder):
        """Processes running from a game's folder (and what they started), minus the
        "<Game> Launcher.exe" stub, which only hands the launch to Battle.net."""
        roots = [pid for pid, exe in self.exe.items()
                 if exe.startswith(folder) and not self.name.get(pid, "").endswith(" launcher.exe")]
        return self.tree(roots)

    def running(self, name):
        n = self._bare(name)
        return any(self._bare(x) == n for x in self.name.values())


def flatpak_instances():
    return {}


def live_scopes():
    return {}


def forget_scope(unit):
    pass


def _folder_key(path):
    return os.path.join(os.path.normpath(path), "").lower()


def folder_key(path):
    """A game folder in the form in_folder() compares against (lowercase, ending in "\\")."""
    return _folder_key(path)


def launch(game):
    exe = game.executable
    kind = kind_of(exe)
    if game.source in ("battlenet", "epic", "riot") and game.install_dir:
        # Each hands the launch to its own client (Battle.net's "<Game> Launcher.exe" stub,
        # Epic's com.epicgames.launcher:// link, RiotClientServices.exe --launch-product);
        # the game itself then runs from its install folder, which is what gets tracked.
        if kind_of(exe) == "handoff":  # a link (Epic's)
            os.startfile(exe)
        else:
            subprocess.Popen(exe, cwd=game.install_dir,
                             creationflags=subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.DETACHED_PROCESS)
        return {"kind": "folder", "dir": _folder_key(game.install_dir)}
    if kind == "steam":
        os.startfile(exe)
        return {"kind": "steam", "appid": steam_appid(exe)}
    if kind == "handoff":
        os.startfile(exe)
        return {"kind": "handoff"}
    p = subprocess.Popen(exe, shell=True, cwd=str(os.path.expanduser("~")),
                         creationflags=subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.DETACHED_PROCESS)
    return {"kind": "proc", "pid": p.pid, "t": time.time()}


def install(game):
    if game.source == "steam":
        os.startfile(f"steam://install/{game.ext_id}")
        return True
    return False


def pids_for(handle, snap, flatpaks=None):
    k = handle["kind"]
    if k == "steam":
        root = snap.steam_games().get(handle["appid"])
        return snap.tree([root]) if root else set()
    if k == "proc":
        return snap.tree([handle["pid"]]) if handle["pid"] in snap.parent else set()
    if k == "folder":
        return snap.in_folder(handle["dir"])
    if k == "names":
        return snap.matching(handle["names"])
    return set()


_EnumProc = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)


def _windows_of(pids):
    out = []

    def cb(hwnd, _):
        if _user32.IsWindowVisible(hwnd):
            pid = wintypes.DWORD()
            _user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
            if pid.value in pids:
                out.append(hwnd)
        return True

    _user32.EnumWindows(_EnumProc(cb), 0)
    return out


class Windows:
    """Close or raise a game's windows."""

    def close(self, pids):
        wins = _windows_of(set(pids))
        for h in wins:
            _user32.PostMessageW(h, WM_CLOSE, 0, 0)
        return len(wins)

    def activate(self, pids):
        wins = _windows_of(set(pids))
        if not wins:
            return False
        _user32.ShowWindow(wins[0], 9)  # SW_RESTORE
        return bool(_user32.SetForegroundWindow(wins[0]))


def _each(pids, fn):
    for pid in pids:
        try:
            fn(psutil.Process(pid))
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass


def terminate(handle, pids):
    _each(pids, lambda p: p.terminate())


def kill(handle, pids):
    """Force Quit — only ever on the user's explicit choice."""
    _each(pids, lambda p: p.kill())
