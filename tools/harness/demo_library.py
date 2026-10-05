"""The test harness's invented demo library: 24 games across every launcher, each with a
`sim` behavior (see carthage/library.py) so every dock state can be seen without real
launches. GC_FAKE_COUNT=500 pads it with generated titles (a stress test)."""

import os
import time

from carthage.library import Game, title_code

_FAKE = [
    ("Starfall Odyssey", "steam", True, "normal"),
    ("Moss & Lantern", "steam", True, "normal"),
    ("Neon Drift II", "steam", False, "normal"),
    ("The Quiet Harbor", "steam", True, "normal"),
    ("Ironbound: Siege of Vael", "steam", True, "stubborn"),
    ("Pixel Parade", "steam", True, "normal"),
    ("Hollow Pines", "heroic", True, "handoff"),
    ("Tidebreaker", "lutris", True, "normal"),
    ("Garden Sprites", "flatpak", True, "normal"),
    ("Skyward Postman", "steam", True, "normal"),
    ("Dungeon Bakery", "steam", False, "normal"),
    ("Retro Racer DX", "steam", True, "normal"),
    ("Aurora Protocol", "steam", True, "crash"),
    ("Cozy Burrow", "steam", True, "normal"),
    ("Paper Knights", "heroic", True, "handoff"),
    ("Void Salvage", "steam", False, "normal"),
    ("Lighthouse Keeper", "steam", True, "normal"),
    ("Mech Tactics: Frontier", "epic", True, "normal"),
    ("Harvest Moonlight", "riot", True, "normal"),
    ("Frostbyte", "lutris", True, "normal"),
    ("Sunset Arcade", "steam", False, "normal"),
    ("Clockwork Fox", "steam", True, "normal"),
    ("Deep Sky Radio", "battlenet", True, "unseen"),
    ("Lantern Launcher", "flatpak", True, "normal"),
]


def demo_games():
    count = int(os.environ.get("GC_FAKE_COUNT", "0") or 0)
    now = int(time.time())
    games = []
    for i, (title, source, installed, sim) in enumerate(_FAKE):
        g = Game(
            game_id=f"fake{i}",
            title=title,
            source=source,
            ext_id=str(1_200_000 + i * 7919) if source == "steam" else title_code(title).lower(),
            installed=installed,
            sim=sim,
            last_played=now - i * 86_400 * 3 if installed else 0,
            added=now - (len(_FAKE) - i) * 86_400,
        )
        if title == "Lantern Launcher":
            g.no_slot = True
        games.append(g)
    # Edge cases: GC_DEMO_EMPTY=1 for no games at all; GC_LONG_TITLES=1 for very long names.
    if os.environ.get("GC_DEMO_EMPTY"):
        return []
    if os.environ.get("GC_LONG_TITLES"):
        long = ["The Legend of the Extraordinarily Long Title: Remastered Definitive Collector's Edition",
                "Supercalifragilisticexpialidocious", "東方紅魔郷 ～ the Embodiment of Scarlet Devil", "A", "Ω"]
        for k, t in enumerate(long):
            games[k].title = t
    # Stress test: GC_FAKE_COUNT=500 pads the library with generated titles.
    for i in range(len(games), count):
        games.append(Game(f"fake{i}", f"Test Game {i}", "steam", str(2_000_000 + i), installed=i % 5 != 0, added=now - i))
    return games
