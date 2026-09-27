"""Lutris games, from Lutris's own database (pga.db, opened read-only).

Steam games inside Lutris are skipped (Carthage reads Steam directly). Games in Lutris's
".hidden" category stay hidden. Launch: lutris:rungameid/<id>.
"""

import sqlite3
from pathlib import Path

QUERY = """
    SELECT games.id, games.name, games.slug, games.runner, games.installed, games.directory,
           games.lastplayed, games.playtime, games.installed_at,
           EXISTS (SELECT 1 FROM games_categories gc JOIN categories c ON c.id = gc.category_id
                   WHERE gc.game_id = games.id AND c.name = '.hidden') AS hidden
    FROM games
    WHERE games.name IS NOT NULL AND games.slug IS NOT NULL
"""


def data_dirs():
    home = Path.home()
    return [
        home / ".local" / "share" / "lutris",
        home / ".var" / "app" / "net.lutris.Lutris" / "data" / "lutris",
    ]


def db_path():
    for d in data_dirs():
        if (d / "pga.db").exists():
            return d / "pga.db"
    return None


def watch_paths():
    p = db_path()
    return [str(p)] if p else []


def load():
    p = db_path()
    if p is None:
        return []
    try:
        con = sqlite3.connect(f"file:{p}?mode=ro", uri=True, timeout=2)
        try:
            rows = con.execute(QUERY).fetchall()
        finally:
            con.close()
    except sqlite3.Error:
        return []
    games = []
    for gid, name, slug, runner, installed, directory, lastplayed, playtime, installed_at, hidden in rows:
        if hidden or runner == "steam":
            continue
        cover = p.parent / "coverart" / f"{slug}.jpg"
        games.append({
            "id": f"lutris_{gid}",
            "name": name,
            "installed": bool(installed),
            "launch": f"lutris:rungameid/{gid}",
            "install_dir": directory or "",
            "short_id": str(slug)[:8].upper(),
            "last_played": int(lastplayed or 0),
            "playtime": int(round(float(playtime or 0) * 60)),  # Lutris stores hours
            "added": int(installed_at or 0),
            "cover": str(cover) if cover.exists() else "",
        })
    return games
