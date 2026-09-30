"""The Steam store, read-only, through the public endpoints the Steam website itself uses:

  featuredcategories   specials / top sellers / new releases / coming soon
  featured             the banner: Steam's spotlight and popular new releases
  storesearch          search by name
  appdetails           one game's page (description, price, screenshots…)

No account, no key, no purchases: buying and wishlisting happen in the Steam client
(steam://store/<id>). Region and currency come from Steam's own detection (no cc= sent).
Requests are cached (memory + ~/.cache/carthage/store) and run in worker threads.
"""

import json
import os
import re
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

from PySide6.QtCore import Property, QObject, Signal, Slot

from . import shops
from .version import VERSION

API = "https://store.steampowered.com/api/"
CDN = "https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/{id}/{name}"
CACHE = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "carthage" / "store"
FEATURED_TTL = 30 * 60
SPOTLIGHT_SIZE = 10      # games in the banner
CHART_SIZE = 30          # games in "Most Played Right Now"
CATEGORY_SIZE = 60       # top sellers fetched per category
GAMES_ONLY = 998         # Steam search "category1" id for games (no DLC, software, videos)
BATCH_SIZE = 50          # apps per IStoreBrowseService/GetItems call
DETAILS_TTL = 24 * 3600
UA = f"Mozilla/5.0 (X11; Linux x86_64) Carthage/{VERSION}"

SECTIONS = [
    ("specials", "On Sale"),
    ("top_sellers", "Top Sellers"),
    ("new_releases", "New Releases"),
    ("coming_soon", "Coming Soon"),
]


# What "Hide adult content" leaves out: games with Steam's content descriptors for sexual
# content (1 some nudity or sexual content, 3 adult only sexual content, 4 frequent nudity
# or sexual content), or at least two of the user tags that mean the same (Sexual Content,
# Nudity, NSFW, Hentai). Tags are applied by users and one alone can be wrong (EA SPORTS FC
# carries Sexual Content), so one isn't enough.
ADULT_DESCRIPTORS = {1, 3, 4}
ADULT_TAGS = {12095, 6650, 24904, 9130}


_country = {"cc": None}
HARDWARE = re.compile(r"^Steam (Deck|Frame|Machine|Controller|Link|Index)\b", re.I)


def country():
    """The store country Steam detects for this connection (its steamCountry cookie), so
    prices are in the user's own currency. Asked once, then remembered."""
    if _country["cc"]:
        return _country["cc"]
    path = CACHE / "country"
    try:
        if path.exists() and time.time() - path.stat().st_mtime < 7 * 86400:
            _country["cc"] = path.read_text(encoding="utf-8").strip()
            return _country["cc"]
    except OSError:
        pass
    try:
        req = urllib.request.Request("https://store.steampowered.com/", method="HEAD", headers={"User-Agent": UA})
        with urllib.request.urlopen(req, timeout=10) as r:
            for c in r.headers.get_all("Set-Cookie") or []:
                if c.startswith("steamCountry="):
                    _country["cc"] = urllib.parse.unquote(c.split("=", 1)[1].split(";")[0]).split("|")[0]
    except (urllib.error.URLError, TimeoutError, OSError):
        pass
    if _country["cc"]:
        try:
            CACHE.mkdir(parents=True, exist_ok=True)
            path.write_text(_country["cc"], encoding="utf-8")
        except OSError:
            pass
    return _country["cc"] or "US"


FETCH_ERRORS = (urllib.error.URLError, TimeoutError, OSError, ValueError)
TIMEOUT = 15


def _fetch_json(url, params=None, timeout=TIMEOUT):
    if params:
        url += "?" + urllib.parse.urlencode(params)
    with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": UA}), timeout=timeout) as r:
        return json.load(r)


def _get(path, params):
    """A storefront API call in the user's language and country."""
    return _fetch_json(API + path, {**params, "l": "english", "cc": country()})


def _money(cents, currency):
    if cents is None:
        return ""
    sym = {"EUR": "€", "USD": "$", "GBP": "£", "BRL": "R$", "JPY": "¥"}.get(currency, "")
    value = f"{cents / 100:.2f}".replace(".", ",") if currency == "EUR" else f"{cents / 100:.2f}"
    return f"{value}{sym}" if currency == "EUR" else f"{sym}{value}"


