"""Games installed as desktop apps: Flatpaks and native packages in the "Game" category.

Launchers and tools that also call themselves games are skipped (Steam, Heroic, Lutris,
ProtonUp-Qt …), as are shortcuts to Steam games (Carthage reads Steam directly) and
entries marked NoDisplay/Hidden.

Launch: Flatpaks as `flatpak run <app-id>` (so Carthage can find the running instance);
native apps run their Exec= command (field codes removed) inside a tracked scope.
"""

import configparser
import hashlib
import os
from pathlib import Path

NOT_GAMES = {
    "steam", "com.valvesoftware.Steam",
    "com.heroicgameslauncher.hgl", "heroic",
    "net.lutris.Lutris", "lutris",
    "page.kramo.Cartridges", "hu.kramo.Cartridges",
    "net.davidotek.pupgui2", "io.github.benjamimgois.goverlay",
    "com.usebottles.bottles", "io.itch.itch", "org.libretro.RetroArch",
    "io.github.lopiksa.Carthage",
}
# Categories that mark a launcher or tool even when "Game" is also listed.
TOOL_CATEGORIES = {"Utility", "PackageManager", "Network", "System", "Settings", "Development"}


def app_dirs():
    home = Path.home()
    data_home = Path(os.environ.get("XDG_DATA_HOME") or home / ".local" / "share")
    data_dirs = os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share"
    dirs = [data_home / "applications"]
    dirs += [Path(d) / "applications" for d in data_dirs.split(":") if d]
    dirs += [
        home / ".local" / "share" / "flatpak" / "exports" / "share" / "applications",
        Path("/var/lib/flatpak/exports/share/applications"),
    ]
    seen, out = set(), []
    for d in dirs:
        r = d.resolve() if d.exists() else d
        if r not in seen and d.is_dir():
            seen.add(r)
            out.append(d)
    return out


def watch_paths():
    return [str(d) for d in app_dirs()]


def _entry(path):
    cp = configparser.ConfigParser(interpolation=None, strict=False)
    cp.optionxform = str
    try:
        cp.read(path, encoding="utf-8")
        return cp["Desktop Entry"]
    except (configparser.Error, KeyError, UnicodeDecodeError, OSError):
        return None


def load():
    games, seen = [], set()
    for d in app_dirs():
        for path in sorted(d.glob("*.desktop")):
            app_id = path.stem
            if app_id in seen:
                continue  # the first directory wins, like the desktop does
            seen.add(app_id)
            e = _entry(path)
            if e is None or e.get("Type", "Application") != "Application":
                continue
            cats = set(filter(None, e.get("Categories", "").split(";")))
            if "Game" not in cats or cats & TOOL_CATEGORIES or app_id in NOT_GAMES:
                continue
            if e.get("NoDisplay") == "true" or e.get("Hidden") == "true":
                continue
            exe = e.get("Exec", "")
            if "steam://" in exe:
                continue  # a shortcut to a Steam game
            fp_id = e.get("X-Flatpak", "")
            from ..launcher import clean_exec

            games.append({
                "id": f"desktop_{app_id}",
                "name": e.get("Name") or app_id,
                "source": "flatpak" if fp_id else "desktop",
                "launch": f"flatpak run {fp_id}" if fp_id else clean_exec(exe),
                "desktop_file": str(path),
                "icon": e.get("Icon", ""),
                "short_id": hashlib.sha1(app_id.encode()).hexdigest()[:6].upper(),
            })
    return games
