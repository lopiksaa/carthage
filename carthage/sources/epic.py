"""Epic Games Store games on Windows, from the launcher's own install manifests — no network.

- installed:  %ProgramData%\\Epic\\EpicGamesLauncher\\Data\\Manifests\\*.item, one JSON file per
              installed item (games, DLC, engines…); only complete game installs count
- launch:     the link Epic's own desktop shortcuts use,
              com.epicgames.launcher://apps/<namespace>%3A<item id>%3A<app name>?action=launch&silent=true
              which hands the launch to the Epic Games Launcher

The game then runs from its install folder, which is how launcher_win.py tracks it. Games
on Linux reach Carthage through Heroic instead (sources/heroic.py).
"""

import json
import os
from pathlib import Path


def manifests_dir():
    return Path(os.environ.get("PROGRAMDATA", r"C:\ProgramData")) / "Epic" / "EpicGamesLauncher" / "Data" / "Manifests"


def _is_game(m):
    """A finished install of a game itself: not DLC (its AppName differs from the main game's),
    not the Unreal Engine or other tools, not a half-downloaded one."""
    if m.get("bIsIncompleteInstall"):
        return False
    app, main = m.get("AppName", ""), m.get("MainGameAppName", "")
    if main and app != main:
        return False
    cats = [c.lower() for c in m.get("AppCategories") or []]
    if cats and "games" not in cats:
        return False
    return bool(app and m.get("InstallLocation"))


def launch_url(m):
    ids = "%3A".join((m.get("CatalogNamespace", ""), m.get("CatalogItemId", ""), m.get("AppName", "")))
    return f"com.epicgames.launcher://apps/{ids}?action=launch&silent=true"


def load_from(folder):
    """[{id, name, launch, install_dir, short_id}] from a Manifests folder (any platform, for tests)."""
    games = {}
    for f in sorted(Path(folder).glob("*.item")):
        try:
            m = json.loads(f.read_text(encoding="utf-8", errors="replace"))
        except (OSError, ValueError):
            continue
        if not isinstance(m, dict) or not _is_game(m):
            continue
        app = m["AppName"]
        if app in games or not Path(m["InstallLocation"]).is_dir():
            continue
        games[app] = {
            "id": f"epic_{app.lower()}",
            "name": m.get("DisplayName") or app,
            "launch": launch_url(m),
            "install_dir": m["InstallLocation"],
            "short_id": app[:6].upper(),
        }
    return list(games.values())


def load():
    if os.name != "nt":
        return []
    return load_from(manifests_dir())
