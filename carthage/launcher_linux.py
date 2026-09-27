"""Starting, watching and stopping games (Linux / X11).

Launch kinds, from the game's executable:
  steam     steam://rungameid/<id>  → found via Steam's `reaper SteamLaunch AppId=<id>` process
  flatpak   flatpak run <app-id>    → found via `flatpak ps`
  handoff   heroic://… / lutris:…   → given to the other launcher; can't be tracked
  scope     any other command       → run inside its own systemd user scope; its cgroup
                                      holds every process the game starts

Only processes Carthage can attribute to the game are ever signalled. Quit first asks the
game's windows to close (like pressing their ✕); a hard kill only happens on Force Quit.
launcher_win.py is the Windows counterpart.
"""

import json
import os
import re
import shlex
import signal
import subprocess
import threading
import time
from pathlib import Path

CACHE = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "carthage"
SCOPES_FILE = CACHE / "scopes.json"

_FIELD_CODES = re.compile(r"%[fFuUdDnNickvm]")


def kind_of(executable):
    if executable.startswith("steam://rungameid/"):
        return "steam"
    if executable.startswith(("heroic://", "lutris:")):
        return "handoff"
    if executable.startswith("flatpak run "):
        return "flatpak"
    return "scope"


def steam_appid(executable):
    return executable.rsplit("/", 1)[-1]


def flatpak_id(executable):
    return executable.split()[2] if len(executable.split()) > 2 else ""


def clean_exec(exec_line):
    """A .desktop Exec= value → a runnable command (field codes removed)."""
    return _FIELD_CODES.sub("", exec_line).replace("%%", "%").strip()


def _detach(args):
    return subprocess.Popen(
        args, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        start_new_session=True, cwd=str(Path.home()),
    )



def progname(argv):
    """A process's program name from its argv, robust to Wine paths and to programs (like
    Chromium) that rewrite argv into one long string."""
    if not argv or not argv[0]:
        return ""
    a0 = argv[0].decode(errors="replace").replace("\\", "/")
    low = a0.lower()
    if ".exe" in low:
        a0 = a0[: low.index(".exe") + 4]
    elif " " in a0 and len(argv) <= 2:
        a0 = a0.split(" ", 1)[0]
    return a0.rsplit("/", 1)[-1]


class Snapshot:
    """One pass over /proc: parent links and command lines."""

    def __init__(self):
        self.parent = {}
        self.children = {}
        self.cmd = {}
        for entry in os.listdir("/proc"):
            if not entry.isdigit():
                continue
            pid = int(entry)
            try:
                with open(f"/proc/{pid}/stat", "rb") as f:
                    stat = f.read()
                ppid = int(stat[stat.rindex(b")") + 2 :].split()[1])
                with open(f"/proc/{pid}/cmdline", "rb") as f:
                    self.cmd[pid] = f.read().split(b"\0")
            except (OSError, ValueError):
                continue
            self.parent[pid] = ppid
            self.children.setdefault(ppid, []).append(pid)

    def tree(self, roots):
        """The given processes and all their descendants."""
        found, pending = set(), list(roots)
        while pending:
            pid = pending.pop()
            if pid in found or pid not in self.parent:
                continue
            found.add(pid)
            pending.extend(self.children.get(pid, []))
        return found

    def matching(self, names):
        """Processes whose program name matches any of `names` (case-insensitive). Works for
        Wine/Proton too: 'GenshinImpact.exe' matches Z:\\…\\GenshinImpact.exe in any argument."""
        wanted = {n.lower() for n in names if n}
        if not wanted:
            return set()
        out = set()
        for pid, argv in self.cmd.items():
            names = {progname(argv).lower()} | {progname([a]).lower() for a in argv[1:3]}
            if names & wanted:
                out.add(pid)
        return self.tree(out)

    def started_since(self, since, uid=None):
        """[(pid, name)] of this user's processes started after `since` (unix time)."""
        try:
            btime = next(int(l.split()[1]) for l in open("/proc/stat") if l.startswith("btime"))
            hz = os.sysconf("SC_CLK_TCK")
        except (OSError, StopIteration, ValueError):
            return []
        uid = os.getuid() if uid is None else uid
        out = []
        for pid in self.cmd:
            try:
                if os.stat(f"/proc/{pid}").st_uid != uid:
                    continue
                with open(f"/proc/{pid}/stat", "rb") as f:
                    stat = f.read()
                start = btime + int(stat[stat.rindex(b")") + 2:].split()[19]) / hz
            except (OSError, ValueError, IndexError):
                continue
            if start >= since:
                name = progname(self.cmd[pid])
                if name:
                    out.append((pid, name, start))
        return out

    def in_folder(self, folder):
        """Processes running from a game's install folder, and what they started. Native
        programs show the folder in their path; Wine/Proton ones show it as a Windows path
        (Z:\\home\\…), so both are checked. `folder` comes from folder_key()."""
        unix = folder.encode()
        wine = ("z:" + folder.replace("/", "\\")).lower().encode()
        roots = []
        for pid, argv in self.cmd.items():
            for a in argv[:2]:
                if a.startswith(unix) or a.lower().replace(b"/", b"\\").startswith(wine):
                    roots.append(pid)
                    break
        return self.tree(roots)

    def steam_games(self):
        """{appid: reaper pid} for every Steam game running right now."""
        out = {}
        for pid, argv in self.cmd.items():
            if len(argv) > 2 and argv[0].endswith(b"reaper") and b"SteamLaunch" in argv:
                for a in argv:
                    if a.startswith(b"AppId="):
                        appid = a[6:].decode(errors="replace")
                        if appid and appid != "0":
                            out[appid] = pid
        return out

    def running(self, name):
        n = name.encode()
        return any(argv and os.path.basename(argv[0]) == n for argv in self.cmd.values())