def _art_urls(appid, sample_url=""):
    """Tall capsule + header URLs. Newer games keep assets under a hashed folder, so derive
    both from any asset URL the API gave us (same folder), else use the plain pattern."""
    m = re.match(r"(.*/apps/\d+/(?:[0-9a-f]{20,}/)?)[^/?]+", sample_url or "")
    if m:
        base = m.group(1)
        return base + "library_600x900_2x.jpg", base + "header.jpg"
    return CDN.format(id=appid, name="library_600x900_2x.jpg"), CDN.format(id=appid, name="header.jpg")


def _item(appid, name, final=None, original=None, discount=0, currency="EUR", free=False, sample=""):
    capsule, header = _art_urls(appid, sample)
    plain_capsule, plain_header = _art_urls(appid)
    # Tried in order until one loads (each asset may live in its own hashed folder, so
    # guesses can miss): plain capsule, header guesses, then the exact image Steam gave us.
    chain = [plain_capsule, header, plain_header, (sample or "").split("?")[0]]
    fallbacks = "|".join(u for u in dict.fromkeys(chain) if u and u != capsule)
    return {
        "appid": int(appid),
        "name": name,
        "price": "Free" if free or final == 0 else _money(final, currency),
        "original": _money(original, currency) if discount else "",
        "discount": int(discount or 0),
        "capsule": capsule,
        "header": fallbacks,
    }


ASSET_BASE = "https://shared.akamai.steamstatic.com/store_item_assets/"


def _batch(appids):
    """{appid: item} for many apps at once (IStoreBrowseService/GetItems): name, price and
    the *exact* art URLs (Steam keeps each asset in its own hashed folder, so guessing
    addresses misses)."""
    out = {}
    ids = [int(a) for a in dict.fromkeys(appids)]
    for i in range(0, len(ids), BATCH_SIZE):
        chunk = ids[i:i + BATCH_SIZE]
        req = {
            "ids": [{"appid": a} for a in chunk],
            "context": {"language": "english", "country_code": country()},
            "data_request": {"include_assets": True, "include_basic_info": True, "include_all_purchase_options": True,
                             "include_release": True, "include_tag_count": 20},
        }
        try:
            items = _fetch_json("https://api.steampowered.com/IStoreBrowseService/GetItems/v1/",
                                {"input_json": json.dumps(req)}, timeout=20).get("response", {}).get("store_items", [])
        except FETCH_ERRORS:
            continue
        for it in items:
            if not it.get("appid") or it.get("success", 1) != 1 or not it.get("name"):
                continue
            assets = it.get("assets") or {}
            rel = it.get("release") or {}
            b = it.get("best_purchase_option") or {}
            price = b.get("formatted_final_price") or ("Free" if it.get("is_free") or not b else "")
            tags = {t.get("tagid") for t in it.get("tags") or []}
            out[it["appid"]] = {
                "appid": it["appid"],
                "name": it["name"],
                "price": price,
                "original": b.get("formatted_original_price") or "" if b.get("discount_pct") else "",
                "discount": int(b.get("discount_pct") or 0),
                "capsule": _asset_url(assets, "library_capsule", "library_capsule_2x"),
                "capsuleLarge": _asset_url(assets, "library_capsule_2x", "library_capsule"),
                "header": _asset_url(assets, "header_2x", "header"),
                "hero": _asset_url(assets, "library_hero_2x", "library_hero", "hero_capsule_2x", "hero_capsule"),
                "comingSoon": bool(rel.get("is_coming_soon")),
                "releaseText": _release_text(rel),
                "adult": bool(ADULT_DESCRIPTORS & set(it.get("content_descriptorids") or []))
                         or len(ADULT_TAGS & tags) >= 2,
            }
    return out


def _asset_url(assets, *names):
    """The first of these art files the game has, as a full URL ("" if none)."""
    fmt = assets.get("asset_url_format", "")
    for n in names:
        if assets.get(n) and fmt:
            return ASSET_BASE + fmt.replace("${FILENAME}", assets[n])
    return ""


