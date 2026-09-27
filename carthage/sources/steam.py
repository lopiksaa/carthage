"""Steam games from Steam's own local files — no network, no API key.

- installed:  steamapps/appmanifest_*.acf in every library folder
- play data:  userdata/<account>/config/localconfig.vdf (LastPlayed, Playtime) for the
              most recent login — also lists games played before and since uninstalled
- names/type: appcache/appinfo.vdf (so Proton, runtimes & redistributables — type "tool"
              — are filtered out exactly, not by guessing from names)

On Windows, Steam's folder comes from the registry.
"""

import json
import os
import re
import time
import urllib.error
import urllib.request
from pathlib import Path

from .. import vdf
from .steam_appinfo import read_appinfo

STEAMID64_BASE = 76561197960265728

# Fallback when appinfo.vdf can't be read.
_TOOL_NAMES = re.compile(
    r"^(Proton\b|Steam Linux Runtime|Steamworks Common Redistributables|Steam Audio|SteamVR\b)", re.I
)


def _windows_steam_path():
    """Steam's folder on Windows, from the registry (HKCU\\Software\\Valve\\Steam\\SteamPath)."""
    try:
        import winreg

        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Software\Valve\Steam") as k:
            return Path(winreg.QueryValueEx(k, "SteamPath")[0])
    except OSError:
        return None


def running_appid_windows():
    """The Steam game running right now on Windows (0 = none): Steam writes it to the registry."""
    try:
        import winreg

        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Software\Valve\Steam") as k:
            return int(winreg.QueryValueEx(k, "RunningAppID")[0] or 0)
    except (OSError, ValueError):
        return 0


