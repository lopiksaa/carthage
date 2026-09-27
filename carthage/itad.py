"""IsThereAnyDeal (isthereanydeal.com), for the unified store's other stores: what GOG, the
Microsoft Store, EA, Blizzard and Epic ask for a game, with links into each store.

Optional: only while the "Other stores" switch is on and there is a key (keys.get("itad")).
The key is sent only to api.isthereanydeal.com. Prices and links are shown as ITAD gives
them (their terms: no changing prices or store links), and the store page credits ITAD.

Endpoints (docs.isthereanydeal.com, v2.11):
  GET  /service/shops/v1          shop ids by name (no key)
  GET  /games/lookup/v1?appid=    Steam app id → ITAD game id
  GET  /games/lookup/v1?title=    title → ITAD game id (games Steam doesn't sell)
  POST /games/prices/v3           current prices per shop, for up to 200 ids

Cached (~/.cache/carthage/store/itad_*.json): game ids for 30 days, prices for 3 hours. The
default limit is 1000 requests per 5 minutes per key.
"""

import json
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

from . import keys, shops

API = "https://api.isthereanydeal.com"
UA = "Carthage (github.com/lopiksaa/carthage)"
TIMEOUT = 15
IDS_TTL = 30 * 86400
PRICES_TTL = 3 * 3600

# ITAD shop name → Carthage store key. Steam's own page gives Steam's price.
SHOPS = {
    "Epic Game Store": "epic",
    "GOG": "gog",
    "Microsoft Store": "xbox",
    "EA Store": "ea",
    "Blizzard": "battlenet",
}

FETCH_ERRORS = (urllib.error.URLError, TimeoutError, OSError, ValueError)


def _request(path, params=None, body=None, key=""):
    params = dict(params or {})
    headers = {"User-Agent": UA}
    if key:
        headers["ITAD-API-Key"] = key
    url = API + path + ("?" + urllib.parse.urlencode(params) if params else "")
    data = json.dumps(body).encode() if body is not None else None
    if data is not None:
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=headers, method="POST" if data is not None else "GET")
    with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
        return json.load(r)


def check_key(key):
    """(ok, message) for the KEYS section: look up one well-known game."""
    try:
        d = _request("/games/lookup/v1", {"appid": 620}, key=key)
    except urllib.error.HTTPError as e:
        if e.code in (401, 403):
            return False, "IsThereAnyDeal didn't accept this key. Check it was copied completely."
        if e.code == 429:
            return False, "IsThereAnyDeal is busy (too many requests). Try again in a few minutes."
        return False, f"IsThereAnyDeal answered with an error ({e.code}). Try again later."
    except (urllib.error.URLError, TimeoutError, OSError):
        return False, "Couldn't reach IsThereAnyDeal. Check your internet connection."
    except ValueError:
        return False, "IsThereAnyDeal sent an unexpected answer. Try again later."
    return (True, "Key works.") if d.get("found") else (False, "IsThereAnyDeal didn't accept this key.")


class Itad:
    def __init__(self, cache_dir, money):
        self._money = money
        self._ids_path = cache_dir / "itad_ids.json"
        self._prices_path = cache_dir / "itad_prices.json"
        self._lock = threading.Lock()
        self._ids = self._read(self._ids_path)
        self._prices = self._read(self._prices_path)
        self._shop_ids = None

    @staticmethod
    def _read(path):
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            return {}

    def _write(self, path, data):
        try:
            path.write_text(json.dumps(data), encoding="utf-8")
        except OSError:
            pass

    def _shops(self):
        """ITAD's ids for the shops we show (asked once per run)."""
        if self._shop_ids is None:
            try:
                listed = _request("/service/shops/v1")
                self._shop_ids = {s["id"]: SHOPS[s["title"]] for s in listed if s.get("title") in SHOPS}
            except FETCH_ERRORS:
                return {}
        return self._shop_ids

    def _game_id(self, appid, title, key):
        ck = f"app/{appid}" if appid else "title/" + shops.norm_title(title)
        with self._lock:
            hit = self._ids.get(ck)
        if hit and time.time() - hit[1] < IDS_TTL:
            return hit[0]
        params = {"appid": appid} if appid else {"title": title}
        d = _request("/games/lookup/v1", params, key=key)
        gid = (d.get("game") or {}).get("id", "") if d.get("found") else ""
        with self._lock:
            self._ids[ck] = [gid, time.time()]
            self._write(self._ids_path, self._ids)
        return gid

    def _deals(self, gid, cc, key):
        ck = f"{gid}/{cc}"
        with self._lock:
            hit = self._prices.get(ck)
        if hit and time.time() - hit[1] < PRICES_TTL:
            return hit[0]
        shop_ids = self._shops()
        params = {"country": cc}
        if shop_ids:
            params["shops"] = ",".join(str(i) for i in shop_ids)
        d = _request("/games/prices/v3", params, body=[gid], key=key)
        deals = (d[0].get("deals") if d else None) or []
        with self._lock:
            self._prices[ck] = [deals, time.time()]
            # Old entries go, so the file doesn't grow forever.
            now = time.time()
            self._prices = {k: v for k, v in self._prices.items() if now - v[1] < PRICES_TTL}
            self._write(self._prices_path, self._prices)
        return deals

    def offers(self, appid, title, cc, existing):
        """`existing` (offers found directly, e.g. Epic's) plus every other store ITAD knows
        sells the game. Never raises: without a key or network it returns `existing`."""
        key = keys.get("itad")
        if not key:
            return existing
        try:
            gid = self._game_id(appid, title, key)
            deals = self._deals(gid, cc, key) if gid else []
        except FETCH_ERRORS:
            return existing
        by_name = {n: k for n, k in SHOPS.items()}
        have = {o["store"] for o in existing}
        out = list(existing)
        for dl in deals:
            store = by_name.get((dl.get("shop") or {}).get("name", ""))
            if not store or store in have:
                continue
            have.add(store)
            price, regular = dl.get("price") or {}, dl.get("regular") or {}
            cents, cur = price.get("amountInt"), price.get("currency", "EUR")
            out.append({
                "store": store,
                "storeName": shops.STORES[store],
                "price": "Free" if cents == 0 else self._money(cents, cur),
                "original": self._money(regular.get("amountInt"), cur) if dl.get("cut") else "",
                "discount": int(dl.get("cut") or 0),
                "free": cents == 0,
                "cents": cents if cents is not None else 1 << 30,
                "url": dl.get("url", ""),
                "via": "IsThereAnyDeal",
            })
        return out