def _release_text(rel):
    """When an unreleased game comes out, as precisely as Steam says (for the label strip)."""
    import datetime

    if rel.get("custom_release_date_message"):
        return rel["custom_release_date_message"]
    ts = rel.get("steam_release_date")
    shown = rel.get("coming_soon_display", "")
    if not ts or shown in ("text_comingsoon", "text_tba", ""):
        return "Coming Soon" if shown != "text_tba" else "TBA"
    d = datetime.datetime.fromtimestamp(ts)
    # English month names whatever the system locale (strftime's %b follows the system language).
    month = "Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec".split()[d.month - 1]
    if shown == "date_year":
        return str(d.year)
    if shown == "date_quarter":
        return f"Q{(d.month - 1) // 3 + 1} {d.year}"
    if shown == "date_month":
        return f"{month} {d.year}"
    return f"{d.day} {month}"


def _with_art(items):
    """Replace guessed art with the exact URLs from the batch endpoint."""
    exact = _batch([i["appid"] for i in items])
    for i in items:
        e = exact.get(i["appid"])
        if e:
            if e["capsule"]:
                i["capsule"] = e["capsule"]
                i["capsuleLarge"] = e["capsuleLarge"]
            i["header"] = "|".join(u for u in (e["header"], i.get("header", "")) if u)
            i["hero"] = e["hero"]
            i["adult"] = e["adult"]
            if e.get("comingSoon"):
                # Not out yet: Steam lists a price of 0, which read as "Free".
                i["price"] = e["releaseText"]
                i["comingSoon"] = True
    return items


def _compact(n):
    return f"{n / 1_000_000:.1f}M" if n >= 1_000_000 else f"{n / 1000:.0f}k" if n >= 1000 else str(n)


def _strip_html(html):
    text = re.sub(r"<br\s*/?>", "\n", html or "")
    text = re.sub(r"<[^>]+>", "", text)
    from html import unescape  # (the argument is also called html)

    # Steam's text keeps HTML entities (&amp;, &quot;, &#39;…): turn them back into characters.
    return re.sub(r"\n{3,}", "\n\n", unescape(text)).strip()