def find_root():
    if os.name == "nt":
        for c in (_windows_steam_path(), Path(os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)")) / "Steam"):
            if c and (c / "steamapps").is_dir():
                return c.resolve()
        return None
    candidates = [
        Path.home() / ".steam" / "steam",
        Path.home() / ".local" / "share" / "Steam",
        Path.home() / ".var" / "app" / "com.valvesoftware.Steam" / ".local" / "share" / "Steam",
    ]
    for c in candidates:
        if (c / "steamapps").is_dir():
            return c.resolve()
    return None


def library_paths(root):
    paths = [root]
    try:
        data = vdf.load(root / "steamapps" / "libraryfolders.vdf").get("libraryfolders", {})
        for entry in data.values():
            if isinstance(entry, dict) and entry.get("path"):
                p = Path(entry["path"])
                if p.resolve() not in [x.resolve() for x in paths] and (p / "steamapps").is_dir():
                    paths.append(p)
    except OSError:
        pass
    return paths


def watch_paths(root):
    """Files and folders whose changes should trigger a library reload."""
    out = [str(p / "steamapps") for p in library_paths(root)]
    lc = _localconfig_path(root)
    if lc:
        out.append(str(lc))
    return out


def _most_recent_account(root):
    try:
        users = vdf.load(root / "config" / "loginusers.vdf").get("users", {})
        for sid, info in users.items():
            if isinstance(info, dict) and info.get("mostrecent") == "1":
                return int(sid) - STEAMID64_BASE
        if users:
            return int(next(iter(users))) - STEAMID64_BASE
    except (OSError, ValueError):
        pass
    ud = root / "userdata"
    ids = [int(p.name) for p in ud.iterdir() if p.name.isdigit()] if ud.is_dir() else []
    return ids[0] if len(ids) == 1 else None


def _localconfig_path(root):
    acct = _most_recent_account(root)
    if acct is None:
        return None
    p = root / "userdata" / str(acct) / "config" / "localconfig.vdf"
    return p if p.exists() else None


def steam_id64(root):
    acct = _most_recent_account(root)
    return acct + STEAMID64_BASE if acct is not None else None


def _play_data(root):
    """{appid: (last_played, playtime_minutes)}"""
    p = _localconfig_path(root)
    if not p:
        return {}
    try:
        data = vdf.load(p)
    except OSError:
        return {}
    apps = (
        data.get("userlocalconfigstore", {}).get("software", {}).get("valve", {}).get("steam", {}).get("apps", {})
    )
    out = {}
    for appid, info in apps.items():
        if appid.isdigit() and isinstance(info, dict):
            lp = int(info.get("lastplayed", "0") or 0)
            pt = int(info.get("playtime", "0") or 0)
            if lp or pt:
                out[int(appid)] = (lp, pt)
    return out


def _meta(appinfo, appid):
    a = appinfo.get(appid) or {}
    return {"developer": a.get("developer", ""), "publisher": a.get("publisher", ""), "released": a.get("released", 0)}


def load(root=None):
    """Returns a list of dicts describing Steam games (installed + previously played)."""
    root = root or find_root()
    import logging

    logging.getLogger("carthage.steam").info("Steam folder: %s", root or "not found")
    if root is None:
        return []
    try:
        appinfo = read_appinfo(root / "appcache" / "appinfo.vdf")
    except (OSError, ValueError):
        appinfo = {}
    play = _play_data(root)

    def is_game(appid, name):
        info = appinfo.get(appid)
        if info:
            return info["type"] == "game"
        return not _TOOL_NAMES.search(name or "")

    games = {}
    for lib in library_paths(root):
        for acf in (lib / "steamapps").glob("appmanifest_*.acf"):
            try:
                st = vdf.load(acf).get("appstate", {})
                appid = int(st.get("appid", "0"))
            except (OSError, ValueError):
                continue
            name = st.get("name") or appinfo.get(appid, {}).get("name", "")
            if not appid or not is_game(appid, name):
                continue
            flags = int(st.get("stateflags", "0") or 0)
            lp, pt = play.get(appid, (int(st.get("lastplayed", "0") or 0), 0))
            games[appid] = {
                "appid": appid,
                "name": name,
                # StateFlags bit 4 = fully installed; anything else is mid-install/update.
                "installed": bool(flags & 4),
                "install_dir": str(lib / "steamapps" / "common" / st.get("installdir", "")),
                "last_played": lp,
                "playtime": pt,
                "added": int(st.get("lastupdated", "0") or 0),
                **_meta(appinfo, appid),
            }

    for appid, (lp, pt) in play.items():
        if appid in games:
            continue
        info = appinfo.get(appid)
        if not info or info["type"] != "game" or not info["name"]:
            continue
        games[appid] = {
            "appid": appid,
            "name": info["name"],
            "installed": False,
            "install_dir": "",
            "last_played": lp,
            "playtime": pt,
            "added": 0,
            **_meta(appinfo, appid),
        }
    owned, _ = owned_cache()
    for appid, info in owned.items():
        a = appinfo.get(appid)
        if a and a["type"] not in ("game", ""):
            continue  # a tool/app/beta that the API happens to list
        if appid in games:
            g = games[appid]
            g["playtime"] = max(g["playtime"], info["playtime"])
            g["last_played"] = max(g["last_played"], info["last_played"])
            continue
        name = info["name"] or (a["name"] if a else "")
        if not name:
            continue
        games[appid] = {
            "appid": appid,
            "name": name,
            "installed": False,
            "install_dir": "",
            "last_played": info["last_played"],
            "playtime": info["playtime"],
            "added": 0,
            **_meta(appinfo, appid),
        }
    return list(games.values())


def _dir_size(path):
    total = 0
    stack = [str(path)]
    while stack:
        try:
            with os.scandir(stack.pop()) as it:
                for e in it:
                    try:
                        if e.is_dir(follow_symlinks=False):
                            stack.append(e.path)
                        else:
                            total += e.stat(follow_symlinks=False).st_size
                    except OSError:
                        pass
        except OSError:
            pass
    return total


_LOG_TOTAL = re.compile(rb"AppID (\d+) update started : download (\d+)/(\d+).*?stage (\d+)/(\d+)")
_LOG_STATE = re.compile(rb"AppID (\d+) App update changed : ([^\n]*)")


def _log_state(root):
    """From the tail of Steam's content log: {appid: (stage_total, latest_update_state)}."""
    path = root / "logs" / "content_log.txt"
    try:
        with open(path, "rb") as f:
            f.seek(0, 2)
            f.seek(max(0, f.tell() - 256 * 1024))
            tail = f.read()
    except OSError:
        return {}
    info = {}
    for m in _LOG_TOTAL.finditer(tail):
        appid = int(m.group(1))
        info[appid] = [int(m.group(5)), info.get(appid, [0, ""])[1]]
    for m in _LOG_STATE.finditer(tail):
        appid = int(m.group(1))
        info.setdefault(appid, [0, ""])[1] = m.group(2).decode(errors="replace").strip()
    return {k: tuple(v) for k, v in info.items()}


def installing(root=None):
    """{appid: fraction 0..1} for games Steam is installing for the first time.

    Steam only writes its byte counters into the appmanifest now and then, so progress is
    measured live: the size of steamapps/downloading/<appid> (where Steam stages the files)
    against the total it announced ("stage X/Y" in logs/content_log.txt, else the
    manifest). While Steam commits the staged files, it's 95–100 %."""
    root = root or find_root()
    if root is None:
        return {}
    log = None
    out = {}
    for lib in library_paths(root):
        for acf in (lib / "steamapps").glob("appmanifest_*.acf"):
            try:
                st = vdf.load(acf).get("appstate", {})
                flags = int(st.get("stateflags", "0") or 0)
                appid = int(st.get("appid", "0"))
            except (OSError, ValueError):
                continue
            if not appid or flags & 4:  # first installs only
                continue
            if log is None:
                log = _log_state(root)
            total, state = log.get(appid, (0, ""))
            total = total or int(st.get("bytestostage", 0) or 0) or int(st.get("bytestodownload", 0) or 0)
            if "Committing" in state:
                out[appid] = 0.97
                continue
            staged = _dir_size(lib / "steamapps" / "downloading" / str(appid))
            out[appid] = min(0.95, 0.95 * staged / total) if total else 0.0
    return out


OWNED_CACHE = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "carthage" / "steam_owned.json"


def owned_cache():
    """The last fetched owned-games list: {appid: {name, playtime, last_played}} (may be empty)."""
    try:
        data = json.loads(OWNED_CACHE.read_text(encoding="utf-8"))
        return {int(k): v for k, v in data.get("games", {}).items()}, data.get("t", 0)
    except (OSError, ValueError):
        return {}, 0


def refresh_owned(key, steam_id):
    """Fetch the owned-games list from the Steam Web API and cache it.
    Returns True if the cache changed. Network — call from a worker thread only."""
    url = (
        "https://api.steampowered.com/IPlayerService/GetOwnedGames/v1/"
        f"?key={key}&steamid={steam_id}&include_appinfo=1&include_played_free_games=1&format=json"
    )
    try:
        with urllib.request.urlopen(url, timeout=20) as r:
            resp = json.load(r).get("response", {})
    except (urllib.error.URLError, TimeoutError, OSError, ValueError):
        return False
    if "games" not in resp:
        return False  # private profile or error: keep the old cache
    games = {
        str(g["appid"]): {
            "name": g.get("name", ""),
            "playtime": int(g.get("playtime_forever", 0)),
            "last_played": int(g.get("rtime_last_played", 0)),
        }
        for g in resp["games"]
        if g.get("appid")
    }
    old, _ = owned_cache()
    OWNED_CACHE.parent.mkdir(parents=True, exist_ok=True)
    tmp = OWNED_CACHE.with_suffix(".tmp")
    tmp.write_text(json.dumps({"t": int(time.time()), "games": games}))
    os.replace(tmp, OWNED_CACHE)
    return {int(k): v for k, v in games.items()} != old
