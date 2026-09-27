"""Battle.net games on Windows, from what Blizzard's installer leaves behind — no network.

- installed:  the Uninstall registry entries whose uninstaller is Blizzard's
              ("…\\Battle.net\\Agent\\Blizzard Uninstaller.exe" --uid=prometheus …)
- launch:     the same as Blizzard's own shortcut: "<folder>\\<Game> Launcher.exe"
              --productcode=<code>, which hands the launch to Battle.net. The code is the
              "Product" column of <folder>\\.build.info (pro = Overwatch).

The game then runs from its folder (Overwatch: _retail_\\Overwatch.exe), which is how
launcher_win.py tracks it. Battle.net only lists installed games locally.
"""

import os
from pathlib import Path

_UNINSTALL = r"Software\Microsoft\Windows\CurrentVersion\Uninstall"
_SKIP_UIDS = {"battle.net", "bna", "agent"}  # the Battle.net app itself


def _uninstall_entries():
    import winreg

    views = [
        (winreg.HKEY_LOCAL_MACHINE, winreg.KEY_WOW64_32KEY),
        (winreg.HKEY_LOCAL_MACHINE, winreg.KEY_WOW64_64KEY),
        (winreg.HKEY_CURRENT_USER, 0),
    ]
    seen = set()
    for hive, view in views:
        try:
            root = winreg.OpenKey(hive, _UNINSTALL, 0, winreg.KEY_READ | view)
        except OSError:
            continue
        with root:
            for i in range(winreg.QueryInfoKey(root)[0]):
                try:
                    name = winreg.EnumKey(root, i)
                    with winreg.OpenKey(root, name) as k:
                        values = {}
                        for v in ("DisplayName", "InstallLocation", "UninstallString"):
                            try:
                                values[v] = str(winreg.QueryValueEx(k, v)[0])
                            except OSError:
                                values[v] = ""
                except OSError:
                    continue
                if (hive, name) not in seen:
                    seen.add((hive, name))
                    yield values


def _uid(uninstall):
    for part in uninstall.split():
        if part.startswith("--uid="):
            return part[len("--uid="):].strip('"').lower()
    return ""


def _product(folder):
    """The product code from .build.info (a "|"-separated table; first active row)."""
    try:
        lines = (folder / ".build.info").read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return ""
    if not lines:
        return ""
    header = [h.split("!")[0] for h in lines[0].split("|")]
    if "Product" not in header:
        return ""
    col, active = header.index("Product"), header.index("Active") if "Active" in header else None
    rows = [r.split("|") for r in lines[1:] if r.strip()]
    rows.sort(key=lambda r: active is not None and len(r) > active and r[active] == "1", reverse=True)
    for r in rows:
        if len(r) > col and r[col]:
            return r[col]
    return ""


def _launcher_exe(folder):
    stubs = sorted(folder.glob("* Launcher.exe"))
    return stubs[0] if stubs else None


def load():
    """[{id, name, launch, install_dir, short_id}] for installed Battle.net games."""
    if os.name != "nt":
        return []
    games = {}
    for e in _uninstall_entries():
        if "blizzard uninstaller" not in e["UninstallString"].lower():
            continue
        uid = _uid(e["UninstallString"])
        folder = Path(e["InstallLocation"]) if e["InstallLocation"] else None
        if not uid or uid in _SKIP_UIDS or not folder or not folder.is_dir() or uid in games:
            continue
        stub, product = _launcher_exe(folder), _product(folder)
        if not stub:
            continue
        launch = f'"{stub}"' + (f" --productcode={product}" if product else "")
        games[uid] = {
            "id": f"battlenet_{uid}",
            "name": e["DisplayName"] or folder.name,
            "launch": launch,
            "install_dir": str(folder),
            "short_id": (product or uid)[:6].upper(),
        }
    return list(games.values())