class Store(QObject):
    featuredReady = Signal("QVariantList")  # [{key, title, items: [...]}]
    searchReady = Signal(str, "QVariantList")
    # A search or category that couldn't load: shown in its own grid, not as the store-wide
    # error.
    searchFailed = Signal(str)
    categoryFailed = Signal(int)
    detailsReady = Signal(int, "QVariantMap")
    failed = Signal(str)

    def __init__(self, owned_ids=set, hide_adult=lambda: True, parent=None, other_stores=lambda: False):
        super().__init__(parent)
        self._owned = owned_ids
        self._hide_adult = hide_adult
        self._featured = None
        self._featured_t = 0
        self._details = {}
        # appid → quiet, for detail fetches still running (a prefetch, or a page waiting).
        self._fetching = {}
        CACHE.mkdir(parents=True, exist_ok=True)
        self._cat_art = self._load_category_art()
        from .itad import Itad

        self._itad = Itad(CACHE, _money)  # used while "Other stores" is on (and there's a key)
        self._other_stores = other_stores

    def _shown(self, items):
        """What a list shows: adult games left out ("Hide adult content"), owned ones marked."""
        if self._hide_adult():
            items = [i for i in items if not i.get("adult")]
        owned = self._owned()
        for i in items:
            i["owned"] = i.get("appid") in owned
        return items

    def _shown_sections(self, sections):
        shown = [dict(sec, items=self._shown(sec["items"])) for sec in sections]
        return [sec for sec in shown if sec["items"]]

    def clear_cache(self):
        """Forget cached store data (memory and disk); returns bytes freed."""
        freed = 0
        for f in CACHE.glob("*"):
            if f.is_file():
                try:
                    freed += f.stat().st_size
                    f.unlink()
                except OSError:
                    pass
        self._featured, self._featured_t, self._details = None, 0, {}
        self._cat_art = {}
        _country["cc"] = None
        self.categoryArtChanged.emit()
        return freed

    @Slot()
    def loadFeatured(self):
        if self._featured and time.time() - self._featured_t < FEATURED_TTL:
            self.featuredReady.emit(self._shown_sections(self._featured))
            return

        def work():
            try:
                d = _get("featuredcategories", {})
            except FETCH_ERRORS:
                self.failed.emit("Something went wrong while loading the store.")
                return
            sections = []
            for key, title in SECTIONS:
                seen, items = set(), []
                for it in (d.get(key) or {}).get("items", []):
                    if it.get("id") in seen or it.get("type", 0) != 0 or HARDWARE.match(it.get("name", "")):
                        continue  # skip duplicates, bundles and Valve hardware
                    seen.add(it["id"])
                    items.append(_item(it["id"], it.get("name", ""), it.get("final_price"),
                                       it.get("original_price"), it.get("discount_percent"),
                                       it.get("currency", "EUR"), sample=it.get("header_image", "")))
                if items:
                    sections.append({"key": key, "title": title, "items": _with_art(items)})
            self._featured, self._featured_t = sections, time.time()
            self.featuredReady.emit(self._shown_sections(sections))

        threading.Thread(target=work, daemon=True).start()

    spotlightReady = Signal("QVariantList")
    chartsReady = Signal("QVariantList")

    @Slot()
    def loadSpotlight(self):
        """The banner at the top of the store: Steam's spotlight games, then its popular new
        releases. (Steam's own Featured & Recommended carousel is only filled in for a
        signed-in user.)"""
        def work():
            try:
                d = _get("featured/", {})
            except FETCH_ERRORS:
                return
            raw = (d.get("large_capsules") or []) + (d.get("featured_win") or [])
            seen, items = set(), []
            for it in raw:
                if it.get("id") in seen or HARDWARE.match(it.get("name", "")):
                    continue
                seen.add(it["id"])
                i = _item(it["id"], it.get("name", ""), it.get("final_price"), it.get("original_price"),
                          it.get("discount_percent"), it.get("currency", "EUR"), sample=it.get("header_image", ""))
                i["banner"] = it.get("large_capsule_image") or it.get("header_image", "")
                items.append(i)
            # All of them, so there are still enough once adult games are left out.
            items = _with_art(items)
            for i in items:
                i["banner"] = i.get("hero") or i["banner"]
            self.spotlightReady.emit(self._shown(items)[:SPOTLIGHT_SIZE])

        threading.Thread(target=work, daemon=True).start()

    @Slot()
    def loadCharts(self):
        """Most played right now (ISteamChartsService), top 30, with player counts."""
        def work():
            try:
                ranks = _fetch_json("https://api.steampowered.com/ISteamChartsService/GetGamesByConcurrentPlayers/v1/"
                                    ).get("response", {}).get("ranks", [])[:CHART_SIZE]
            except FETCH_ERRORS:
                return
            info = _batch([r["appid"] for r in ranks])
            items = []
            for r in ranks:
                i = info.get(r["appid"])
                if not i or HARDWARE.match(i["name"]):
                    continue
                i = dict(i, rank=r["rank"], players=_compact(r.get("concurrent_in_game", 0)),
                         peak=_compact(r.get("peak_in_game", 0)))
                items.append(i)
            self.chartsReady.emit(self._shown(items))

        threading.Thread(target=work, daemon=True).start()

    freeReady = Signal("QVariantList")

    @Slot()
    def loadFree(self):
        """Free for a limited time: Steam's 100%-off games, Epic's weekly free games, then
        Epic's next ones ("Free from …")."""
        def work():
            items = []
            try:
                raw = _fetch_json("https://store.steampowered.com/search/results/", {
                    "query": "", "start": 0, "count": 30, "maxprice": "free", "specials": 1,
                    "category1": GAMES_ONLY, "json": 1, "cc": country(), "l": "english"}).get("items", [])
                ids = [int(m.group(1)) for it in raw if (m := re.search(r"/apps/(\d+)/", it.get("logo", "")))]
                info = _batch(ids)
                for a in ids:
                    if a in info:
                        items.append(dict(info[a], price="Free", discount=100 if info[a].get("original") else 0))
            except FETCH_ERRORS:
                pass
            try:
                epic = shops.epic_free(_fetch_json, country(), _money)
            except FETCH_ERRORS:
                epic = []
            steam_titles = {shops.norm_title(i["name"]) for i in items}
            items += [e for e in epic if shops.norm_title(e["name"]) not in steam_titles]
            self.freeReady.emit(self._shown(items))

        threading.Thread(target=work, daemon=True).start()

    offersReady = Signal(str, "QVariantList")  # item key, [offer]

    @Slot(str, int, str, "QVariantMap")
    def loadOffers(self, key, appid, title, steam):
        """Every store selling this game, Steam's offer (`steam`, from the page) first, then
        the others cheapest first. Epic by exact title; the rest through IsThereAnyDeal
        when that's switched on."""
        def work():
            offers = []
            if appid:
                offers.append(dict(steam, store="steam", storeName=shops.STORES["steam"],
                                   url=f"steam://store/{appid}"))
            others = []
            try:
                e = shops.epic_offer_for(_fetch_json, title, country(), _money)
                if e:
                    others.append(e)
            except FETCH_ERRORS:
                pass
            if self._other_stores():
                others = self._itad.offers(appid, title, country(), others)
            offers += sorted(others, key=lambda o: (0 if o.get("free") else 1, o.get("cents", 1 << 30)))
            self.offersReady.emit(key, offers)

        threading.Thread(target=work, daemon=True).start()

    CATEGORIES = [
        ("Action", 19), ("Adventure", 21), ("RPG", 122), ("Strategy", 9), ("Simulation", 599),
        ("Puzzle", 1664), ("Platformer", 1625), ("Roguelike", 1716), ("Metroidvania", 1628),
        ("Horror", 1667), ("Survival", 1662), ("Open World", 1695), ("Shooter", 1774),
        ("Racing", 699), ("Sports", 701), ("Fighting", 1743), ("Co-op", 1685), ("Cozy", 97376),
        ("Farming Sim", 87918), ("Visual Novel", 3799), ("JRPG", 4434), ("Indie", 492),
        ("Casual", 597), ("Free to Play", 113),
    ]

    @Property("QVariantMap", constant=True)
    def storeNames(self):
        """store key → display name ("epic" → "Epic Games")."""
        return dict(shops.STORES)

    @Property("QVariantList", constant=True)
    def categories(self):
        return [{"name": n, "tag": t} for n, t in self.CATEGORIES]

    categoryReady = Signal(int, "QVariantList")  # tag, items
    categoryArtChanged = Signal()

    def _load_category_art(self):
        try:
            return json.loads((CACHE / "category_art.json").read_text(encoding="utf-8"))
        except (OSError, ValueError):
            return {}

    @Property("QVariantMap", notify=categoryArtChanged)
    def categoryArt(self):
        """{tag: image url} — each category's top game, once the category has been opened."""
        return dict(self._cat_art)

    def _remember_category_art(self, tag, items):
        """Use the category's best-selling game whose art no other tile already shows (never an
        adult game's: the tiles are cached for a week, whatever the setting is then)."""
        taken = {v for k, v in self._cat_art.items() if k != str(tag) and not k.startswith("_")}
        arts = [i.get("hero") or i.get("header", "").split("|")[0] for i in items if not i.get("adult")]
        art = next((a for a in arts if a and a not in taken), "")
        if not art or self._cat_art.get(str(tag)) == art:
            return
        self._cat_art[str(tag)] = art
        try:
            (CACHE / "category_art.json").write_text(json.dumps(self._cat_art), encoding="utf-8")
        except OSError:
            pass
        self.categoryArtChanged.emit()

    CATEGORY_ART_TTL = 7 * 86400

    @Slot()
    def loadAllCategoryArt(self):
        """Fill in art for every category tile, in the background, one category at a time
        (a small search per category); refreshed weekly."""
        if getattr(self, "_art_job", False):
            return
        fresh = time.time() - self._cat_art.get("_t", 0) < self.CATEGORY_ART_TTL
        todo = [t for _n, t in self.CATEGORIES if not (fresh and str(t) in self._cat_art)]
        if not todo:
            return
        self._art_job = True

        def work():
            try:
                for tag in todo:
                    items = self._category_items(tag, count=12)
                    if items:
                        self._remember_category_art(tag, items)
                    time.sleep(0.3)  # be gentle with Steam
                self._cat_art["_t"] = time.time()
                try:
                    (CACHE / "category_art.json").write_text(json.dumps(self._cat_art), encoding="utf-8")
                except OSError:
                    pass
            finally:
                self._art_job = False

        threading.Thread(target=work, daemon=True).start()

    def _category_items(self, tag, count=CATEGORY_SIZE):
        try:
            raw = _fetch_json("https://store.steampowered.com/search/results/", {
                "query": "", "start": 0, "count": count, "tags": tag, "filter": "topsellers",
                "category1": GAMES_ONLY, "json": 1, "cc": country(), "l": "english"}).get("items", [])
        except FETCH_ERRORS:
            return None
        ids = []
        for it in raw:
            m = re.search(r"/apps/(\d+)/", it.get("logo", ""))
            if m and not HARDWARE.match(it.get("name", "")):
                ids.append(int(m.group(1)))
        info = _batch(ids)
        return [info[i] for i in ids if i in info]

    @Slot(int)
    def loadCategory(self, tag):
        """Top sellers in one category (Steam's store search filtered by tag)."""
        def work():
            items = self._category_items(tag)
            if items is None:
                self.categoryFailed.emit(tag)
                return
            self.categoryReady.emit(tag, self._shown(items))
            self._remember_category_art(tag, items)

        threading.Thread(target=work, daemon=True).start()

    @Slot(str)
    def search(self, term):
        term = term.strip()

        def work():
            if len(term) < 2:
                self.searchReady.emit(term, [])
                return
            try:
                d = _get("storesearch/", {"term": term})
            except FETCH_ERRORS:
                self.searchFailed.emit(term)
                return
            items = []
            for it in d.get("items", []):
                if it.get("type") != "app" or HARDWARE.match(it.get("name", "")) or "Soundtrack" in it.get("name", ""):
                    continue
                p = it.get("price") or {}
                items.append(_item(it["id"], it.get("name", ""), p.get("final"), p.get("initial"),
                                   round(100 - 100 * p["final"] / p["initial"]) if p.get("initial") else 0,
                                   p.get("currency", "EUR"), free=not p, sample=it.get("tiny_image", "")))
            items = _with_art(items)
            try:
                epic = shops.epic_search(_fetch_json, term, country(), _money)
            except FETCH_ERRORS:
                epic = []
            on_steam = {shops.norm_title(i["name"]) for i in items}
            for el in epic:
                t = shops.norm_title(el.get("title"))
                if t and t not in on_steam:
                    on_steam.add(t)
                    items.append(shops.epic_item(el, _money))
            self.searchReady.emit(term, self._shown(items))

        threading.Thread(target=work, daemon=True).start()

    @Slot(int)
    def loadDetails(self, appid):
        self._load_details(appid, quiet=False)

    @Slot(int)
    def loadDetailsQuiet(self, appid):
        """For the library's closer look: same data, but a game without a store page
        (delisted, region-locked) just shows nothing extra instead of an error."""
        self._load_details(appid, quiet=True)

    @Slot(int)
    def prefetchDetails(self, appid):
        """Fetch a game's details ahead of time (the store page's neighbours), so stepping to
        it shows them at once. Quiet: nothing is shown, and a failure says nothing."""
        cached = self._details.get(appid)
        if appid and appid not in self._fetching and not (cached and time.time() - cached[0] < DETAILS_TTL):
            self._load_details(appid, quiet=True)

    def _load_details(self, appid, quiet):
        cached = self._details.get(appid)
        if cached and time.time() - cached[0] < DETAILS_TTL:
            self.detailsReady.emit(appid, cached[1])
            return
        if appid in self._fetching:
            # Already on its way (e.g. prefetched): that fetch reports it, loudly if a page
            # is now waiting for it.
            self._fetching[appid] = self._fetching[appid] and quiet
            return
        self._fetching[appid] = quiet

        def work():
            try:
                fetch()
            finally:
                self._fetching.pop(appid, None)

        def fetch():
            path = CACHE / f"{appid}.json"
            data = None
            try:
                if path.exists() and time.time() - path.stat().st_mtime < DETAILS_TTL:
                    data = json.loads(path.read_text(encoding="utf-8"))
            except (OSError, ValueError):
                data = None
            if data is None:
                try:
                    raw = _get("appdetails", {"appids": appid})
                    entry = next(iter(raw.values())) if raw else {}
                    if not entry.get("success"):
                        raise ValueError("no data")
                    data = entry["data"]
                    path.write_text(json.dumps(data), encoding="utf-8")
                except FETCH_ERRORS + (StopIteration,):
                    if not self._fetching.get(appid, quiet):
                        self.failed.emit("Couldn't load this game's store page.")
                    return
            po = data.get("price_overview") or {}
            rel = data.get("release_date") or {}
            info = {
                "appid": appid,
                "name": data.get("name", ""),
                "developer": ", ".join(data.get("developers") or []),
                "publisher": ", ".join(data.get("publishers") or []),
                "released": rel.get("date", ""),
                "comingSoon": bool(rel.get("coming_soon")),
                "free": bool(data.get("is_free")),
                "price": "Free" if data.get("is_free") else po.get("final_formatted", ""),
                "original": po.get("initial_formatted", "") if po.get("discount_percent") else "",
                "discount": int(po.get("discount_percent") or 0),
                "description": _strip_html(data.get("short_description", "")),
                "genres": [g.get("description", "") for g in data.get("genres") or []][:4],
                "linux": bool((data.get("platforms") or {}).get("linux")),
                "screenshots": [s.get("path_thumbnail", "") for s in data.get("screenshots") or []][:12],
                "screenshotsFull": [s.get("path_full", "") for s in data.get("screenshots") or []][:12],
                "movies": [{"thumb": m.get("thumbnail", ""), "name": m.get("name", ""),
                            # Steam streams trailers as HLS now (older entries had mp4/webm files).
                            "url": m.get("hls_h264") or (m.get("mp4") or {}).get("max")
                                   or (m.get("mp4") or {}).get("480") or (m.get("webm") or {}).get("max") or ""}
                           for m in data.get("movies") or []][:4],
                "about": _strip_html(data.get("about_the_game") or data.get("detailed_description") or "")[:4000],
                "features": [c.get("description", "") for c in data.get("categories") or []][:12],
                "languages": _strip_html((data.get("supported_languages") or "").replace("<strong>*</strong>", "")).split(",")
                             if data.get("supported_languages") else [],
                "controller": {"full": "Full controller support", "partial": "Partial controller support"}.get(
                    data.get("controller_support") or "", ""),
                "achievements": int((data.get("achievements") or {}).get("total") or 0),
                "dlcCount": len(data.get("dlc") or []),
                "metacritic": int((data.get("metacritic") or {}).get("score") or 0),
                "metacriticUrl": (data.get("metacritic") or {}).get("url") or "",
                "ageRating": int(data.get("required_age") or 0),
                "website": data.get("website") or "",
                "requirements": _strip_html(((data.get("linux_requirements") or {}) if isinstance(data.get("linux_requirements"), dict)
                                             else {}).get("minimum", "")
                                            or ((data.get("pc_requirements") or {}) if isinstance(data.get("pc_requirements"), dict)
                                                else {}).get("minimum", "")).replace("Minimum:", "").strip()[:1200],
                "reviews": "",
                "reviewPct": -1,
                "reviewCount": "",
                "capsule": _art_urls(appid, data.get("header_image", ""))[0],
                "header": data.get("header_image", ""),
                "owned": appid in self._owned(),
            }
            try:
                rv = _fetch_json(f"https://store.steampowered.com/appreviews/{appid}",
                                 {"json": 1, "language": "all", "purchase_type": "all", "num_per_page": 0},
                                 timeout=10).get("query_summary", {})
                total = int(rv.get("total_reviews") or 0)
                if total:
                    info["reviews"] = rv.get("review_score_desc", "")
                    info["reviewPct"] = round(100 * int(rv.get("total_positive") or 0) / total)
                    info["reviewCount"] = _compact(total)
            except FETCH_ERRORS:
                pass
            self._details[appid] = (time.time(), info)
            self.detailsReady.emit(appid, info)

        threading.Thread(target=work, daemon=True).start()

    extrasReady = Signal(str, "QVariantMap")  # key (gameId), {players}

    @Slot(str, int, str)
    def loadExtras(self, key, appid, title):
        """Players right now (Steam games)."""
        def work():
            out = {}
            if appid:
                players = _players_now(appid)
                if players:
                    out["players"] = _compact(players)
            self.extrasReady.emit(key, out)

        threading.Thread(target=work, daemon=True).start()


def _players_now(appid):
    """How many people are playing right now (public Steam API, no key)."""
    try:
        r = _fetch_json("https://api.steampowered.com/ISteamUserStats/GetNumberOfCurrentPlayers/v1/",
                        {"appid": appid}, timeout=10).get("response", {})
        return int(r.get("player_count") or 0) if r.get("result") == 1 else 0
    except FETCH_ERRORS:
        return 0
