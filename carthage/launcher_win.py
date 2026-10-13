"""Starting, watching and stopping games on Windows. Same functions as launcher_linux.py.

Launch kinds, from the game's executable:
  steam     steam://rungameid/<id>  → Steam writes the running game's id to the registry
                                      (RunningAppID); the game is the process running from
                                      steamapps\\common and everything it started
  folder    Battle.net games → "<Game> Launcher.exe --productcode=…" hands the launch to
                                      Battle.net; the game is what runs from its install folder
  handoff   heroic://… and other launcher links → given to that launcher; untracked
  proc      any other command → started here inside its own job object (Windows' process
                                      group: everything it starts joins it, even after a
                                      launcher stub exits); the job's processes are the game

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
_kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
_ntdll = ctypes.WinDLL("ntdll")
WM_CLOSE = 0x0010

_kernel32.CreateJobObjectW.restype = wintypes.HANDLE
_kernel32.CreateJobObjectW.argtypes = (wintypes.LPVOID, wintypes.LPCWSTR)
_kernel32.OpenProcess.restype = wintypes.HANDLE
_kernel32.OpenProcess.argtypes = (wintypes.DWORD, wintypes.BOOL, wintypes.DWORD)
_kernel32.AssignProcessToJobObject.argtypes = (wintypes.HANDLE, wintypes.HANDLE)
_kernel32.SetInformationJobObject.argtypes = (wintypes.HANDLE, ctypes.c_int, wintypes.LPVOID, wintypes.DWORD)
_kernel32.QueryInformationJobObject.argtypes = (wintypes.HANDLE, ctypes.c_int, wintypes.LPVOID, wintypes.DWORD,
                                                 wintypes.LPVOID)
_kernel32.CloseHandle.argtypes = (wintypes.HANDLE,)
_ntdll.NtResumeProcess.argtypes = (wintypes.HANDLE,)


class _ExtendedLimits(ctypes.Structure):
    """JOBOBJECT_EXTENDED_LIMIT_INFORMATION (only LimitFlags is set)."""
    _fields_ = [("PerProcessUserTimeLimit", ctypes.c_int64), ("PerJobUserTimeLimit", ctypes.c_int64),
                ("LimitFlags", wintypes.DWORD), ("MinimumWorkingSetSize", ctypes.c_size_t),
                ("MaximumWorkingSetSize", ctypes.c_size_t), ("ActiveProcessLimit", wintypes.DWORD),
                ("Affinity", ctypes.c_size_t), ("PriorityClass", wintypes.DWORD),
                ("SchedulingClass", wintypes.DWORD), ("Io", ctypes.c_uint64 * 6),
                ("ProcessMemoryLimit", ctypes.c_size_t), ("JobMemoryLimit", ctypes.c_size_t),
                ("PeakProcessMemoryUsed", ctypes.c_size_t), ("PeakJobMemoryUsed", ctypes.c_size_t)]


_JOB_EXTENDED_LIMITS = 9
_JOB_PROCESS_LIST = 3
_JOB_BREAKAWAY_OK = 0x800  # a program that asks to leave the job may (it would fail to start otherwise)
_PROCESS_JOB_ACCESS = 0x0100 | 0x0001 | 0x0800  # SET_QUOTA | TERMINATE | SUSPEND_RESUME
_jobs = {}  # launched pid → its job's handle (open while the game runs)


def _start_in_job(exe):
    """Start a command (through cmd, like a typed command) inside a new job object, so every
    process it starts is found later, even when a launcher stub hands over and exits. The
    process starts paused and only runs once it's in the job, so nothing slips out first.
    Returns the Popen; tracking falls back to the process tree if the job can't be made."""
    p = subprocess.Popen(exe, shell=True, cwd=str(os.path.expanduser("~")),
                         creationflags=subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.DETACHED_PROCESS
                         | 0x4)  # CREATE_SUSPENDED
    proc = _kernel32.OpenProcess(_PROCESS_JOB_ACCESS, False, p.pid)
    job = _kernel32.CreateJobObjectW(None, None)
    try:
        if job and proc:
            limits = _ExtendedLimits(LimitFlags=_JOB_BREAKAWAY_OK)
            _kernel32.SetInformationJobObject(job, _JOB_EXTENDED_LIMITS, ctypes.byref(limits), ctypes.sizeof(limits))
            if _kernel32.AssignProcessToJobObject(job, proc):
                _jobs[p.pid] = job
                job = None
        if p.pid not in _jobs:
            import logging

            logging.getLogger("carthage.launcher").warning(
                "No job object for this launch (error %d): tracking only its own process tree", ctypes.get_last_error())
    finally:
        if proc:
            _ntdll.NtResumeProcess(proc)
            _kernel32.CloseHandle(proc)
        if job:
            _kernel32.CloseHandle(job)
    return p


