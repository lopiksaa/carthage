"""Play time Carthage records itself, for every game whose launcher doesn't count it for us
(everything except Steam, which keeps its own).

Saved to ~/.config/carthage/playtime.json as {gameId: {"minutes": float, "last": unix time}}.
"minutes" is added on top of what the game's source reports (Lutris counts its own too);
Edit Play Time sets it so the total comes out as the number the user typed.
"""

import json
import os
import time

from .chrome import REAL_CONFIG_HOME


class PlayLog:
    def __init__(self, enabled=True):
        # Scripted runs (GC_DEMO) never write, like settings.json.
        self._enabled = enabled and not os.environ.get("GC_DEMO")
        self._path = REAL_CONFIG_HOME / "carthage" / "playtime.json"
        try:
            data = json.loads(self._path.read_text(encoding="utf-8"))
            self._data = {k: v for k, v in data.items() if isinstance(v, dict)}
        except (OSError, ValueError):
            self._data = {}

    @staticmethod
    def counts(game):
        # Not Steam (it counts its own), and not a pretend game (Test Cartridge, demo library).
        return game.source != "steam" and not game.sim

    def apply(self, game):
        """Fold the recorded time into a freshly loaded game (safe to call repeatedly)."""
        if not self.counts(game):
            return
        if getattr(game, "source_playtime", None) is None:
            game.source_playtime = game.playtime
        e = self._data.get(game.game_id)
        if e:
            game.playtime = max(0, round(game.source_playtime + e.get("minutes", 0)))
            game.last_played = max(game.last_played, int(e.get("last", 0)))

    def add(self, game, seconds):
        e = self._data.setdefault(game.game_id, {"minutes": 0.0, "last": 0})
        e["minutes"] = e.get("minutes", 0) + max(0.0, seconds) / 60
        e["last"] = int(time.time())
        self._save()
        self.apply(game)

    def touch(self, game):
        e = self._data.setdefault(game.game_id, {"minutes": 0.0, "last": 0})
        e["last"] = int(time.time())
        self._save()

    def set_total(self, game, minutes):
        self.apply(game)  # makes sure source_playtime is known
        e = self._data.setdefault(game.game_id, {"minutes": 0.0, "last": 0})
        e["minutes"] = float(minutes) - game.source_playtime
        self._save()
        self.apply(game)

    def _save(self):
        if not self._enabled:
            return
        try:
            self._path.parent.mkdir(parents=True, exist_ok=True)
            tmp = self._path.with_suffix(".tmp")
            tmp.write_text(json.dumps(self._data, indent=1), encoding="utf-8")
            tmp.replace(self._path)
        except OSError as e:
            print(f"[playtime] couldn't save: {e}", flush=True)