def flatpak_instances():
    """{app-id: [pid, …]} for running Flatpak apps."""
    try:
        out = subprocess.run(
            ["flatpak", "ps", "--columns=pid,application"], capture_output=True, text=True, timeout=3
        ).stdout
    except (OSError, subprocess.TimeoutExpired):
        return {}
    apps = {}
    for line in out.splitlines():
        parts = line.split()
        if len(parts) >= 2 and parts[0].isdigit():
            apps.setdefault(parts[1], []).append(int(parts[0]))
    return apps



def _load_scopes():
    try:
        return json.loads(SCOPES_FILE.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def _save_scopes(scopes):
    CACHE.mkdir(parents=True, exist_ok=True)
    SCOPES_FILE.write_text(json.dumps(scopes), encoding="utf-8")


def scope_pids(unit):
    try:
        cg = subprocess.run(
            ["systemctl", "--user", "show", "-p", "ControlGroup", "--value", unit],
            capture_output=True, text=True, timeout=2,
        ).stdout.strip()
        if not cg:
            return set()
        return {int(x) for x in Path(f"/sys/fs/cgroup{cg}/cgroup.procs").read_text(encoding="utf-8").split()}
    except (OSError, ValueError, subprocess.TimeoutExpired):
        return set()


def live_scopes():
    """{unit: game_id} for Carthage scopes that still have processes (e.g. after a restart)."""
    scopes = _load_scopes()
    alive = {u: g for u, g in scopes.items() if scope_pids(u)}
    if alive != scopes:
        _save_scopes(alive)
    return alive


def forget_scope(unit):
    scopes = _load_scopes()
    if scopes.pop(unit, None) is not None:
        _save_scopes(scopes)



def launch(game):
    """Start a game. Returns a handle dict describing how to find it again."""
    exe = game.executable
    kind = kind_of(exe)
    if kind == "steam":
        _detach(["steam", exe] if _which("steam") else ["xdg-open", exe])
        return {"kind": "steam", "appid": steam_appid(exe)}
    if kind == "handoff":
        _detach(["xdg-open", exe])
        return {"kind": "handoff"}
    if kind == "flatpak":
        _detach(shlex.split(exe))
        return {"kind": "flatpak", "app": flatpak_id(exe)}
    if not _which("systemd-run"):  # no systemd (Artix, Void…): follow the process tree instead
        p = _detach(["sh", "-c", exe])
        threading.Thread(target=p.wait, daemon=True).start()  # reap it, or it lingers as a zombie
        return {"kind": "proc", "pid": p.pid, "t": time.time()}
    unit = f"carthage-{re.sub(r'[^A-Za-z0-9]', '', game.game_id)[:40]}-{int(time.time())}.scope"
    _detach(["systemd-run", "--user", "--scope", "--collect", "-q", f"--unit={unit}", "--", "sh", "-c", exe])
    scopes = _load_scopes()
    scopes[unit] = game.game_id
    _save_scopes(scopes)
    return {"kind": "scope", "unit": unit}


def install(game):
    """Hand an uninstalled game to its launcher's installer."""
    if game.source == "steam":
        _detach(["xdg-open", f"steam://install/{game.ext_id}"])
        return True
    return False


def _which(name):
    return any((Path(p) / name).exists() for p in os.environ.get("PATH", "").split(":"))


def folder_key(path):
    """A game folder in the form in_folder() compares against: absolute, ending in "/"."""
    return os.path.join(os.path.normpath(os.path.abspath(path)), "")


def pids_for(handle, snap, flatpaks=None):
    """Every process currently belonging to the game (empty set: not running)."""
    k = handle["kind"]
    if k == "folder":
        return snap.in_folder(handle["dir"])
    if k == "names":
        return snap.matching(handle["names"])
    if k == "steam":
        reaper = snap.steam_games().get(handle["appid"])
        return snap.tree([reaper]) if reaper else set()
    if k == "flatpak":
        roots = (flatpaks if flatpaks is not None else flatpak_instances()).get(handle["app"], [])
        return snap.tree(roots)
    if k == "scope":
        return scope_pids(handle["unit"])
    if k == "proc":
        return snap.tree([handle["pid"]]) if handle["pid"] in snap.parent else set()
    return set()



class Windows:
    """Close or raise a game's windows through the window manager (EWMH)."""

    def __init__(self):
        self._d = None

    def _display(self):
        if self._d is None:
            from Xlib import display

            self._d = display.Display()
        return self._d

    def _windows_of(self, pids):
        from Xlib import X

        d = self._display()
        root = d.screen().root
        lst = root.get_full_property(d.intern_atom("_NET_CLIENT_LIST"), X.AnyPropertyType)
        pid_atom = d.intern_atom("_NET_WM_PID")
        out = []
        for wid in (lst.value if lst else []):
            w = d.create_resource_object("window", wid)
            try:
                p = w.get_full_property(pid_atom, X.AnyPropertyType)
            except Exception:
                continue
            if p and p.value[0] in pids:
                out.append(w)
        return out

    def close(self, pids):
        """Politely ask every window of these processes to close. Returns how many were asked."""
        try:
            from Xlib import X
            from Xlib.protocol import event

            d = self._display()
            root = d.screen().root
            close_atom = d.intern_atom("_NET_CLOSE_WINDOW")
            n = 0
            for w in self._windows_of(pids):
                ev = event.ClientMessage(window=w, client_type=close_atom, data=(32, [int(time.time()), 2, 0, 0, 0]))
                root.send_event(ev, event_mask=X.SubstructureRedirectMask | X.SubstructureNotifyMask)
                n += 1
            d.flush()
            return n
        except Exception:
            return 0

    def activate(self, pids):
        try:
            from Xlib import X
            from Xlib.protocol import event

            d = self._display()
            root = d.screen().root
            wins = self._windows_of(pids)
            if not wins:
                return False
            ev = event.ClientMessage(
                window=wins[0], client_type=d.intern_atom("_NET_ACTIVE_WINDOW"), data=(32, [2, X.CurrentTime, 0, 0, 0])
            )
            root.send_event(ev, event_mask=X.SubstructureRedirectMask | X.SubstructureNotifyMask)
            d.flush()
            return True
        except Exception:
            return False


def signal_all(pids, sig):
    for p in pids:
        try:
            os.kill(p, sig)
        except (ProcessLookupError, PermissionError):
            pass


def _run_quietly(cmd):
    """Best effort: a missing or stuck systemctl/flatpak must not stop the signals after it."""
    try:
        subprocess.run(cmd, capture_output=True, timeout=5)
    except (OSError, subprocess.TimeoutExpired):
        pass


def terminate(handle, pids):
    """Ask processes to stop (SIGTERM) — used when a game has no window to close."""
    if handle["kind"] == "scope":
        _run_quietly(["systemctl", "--user", "kill", "--signal=TERM", handle["unit"]])
    signal_all(pids, signal.SIGTERM)  # includes a linked game process outside the scope


def kill(handle, pids):
    """Force Quit — only ever on the user's explicit choice."""
    if handle["kind"] == "scope":
        _run_quietly(["systemctl", "--user", "kill", "--signal=KILL", handle["unit"]])
    elif handle["kind"] == "flatpak":
        _run_quietly(["flatpak", "kill", handle["app"]])
    signal_all(pids, signal.SIGKILL)
