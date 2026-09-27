"""Heroic Games Launcher: Epic (legendary), GOG, Amazon (nile) and sideloaded games.

Reads Heroic's own cache and install files (read-only). Owned but not-installed games
are included too, shown as not installed. Games hidden in Heroic
stay hidden.

Launch: heroic://launch/<runner>/<app_name> (Heroic's documented URL scheme).
"""

import json
import os
from pathlib import Path

# (store key, library file, key holding the list, installed file, how to read installed)
STORES = [
    ("legendary", "store_cache/legendary_library.json", "library", "legendaryConfig/legendary/installed.json", "keys"),
    ("gog", "store_cache/gog_library.json", "games", "gog_store/installed.json", "gog"),
    ("nile", "store_cache/nile_library.json", "library", "nile_config/nile/installed.json", "nile"),
    ("sideload", "sideload_apps/library.json", "games", None, "flag"),
]


def config_dirs():
    home = Path.home()
    return [
        home / ".config" / "heroic",
        home / ".var" / "app" / "com.heroicgameslauncher.hgl" / "config" / "heroic",
        # Windows: %APPDATA%\\heroic
        Path(os.environ.get("APPDATA", str(home / "AppData" / "Roaming"))) / "heroic",
    ]


def root():
    for d in config_dirs():
        if (d / "store_cache").is_dir() or (d / "sideload_apps").is_dir():
            return d
    return None


def watch_paths():
    r = root()
    if not r:
        return []
    out = []
    for _store, lib, _k, inst, _how in STORES:
        for rel in (lib, inst):
            if rel and (r / rel).exists():
                out.append(str(r / rel))
    return out


def _json(path):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def _installed(r, rel, how):
    """{app: install folder ("" if unknown)} for installed games, or None when this store
    has no installed file (sideloaded apps carry an is_installed flag instead)."""
    if rel is None:
        return None
    data = _json(r / rel)
    if data is None:
        return {}
    try:
        if how == "keys":
            return {k: (v or {}).get("install_path", "") if isinstance(v, dict) else "" for k, v in data.items()}
        if how == "gog":
            return {e.get("appName"): e.get("install_path", "") for e in data.get("installed", []) if e.get("appName")}
        if how == "nile":
            return {e.get("id"): e.get("path", "") for e in data if e.get("id")}
    except (AttributeError, TypeError):
        pass
    return {}


def _install_path(entry):
    inst = entry.get("install")
    return inst.get("install_path", "") if isinstance(inst, dict) else ""


def _hidden(r):
    data = _json(r / "store" / "config.json") or {}
    try:
        return {g.get("appName") for g in data["games"]["hidden"] if g.get("appName")}
    except (KeyError, TypeError):
        return set()


def load():
    r = root()
    if r is None:
        return []
    hidden = _hidden(r)
    games = []
    for store, lib, key, inst, how in STORES:
        data = _json(r / lib)
        if not isinstance(data, dict):
            continue
        entries = data.get(key) or []
        if isinstance(entries, dict):
            entries = list(entries.values())
        installed = _installed(r, inst, how)
        for e in entries:
            if not isinstance(e, dict):
                continue
            app, title = e.get("app_name"), e.get("title")
            runner = e.get("runner") or store
            if not app or not title or app in hidden or e.get("is_dlc"):
                continue
            is_inst = bool(e.get("is_installed")) if installed is None else app in installed
            games.append({
                "id": f"heroic_{runner}_{app}",
                "name": title,
                "store": runner,
                "installed": is_inst,
                "launch": f"heroic://launch/{runner}/{app}",
                "install_dir": (installed or {}).get(app, "") or _install_path(e),
                "short_id": app[:8].upper(),
                "developer": e.get("developer") or "",
            })
    return games
