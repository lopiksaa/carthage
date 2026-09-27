"""Stores other than Steam, for the unified store.

Epic Games Store, without a key, through the endpoints its own website uses:
  freeGamesPromotions   the weekly free games (now and next)
  graphql searchStore   search by name, with prices and art (a persisted query: if Epic
                        changes its hash, Epic results simply stop appearing)

A game's offers are what each store asks for it: [{store, storeName, price, original,
discount, url, free, until}] — Steam's first, then the others, cheapest first. The store
page's cartridge turns through them.

IsThereAnyDeal (optional, "Other stores" switch, needs a key) adds GOG, the Microsoft
Store, EA, Blizzard and Epic prices for any game: see itad.py.
"""

import datetime
import json
import re
import unicodedata
import urllib.parse

EPIC_FREE = "https://store-site-backend-static-ipv4.ak.epicgames.com/freeGamesPromotions"
EPIC_GRAPHQL = "https://store.epicgames.com/graphql"
EPIC_SEARCH_HASH = "7d58e12d9dd8cb14c84a3ff18d360bf9f0caa96bf218f2c5fda68ba88d68a437"
EPIC_PAGE = "https://store.epicgames.com/p/"
EPIC_CATEGORY = "games/edition/base|bundles/games"

STORES = {
    "steam": "Steam",
    "epic": "Epic Games",
    "gog": "GOG",
    "xbox": "Microsoft Store",
    "ea": "EA",
    "battlenet": "Battle.net",
}

MONTHS = "Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec".split()


def norm_title(title):
    """A title reduced for matching across stores: no ™®©, accents, punctuation or case."""
    t = unicodedata.normalize("NFKD", title or "")
    t = "".join(c for c in t if not unicodedata.combining(c))
    t = re.sub(r"[™®©]", "", t).lower().replace("&", "and")
    return re.sub(r"[^a-z0-9]+", " ", t).strip()


def _date(iso):
    try:
        return datetime.datetime.fromisoformat(iso.replace("Z", "+00:00"))
    except (AttributeError, ValueError):
        return None


def _day(d):
    local = d.astimezone()
    return f"{local.day} {MONTHS[local.month - 1]}"


def _epic_image(el, *kinds):
    imgs = {i.get("type"): i.get("url") for i in el.get("keyImages") or []}
    for k in kinds:
        if imgs.get(k):
            return imgs[k]
    return ""


def _epic_slug(el):
    for m in (el.get("catalogNs") or {}).get("mappings") or []:
        if m.get("pageSlug") and m.get("pageType", "productHome") == "productHome":
            return m["pageSlug"]
    for m in el.get("offerMappings") or []:
        if m.get("pageSlug"):
            return m["pageSlug"]
    return el.get("productSlug") or el.get("urlSlug") or ""


def _epic_offer(el, money):
    tp = (el.get("price") or {}).get("totalPrice") or {}
    final, orig = tp.get("discountPrice"), tp.get("originalPrice")
    cur = tp.get("currencyCode", "EUR")
    slug = _epic_slug(el)
    return {
        "store": "epic",
        "storeName": STORES["epic"],
        "price": "Free" if final == 0 else money(final, cur),
        "original": money(orig, cur) if orig and final is not None and final < orig else "",
        "discount": round(100 - 100 * final / orig) if orig and final is not None and final < orig else 0,
        "free": final == 0,
        "cents": final if final is not None else 1 << 30,
        "url": EPIC_PAGE + slug if slug else "https://store.epicgames.com/",
    }


def epic_item(el, money):
    """An Epic game as a store item (for games Steam doesn't sell, and the free shelf)."""
    offer = _epic_offer(el, money)
    slug = _epic_slug(el)
    return {
        "key": "epic:" + (slug or el.get("id", "")),
        "store": "epic",
        "name": el.get("title", ""),
        "price": offer["price"],
        "original": offer["original"],
        "discount": offer["discount"],
        "capsule": _epic_image(el, "OfferImageTall", "DieselStoreFrontTall", "Thumbnail"),
        "header": _epic_image(el, "OfferImageWide", "DieselStoreFrontWide"),
        "hero": _epic_image(el, "OfferImageWide", "DieselStoreFrontWide"),
        "description": el.get("description", "") if el.get("description") != el.get("title") else "",
        "offers": [offer],
    }


def epic_free(fetch_json, cc, money):
    """Epic's free games: [items] with `until` (free now) or `from` (next), in Epic's order."""
    d = fetch_json(EPIC_FREE, {"locale": "en-US", "country": cc, "allowCountries": cc})
    now, soon = [], []
    for el in ((d.get("data") or {}).get("Catalog") or {}).get("searchStore", {}).get("elements", []):
        p = el.get("promotions") or {}
        cur = [o for g in p.get("promotionalOffers") or [] for o in g.get("promotionalOffers") or []]
        nxt = [o for g in p.get("upcomingPromotionalOffers") or [] for o in g.get("promotionalOffers") or []]
        # Only giveaways (100% off), not Epic's ordinary discounts in the same list.
        cur = [o for o in cur if (o.get("discountSetting") or {}).get("discountPercentage") == 0]
        nxt = [o for o in nxt if (o.get("discountSetting") or {}).get("discountPercentage") == 0]
        if not cur and not nxt:
            continue
        it = epic_item(el, money)
        tp = (el.get("price") or {}).get("totalPrice") or {}
        it["original"] = money(tp.get("originalPrice"), tp.get("currencyCode", "EUR")) if tp.get("originalPrice") else ""
        if cur:
            end = _date(cur[0].get("endDate"))
            it["price"] = "Free until " + _day(end) if end else "Free"
            it["discount"] = 100 if it["original"] else 0
            it["offers"][0].update(price="Free", free=True, original=it["original"], until=it["price"])
            now.append(it)
        else:
            start = _date(nxt[0].get("startDate"))
            it["price"] = "Free from " + _day(start) if start else "Free soon"
            it["discount"] = 0
            it["upcoming"] = True
            soon.append(it)
    return now + soon


def epic_search(fetch_json, term, cc, money, count=12):
    """Epic's catalog search: the raw elements (games only)."""
    variables = {"keywords": term, "count": count, "country": cc, "locale": "en-US",
                 "category": EPIC_CATEGORY, "withPrice": True}
    url = EPIC_GRAPHQL + "?" + urllib.parse.urlencode({
        "operationName": "searchStoreQuery",
        "variables": json.dumps(variables),
        "extensions": json.dumps({"persistedQuery": {"version": 1, "sha256Hash": EPIC_SEARCH_HASH}}),
    })
    d = fetch_json(url)
    els = (((d.get("data") or {}).get("Catalog") or {}).get("searchStore") or {}).get("elements") or []
    return [e for e in els if e.get("offerType") in (None, "BASE_GAME", "BUNDLE", "EDITION")]


def epic_offer_for(fetch_json, title, cc, money):
    """Epic's offer for exactly this game (same title once normalized), or None."""
    want = norm_title(title)
    if not want:
        return None
    for el in epic_search(fetch_json, title, cc, money, count=6):
        if norm_title(el.get("title")) == want:
            return _epic_offer(el, money)
    return None
