"""Windows games that come with their own launcher instead of a store (Final Fantasy XIV,
Guild Wars 2), found where their installers record them — no network.

Each entry knows its game's registry keys (and the installed-apps entry as a second way in);
a game only counts when its program is really there. It's launched like its own shortcut
does, and tracked by its install folder (launcher_win.py), so its own launcher and the game
it starts are both seen.
"""

import os
from pathlib import Path


def _value(hive, key, name, view=0):
    try:
        import winreg

        with winreg.OpenKey(getattr(winreg, hive), key, 0, winreg.KEY_READ | view) as k:
            return str(winreg.QueryValueEx(k, name)[0])
    except (ImportError, OSError):
        return ""


def _uninstall(display_name, name):
    """A value of the installed-apps entry with this display name ("" if there's none)."""
    try:
        import winreg
    except ImportError:
        return ""
    for hive, view in ((winreg.HKEY_LOCAL_MACHINE, winreg.KEY_WOW64_32KEY), (winreg.HKEY_LOCAL_MACHINE, winreg.KEY_WOW64_64KEY),
                       (winreg.HKEY_CURRENT_USER, 0)):
        try:
            root = winreg.OpenKey(hive, r"Software\Microsoft\Windows\CurrentVersion\Uninstall", 0, winreg.KEY_READ | view)
        except OSError:
            continue
        with root:
            for i in range(winreg.QueryInfoKey(root)[0]):
                try:
                    with winreg.OpenKey(root, winreg.EnumKey(root, i)) as k:
                        if str(winreg.QueryValueEx(k, "DisplayName")[0]).strip().lower() == display_name.lower():
                            return str(winreg.QueryValueEx(k, name)[0])
                except OSError:
                    continue
    return ""


def _program(path):
    """A registry path to a program, cleaned up (quotes, a trailing ",0" icon index)."""
    path = path.strip().strip('"')
    if "," in path and not os.path.isfile(path):
        path = path.rsplit(",", 1)[0].strip('"')
    return path


def _ffxiv():
    """Square Enix's installer: HKLM\\SOFTWARE\\(WOW6432Node\\)SquareEnix\\<SubDirName>, under
    the installed-apps entry's folder; the boot launcher is <folder>\\boot\\ffxivboot.exe."""
    import winreg

    key = r"SOFTWARE\SquareEnix\FINAL FANTASY XIV - A Realm Reborn"
    sub = _value("HKEY_LOCAL_MACHINE", key, "SubDirName", winreg.KEY_WOW64_32KEY)
    base = _uninstall("FINAL FANTASY XIV ONLINE", "InstallLocation")
    candidates = []
    if sub and base:
        candidates.append(Path(base) / sub / "boot" / "ffxivboot.exe")
    icon = _program(_uninstall("FINAL FANTASY XIV ONLINE", "DisplayIcon"))
    if icon:
        candidates.append(Path(icon))
    for exe in candidates:
        if exe.name.lower() == "ffxivboot.exe" and exe.is_file():
            return exe, exe.parent.parent  # the game's folder holds boot\ and game\
    return None


def _gw2():
    """ArenaNet's installer: HKLM\\SOFTWARE\\ArenaNet\\Guild Wars 2, value Path (Gw2-64.exe)."""
    import winreg

    for path in (_value("HKEY_LOCAL_MACHINE", r"SOFTWARE\ArenaNet\Guild Wars 2", "Path", winreg.KEY_WOW64_64KEY),
                 _program(_uninstall("Guild Wars 2", "DisplayIcon"))):
        exe = Path(_program(path)) if path else None
        if exe and exe.suffix.lower() == ".exe" and exe.is_file():
            return exe, exe.parent
    return None


# (id, name, finder → (program, install folder) or None)
GAMES = [
    ("ffxiv", "FINAL FANTASY XIV Online", _ffxiv),
    ("gw2", "Guild Wars 2", _gw2),
]


def load():
    """[{id, name, launch, install_dir, short_id}] for the installed ones."""
    if os.name != "nt":
        return []
    games = []
    for gid, name, find in GAMES:
        try:
            found = find()
        except OSError:
            found = None
        if found:
            exe, folder = found
            games.append({"id": f"standalone_{gid}", "name": name, "launch": f'"{exe}"',
                          "install_dir": str(folder), "short_id": gid.upper()[:6]})
    return games
