"""Steam achievements for the closer look: yours, with names, icons and how rare each is.

Three Steam Web API calls (the key only goes to api.steampowered.com):
- ISteamUserStats/GetPlayerAchievements: which ones you've unlocked, and when (needs your
  Steam key, and the profile's game details visible to it);
- ISteamUserStats/GetSchemaForGame: every achievement's name, description, icons, hidden flag;
- ISteamUserStats/GetGlobalAchievementPercentagesForApp: how many players have each (no key).
"""

import json
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

from PySide6.QtCore import QObject, Signal, Slot

API = "https://api.steampowered.com/ISteamUserStats/"
TTL = 600  # seconds a game's achievements are remembered
TIMEOUT = 15


def _call(method, params):
    url = API + method + "?" + urllib.parse.urlencode(params)
    with urllib.request.urlopen(url, timeout=TIMEOUT) as r:
        return json.load(r)


def fetch(appid, key, steam_id):
    """{appid, total, unlocked, items: [...], error}. Network: call from a worker thread only.

    Items are sorted: unlocked first (newest first), then locked (most common first, so the
    next ones within reach come first). A locked hidden achievement keeps its secret."""
    out = {"appid": appid, "total": 0, "unlocked": 0, "items": [], "error": ""}
    if not key or not steam_id:
        out["error"] = "Add your Steam key in Settings → Accounts & Keys to see achievements."
        return out
    try:
        mine = _call("GetPlayerAchievements/v1/", {"appid": appid, "steamid": steam_id, "key": key, "l": "english"})
    except urllib.error.HTTPError as e:
        # Steam answers 400 with a reason for "no stats" and private profiles.
        try:
            mine = json.load(e)
        except ValueError:
            out["error"] = "Steam didn't answer about achievements. Try again later."
            return out
    except (urllib.error.URLError, TimeoutError, OSError, ValueError):
        out["error"] = "Couldn't reach Steam for achievements. Check your connection."
        return out
    stats = mine.get("playerstats", {})
    if not stats.get("success"):
        reason = (stats.get("error") or "").lower()
        if "no stats" in reason:
            return out  # a game without achievements: nothing to show
        out["error"] = ("Your Steam profile's game details are private, so Steam won't share "
                        "achievements. You can change that in Steam → Profile → Privacy.")
        return out
    unlocked = {a["apiname"]: a for a in stats.get("achievements") or []}
    if not unlocked:
        return out
    try:
        schema = _call("GetSchemaForGame/v2/", {"appid": appid, "key": key, "l": "english"})
        defs = ((schema.get("game") or {}).get("availableGameStats") or {}).get("achievements") or []
    except (urllib.error.URLError, TimeoutError, OSError, ValueError):
        defs = []
    try:
        glob = _call("GetGlobalAchievementPercentagesForApp/v2/", {"gameid": appid})
        percent = {a["name"]: float(a["percent"]) for a in
                   (glob.get("achievementpercentages") or {}).get("achievements") or []}
    except (urllib.error.URLError, TimeoutError, OSError, ValueError, KeyError):
        percent = {}
    by_name = {d["name"]: d for d in defs}
    items = []
    for api_name, a in unlocked.items():
        d = by_name.get(api_name, {})
        got = bool(a.get("achieved"))
        hidden = bool(d.get("hidden")) and not got
        items.append({
            "name": "Hidden achievement" if hidden else (d.get("displayName") or a.get("name") or api_name),
            "description": "" if hidden else (d.get("description") or a.get("description") or ""),
            "icon": d.get("icon" if got else "icongray", ""),
            "unlocked": got,
            "time": int(a.get("unlocktime") or 0),
            "percent": percent.get(api_name, -1.0),
            "hidden": hidden,
        })
    items.sort(key=lambda i: (not i["unlocked"], -i["time"] if i["unlocked"] else -i["percent"]))
    out.update(total=len(items), unlocked=sum(i["unlocked"] for i in items), items=items)
    return out


class Achievements(QObject):
    """Loads a Steam game's achievements off the UI thread; `ready` brings them back."""

    ready = Signal(int, "QVariantMap")  # appid, fetch()'s result

    def __init__(self, steam_id, parent=None):
        super().__init__(parent)
        self._steam_id = steam_id  # a function: the Steam account on this PC, or None
        self._cache = {}  # appid → (time, result)
        self._loading = set()

    @Slot(int)
    def load(self, appid):
        cached = self._cache.get(appid)
        if cached and time.time() - cached[0] < TTL:
            self.ready.emit(appid, cached[1])
            return
        if not appid or appid in self._loading:
            return
        self._loading.add(appid)

        def work():
            from . import keys

            try:
                result = fetch(appid, keys.get("steam"), self._steam_id())
                if not result["error"]:
                    self._cache[appid] = (time.time(), result)
                self.ready.emit(appid, result)
            finally:
                self._loading.discard(appid)

        threading.Thread(target=work, daemon=True).start()