def _job_pids(pid):
    """The processes in the job of the game launched as `pid`; None if it has no job. The job
    is let go once it's empty (the game and everything it started have exited)."""
    job = _jobs.get(pid)
    if job is None:
        return None
    n = 256
    while True:
        buf = (ctypes.c_size_t * (n + 1))()  # two DWORD counts (one ULONG_PTR), then the ids
        if not _kernel32.QueryInformationJobObject(job, _JOB_PROCESS_LIST, buf, ctypes.sizeof(buf), None):
            if ctypes.get_last_error() == 234 and n < 65536:  # ERROR_MORE_DATA
                n *= 4
                continue
            return set()
        counts = ctypes.cast(buf, ctypes.POINTER(wintypes.DWORD))
        pids = {int(buf[1 + i]) for i in range(counts[1])}
        if not pids:
            _kernel32.CloseHandle(_jobs.pop(pid))
        return pids


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
    """steamapps\\common\\<installdir>\\ for a Steam app, lowercased (as Snapshot's paths are); "" if unknown."""
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
    """One pass over the running processes: parent links, names, paths and start times.
    (Not command lines: reading those means reaching into every program's memory, and
    nothing here needs them.)"""

    def __init__(self):
        self.parent, self.children, self.name, self.exe, self.started = {}, {}, {}, {}, {}
        for p in psutil.process_iter(["pid", "ppid", "name", "exe", "create_time"]):
            i = p.info
            pid = i["pid"]
            self.parent[pid] = i["ppid"] or 0
            self.children.setdefault(i["ppid"] or 0, []).append(pid)
            self.name[pid] = (i["name"] or "").lower()
            self.exe[pid] = (i["exe"] or "").lower()
            self.started[pid] = i["create_time"] or 0

    def tree(self, roots):
        """The processes and everything they started. Windows keeps a dead parent's id on its
        children and reuses ids, so a "child" only counts if it started after its parent (or a
        Windows program whose parent died long ago would look like the game's)."""
        found, pending = set(), list(roots)
        while pending:
            pid = pending.pop()
            if pid in found or pid not in self.parent:
                continue
            found.add(pid)
            born = self.started.get(pid, 0)
            pending.extend(c for c in self.children.get(pid, []) if self.started.get(c, 0) >= born)
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
        games = sorted((t, pid) for pid, t in self.started.items()
                       if folder and self.exe.get(pid, "").startswith(folder))
        if not games:
            # Some games run from somewhere else (a publisher's launcher the Steam app hands
            # over to): then it's what Steam itself started that isn't part of Steam.
            root = _steam.find_root()
            steam_dir = _folder_key(str(root)) if root else ""
            apps_dir = os.path.join(steam_dir, "steamapps", "")
            steam_pids = [pid for pid, n in self.name.items() if n == "steam.exe"]
            games = sorted((self.started[pid], pid) for sp in steam_pids for pid in self.children.get(sp, [])
                           if self.exe.get(pid) and (not steam_dir or not self.exe[pid].startswith(steam_dir)
                                                     or self.exe[pid].startswith(apps_dir)))
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


def steam_signed_in():
    return _steam.signed_in_windows()


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


# Sources whose games are tracked by their install folder (see launch()).
FOLDER_SOURCES = ("battlenet", "epic", "riot", "desktop")


def launch(game):
    exe = game.executable
    kind = kind_of(exe)
    if game.source in FOLDER_SOURCES and game.install_dir:
        # Each hands the launch to its own client (Battle.net's "<Game> Launcher.exe" stub,
        # Epic's com.epicgames.launcher:// link, RiotClientServices.exe --launch-product, a
        # game's own launcher); the game itself then runs from its install folder, which is
        # what gets tracked.
        if kind_of(exe) == "handoff":  # a link (Epic's)
            os.startfile(exe)
        else:
            # A game's own launcher starts in its own folder, like its shortcut does.
            cwd = os.path.dirname(_program(exe)) if game.source == "desktop" else game.install_dir
            subprocess.Popen(exe, cwd=cwd or game.install_dir,
                             creationflags=subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.DETACHED_PROCESS)
        return {"kind": "folder", "dir": _folder_key(game.install_dir)}
    if kind == "steam":
        os.startfile(exe)
        return {"kind": "steam", "appid": steam_appid(exe)}
    if kind == "handoff":
        os.startfile(exe)
        return {"kind": "handoff"}
    if not exe.strip().startswith('"') and os.path.isfile(os.path.expandvars(exe.strip())):
        exe = f'"{exe.strip()}"'  # a path with spaces typed without quotes (cmd would cut it at the space)
    p = _start_in_job(exe)
    return {"kind": "proc", "pid": p.pid, "t": time.time()}


def _program(exe):
    """The program a command starts (its first word, quotes removed)."""
    exe = exe.strip()
    if exe.startswith('"'):
        return exe[1:].split('"', 1)[0]
    return exe.split(" ", 1)[0]


def missing_program(game):
    """The path a game's command points to when that file doesn't exist (moved or
    uninstalled), else "". Only commands naming a file by its path are checked: a bare
    program name may be found on the PATH, and links go to their launcher."""
    exe = game.executable or ""
    if kind_of(exe) != "proc" or game.source in ("battlenet", "epic", "riot"):  # (they check their own)
        return ""
    program = os.path.expandvars(_program(exe))
    if not (os.path.isabs(program) or "\\" in program or "/" in program):
        return ""
    if os.path.isfile(os.path.expandvars(exe.strip())):
        return ""  # the whole command is one path with spaces, typed without quotes
    return "" if os.path.exists(program) else os.path.normpath(program)


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
        tree = snap.tree([handle["pid"]]) if handle["pid"] in snap.parent else set()
        job = _job_pids(handle["pid"])
        return tree if job is None else tree | (job & snap.parent.keys())
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
