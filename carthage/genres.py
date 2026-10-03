"""Genres for library games: the store's categories (store.Store.CATEGORIES, Steam tags), so
the library and the store use the same names.

- Steam games: their Steam tags, in batches (IStoreBrowseService/GetItems).
- Other games (Heroic, the Epic launcher, Lutris…): matched to a Steam page by exact title
  (Steam's public store search), then the same tags.
- Games added by hand, and games without a matching Steam page, have none.

Cached in ~/.cache/carthage/genres.json: Steam tags for 30 days, title matches for good (a
match that failed is retried after 30 days). Network: call `lookup` from a worker thread.
"""

import json
import time
import urllib.parse

from . import shops
from .store import CACHE, FETCH_ERRORS, Store, _batch, _fetch_json, country

PATH = CACHE.parent / "genres.json"
REFRESH = 30 * 86400
GENRE_TAGS = {tag for _, tag in Store.CATEGORIES}


def _load():
    try:
        data = json.loads(PATH.read_text(encoding="utf-8"))
        return {"tags": data.get("tags", {}), "titles": data.get("titles", {})}
    except (OSError, ValueError):
        return {"tags": {}, "titles": {}}


def _save(cache):
    try:
        PATH.parent.mkdir(parents=True, exist_ok=True)
        PATH.write_text(json.dumps(cache), encoding="utf-8")
    except OSError:
        pass


def _steam_match(title):
    """The Steam app id with exactly this title (normalized), or 0."""
    want = shops.norm_title(title)
    if not want:
        return 0
    url = "https://store.steampowered.com/api/storesearch/?" + urllib.parse.urlencode(
        {"term": title, "cc": country(), "l": "english"})
    for it in _fetch_json(url, timeout=15).get("items") or []:
        if shops.norm_title(it.get("name", "")) == want:
            return int(it["id"])
    return 0


def lookup(games):
    """{game_id: [tag, …]} (only the store's category tags) for these games.
    `games`: [(game_id, source, ext_id, title)]."""
    cache = _load()
    now = time.time()
    appid_of = {}
    for gid, source, ext_id, title in games:
        if source == "steam" and str(ext_id).isdigit():
            appid_of[gid] = int(ext_id)
        elif source != "custom" and title:
            key = shops.norm_title(title)
            known = cache["titles"].get(key)
            if known is None or (known[0] == 0 and now - known[1] > REFRESH):
                try:
                    known = [_steam_match(title), now]
                except FETCH_ERRORS:
                    continue
                cache["titles"][key] = known
                time.sleep(0.3)  # be gentle with Steam
            if known[0]:
                appid_of[gid] = known[0]
    stale = [a for a in set(appid_of.values())
             if str(a) not in cache["tags"] or now - cache["tags"][str(a)][1] > REFRESH]
    if stale:
        try:
            for appid, info in _batch(stale).items():
                cache["tags"][str(appid)] = [sorted(info.get("tags", [])), now]
        except FETCH_ERRORS:
            pass
    _save(cache)
    out = {}
    for gid, appid in appid_of.items():
        tags = (cache["tags"].get(str(appid)) or [[], 0])[0]
        out[gid] = [t for t in tags if t in GENRE_TAGS]
    return out
