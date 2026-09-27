"""Cartridge art: fetched once in the background, cached on disk, never blocking the UI.

For each game, the first that works (DESIGN.md §4):
  1. SteamGridDB square grid (static, no NSFW / humor), best voted, preferring styles
     that keep the game's logo
  2. "logo on hero": the game's transparent logo over its wide background art, cropped
     square (both from SteamGridDB)
  3. Steam's own local library art (appcache/librarycache/<appid>/library_hero.jpg)
  4. the launcher's local cover (Lutris coverart)
  5. nothing → the generated placeholder stays

Cached as 640×640 JPEGs in ~/.cache/carthage/art/. Misses are remembered for a week so
Carthage doesn't ask SteamGridDB about the same game on every start.
"""

import io
import json
import os
import queue
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

import numpy as np
from PIL import Image
from PySide6.QtCore import Property, QObject, Signal, Slot

from . import keys

CACHE = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "carthage" / "art"
INDEX = CACHE / "index.json"
SIZE = 640
MISS_TTL = 7 * 86400
INDEX_VERSION = 2
ORIG_MAX = 1280
# The cartridge's art window (theme.GEOMETRY["art"]): what the crop is framed for.
ART_ASPECT = 512 / 454
API = "https://www.steamgriddb.com/api/v2/"
STYLE_RANK = {"alternate": 0, "white_logo": 1, "material": 2, "blurred": 3, "no_logo": 4}
WORKERS = 4


def _safe(game_id):
    return "".join(c if c.isalnum() or c in "-_" else "_" for c in game_id)


STEAM_CDN = "https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/{appid}/{name}"


class ArtManager(QObject):
    ready = Signal(str)  # game_id whose art changed
    progressChanged = Signal()
    regenerated = Signal()  # all automatic art was dropped (e.g. the art source changed)

    def __init__(self, library, prefer_official=lambda: False, settings=None, parent=None):
        super().__init__(parent)
        self._library = library
        self._prefer_official = prefer_official
        self._settings = settings  # for user-chosen SteamGridDB matches (sgdbIds)
        self._lock = threading.Lock()
        self._queued = set()
        self._q = queue.Queue()
        CACHE.mkdir(parents=True, exist_ok=True)
        try:
            self._index = json.loads(INDEX.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            self._index = {}
        if self._index.get("_version") != INDEX_VERSION:
            # Older caches: no originals kept, no clean-art filter. Keep only hand-picked art.
            self._index = {k: v for k, v in self._index.items()
                           if isinstance(v, dict) and v.get("source") == "chosen" and v.get("orig")}
            self._index["_version"] = INDEX_VERSION
        for _ in range(WORKERS):
            threading.Thread(target=self._worker, daemon=True).start()

    # ------------------------------------------------------------ lookup

    def path_for(self, game_id):
        """The cached art file, or None (and fetching is queued if it makes sense)."""
        entry = self._index.get(game_id)
        if not isinstance(entry, dict):
            entry = None
        if entry and entry.get("file"):
            p = CACHE / entry["file"]
            if p.exists():
                return p
        if entry and not entry.get("file") and time.time() - entry.get("t", 0) < MISS_TTL:
            return None
        self.request(game_id)
        return None

    def request(self, game_id):
        with self._lock:
            if game_id in self._queued:
                return
            self._queued.add(game_id)
        self._q.put(game_id)
        self.progressChanged.emit()

    def prefetch(self, game_ids):
        """Queue everything that has no art (or remembered miss) yet, all at once — so fetching
        happens up front instead of trickling in while the user is idle."""
        now = time.time()
        for gid in game_ids:
            e = self._index.get(gid)
            if isinstance(e, dict) and (e.get("file") or now - e.get("t", 0) < MISS_TTL):
                continue
            self.request(gid)

    @Property(int, notify=progressChanged)
    def pending(self):
        return len(self._queued)

    @Slot()
    def retryMissing(self):
        """Forget remembered misses so they're looked up again."""
        with self._lock:
            for k in [k for k, v in self._index.items() if isinstance(v, dict) and not v.get("file")]:
                del self._index[k]
            self._write_index()
        self.regenerated.emit()

    def clear_cache(self):
        """Delete every downloaded image except hand-picked art (and its original); returns
        bytes freed. Automatic art is fetched again right after."""
        with self._lock:
            keep = {INDEX.name}
            for k, v in list(self._index.items()):
                if isinstance(v, dict) and v.get("source") == "chosen":
                    keep.update(x for x in (v.get("file"), v.get("orig")) if x)
                elif not k.startswith("_"):
                    del self._index[k]
            freed = 0
            for f in CACHE.iterdir():
                if f.is_file() and f.name not in keep:
                    try:
                        freed += f.stat().st_size
                        f.unlink()
                    except OSError:
                        pass
            self._write_index()
        self.regenerated.emit()
        return freed

    def drop_automatic(self):
        """Forget every automatic pick (hand-picked art stays), e.g. when the source preference changes."""
        with self._lock:
            for k in [k for k, v in self._index.items() if isinstance(v, dict) and v.get("source") != "chosen"]:
                del self._index[k]
            self._write_index()
        self.regenerated.emit()

    # ------------------------------------------------------------ work

    def _worker(self):
        while True:
            gid = self._q.get()
            try:
                g = self._library.game(gid)
                if g is not None:
                    img, source = self._find(g)
                    self._store(gid, img, source)
            except Exception:
                pass
            finally:
                with self._lock:
                    self._queued.discard(gid)
                self.progressChanged.emit()

    def _store(self, gid, img, source, crop=None):
        """img is the original (uncropped) image; the cartridge crop is derived from it."""
        entry = {"t": int(time.time()), "source": source}
        if img is not None:
            orig = img.convert("RGB")
            if max(orig.size) > ORIG_MAX:
                orig.thumbnail((ORIG_MAX, ORIG_MAX), Image.LANCZOS)
            orig_name = _safe(gid) + ".orig.jpg"
            orig.save(CACHE / orig_name, "JPEG", quality=92)
            crop = crop or {"cx": 0.5, "cy": 0.5, "zoom": 1.0}
            name = _safe(gid) + ".jpg"
            _crop(orig, **crop).save(CACHE / name, "JPEG", quality=90, optimize=True)
            entry.update(file=name, orig=orig_name, crop=crop)
        with self._lock:
            self._index[gid] = entry
            tmp = INDEX.with_suffix(".tmp")
            tmp.write_text(json.dumps(self._index), encoding="utf-8")
            os.replace(tmp, INDEX)
        if img is not None:
            self.ready.emit(gid)

    def _find(self, g):
        if g.source == "carthage":
            return None, "none"  # the Test Cartridge keeps its generated art
        if g.source == "steam" and self._prefer_official():
            img = self._steam_official(g.ext_id)
            if img:
                return img, "official"
        key = keys.get("steamgrid")
        sgdb_ids = None
        if key:
            sgdb_ids = self._ids_for(key, g)
        if sgdb_ids:
            img = self._square_grid(key, *sgdb_ids)
            if img:
                return img, "sgdb"
            img = self._logo_on_hero(key, *sgdb_ids)
            if img:
                return img, "sgdb-composite"
        if g.source == "steam":
            img = self._steam_local(g.ext_id)
            if img:
                return img, "steam-local"
        if g.cover and Path(g.cover).exists():
            return Image.open(g.cover), "local-cover"
        return None, "none"

    # ------------------------------------------------------------ SteamGridDB

    def _get(self, key, path):
        req = urllib.request.Request(API + path, headers={"Authorization": f"Bearer {key}", "User-Agent": "Carthage/0.1"})
        try:
            with urllib.request.urlopen(req, timeout=15) as r:
                d = json.load(r)
            return d.get("data") if d.get("success") else None
        except (urllib.error.URLError, TimeoutError, OSError, ValueError):
            return None

    def _download(self, url):
        req = urllib.request.Request(url, headers={"User-Agent": "Carthage/0.1"})
        with urllib.request.urlopen(req, timeout=30) as r:
            return Image.open(io.BytesIO(r.read()))

    def _search(self, key, title):
        data = self._get(key, "search/autocomplete/" + urllib.parse.quote(title))
        return ("game", data[0]["id"]) if data else None

    def _ids_for(self, key, g):
        """Which SteamGridDB entry a game uses: the user's pick, else Steam's id, else a search."""
        chosen = self._settings.get("sgdbIds").get(g.game_id) if self._settings else None
        if chosen:
            return ("game", chosen)
        return ("steam", g.ext_id) if g.source == "steam" else self._search(key, g.title)

    @staticmethod
    def _best(items, styled=True):
        items = [i for i in items if not i.get("epilepsy") and not i.get("nsfw") and not i.get("humor")]

        def rank(i):
            votes = i.get("upvotes", 0) - i.get("downvotes", 0)
            return (-votes, STYLE_RANK.get(i.get("style"), 5) if styled else 0)

        return sorted(items, key=rank)

    def _square_grid(self, key, kind, ident):
        data = self._get(key, f"grids/{kind}/{ident}?dimensions=512x512,1024x1024&types=static&nsfw=false&humor=false")
        fallback = None
        for item in self._best(data or [])[:4]:
            try:
                img = self._download(item["url"])
            except (urllib.error.URLError, TimeoutError, OSError, ValueError):
                continue
            # Prefer clean art: skip rounded "card" images (transparent corners) and ones with a
            # solid frame — both usually carry a store badge. "Change Art…" covers misses.
            if _clean(img):
                return img
            fallback = fallback or img
        return fallback

    def _logo_on_hero(self, key, kind, ident):
        heroes = self._best(self._get(key, f"heroes/{kind}/{ident}?types=static&nsfw=false&humor=false") or [], False)
        logos = self._best(self._get(key, f"logos/{kind}/{ident}?types=static&nsfw=false&humor=false") or [], False)
        if not heroes or not logos:
            return None
        try:
            return _compose(self._download(heroes[0]["url"]), self._download(logos[0]["url"]))
        except (urllib.error.URLError, TimeoutError, OSError, ValueError):
            return None

    # ------------------------------------------------------------ Change Art…

    candidatesReady = Signal(str, "QVariantList")  # game_id, [{id, thumb, url, style}]
    choiceFailed = Signal(str, str)  # game_id, message

    # Picker tabs → SteamGridDB query. Any shape can be chosen; Reposition frames it.
    KINDS = {
        "square": ("grids", "dimensions=512x512,1024x1024&"),
        "portrait": ("grids", "dimensions=600x900,342x482,660x930&"),
        "wide": ("grids", "dimensions=460x215,920x430&"),
        "banner": ("heroes", ""),
    }
    NAMES = {"square": "square art", "portrait": "portrait art", "wide": "wide art", "banner": "banners"}

    searchResults = Signal(str, "QVariantList")  # term, [{id, name, year}]

    @Slot(str)
    def searchGames(self, term):
        """Search SteamGridDB for any game, for the picker's search box."""
        key = keys.get("steamgrid")

        def work():
            data = self._get(key, "search/autocomplete/" + urllib.parse.quote(term)) if key and term.strip() else []
            items = []
            for d in (data or [])[:12]:
                year = time.gmtime(d["release_date"]).tm_year if d.get("release_date") else ""
                items.append({"id": d["id"], "name": d.get("name", ""), "year": str(year)})
            self.searchResults.emit(term, items)

        threading.Thread(target=work, daemon=True).start()

    @Slot(str, int)
    def useSgdbGame(self, game_id, sgdb_id):
        """Remember that this game matches a SteamGridDB entry (also used for automatic art)."""
        if self._settings is None:
            return
        ids = dict(self._settings.get("sgdbIds"))
        ids[game_id] = sgdb_id
        self._settings.set("sgdbIds", ids)

    @Slot(str, str)
    def chooseFile(self, game_id, path):
        """Use an image file from disk as the art."""
        def work():
            try:
                img = Image.open(path)
                img.load()
            except (OSError, ValueError):
                self.choiceFailed.emit(game_id, "That file isn't an image Carthage can read.")
                return
            self._store(game_id, img, "chosen")
            self.chosen.emit(game_id)

        threading.Thread(target=work, daemon=True).start()

    # ------------------------------------------------------------ game logos (cartridge header)

    logoReady = Signal(str)

    def logo_path(self, game_id):
        p = CACHE / (_safe(game_id) + ".logo.png")
        if p.exists():
            return p
        self.fetch_logo(game_id)
        return None

    @Slot(str)
    def fetch_logo_slot(self, game_id):
        self.fetch_logo(game_id)

    def fetch_logo(self, game_id):
        g = self._library.game(game_id)
        if g is None or (CACHE / (_safe(game_id) + ".logo.png")).exists():
            return

        def work():
            img = None
            if g.source == "steam":
                try:
                    img = self._download(STEAM_CDN.format(appid=g.ext_id, name="logo.png"))
                except (urllib.error.URLError, TimeoutError, OSError, ValueError):
                    img = None
            key = keys.get("steamgrid")
            if img is None and key:
                ids = self._ids_for(key, g)
                logos = self._best(self._get(key, f"logos/{ids[0]}/{ids[1]}?types=static&nsfw=false&humor=false") or [], False) if ids else []
                if logos:
                    try:
                        img = self._download(logos[0]["url"])
                    except (urllib.error.URLError, TimeoutError, OSError, ValueError):
                        img = None
            if img is not None:
                img = img.convert("RGBA")
                bbox = img.getbbox()  # trim transparent margins
                if bbox:
                    img = img.crop(bbox)
                img.thumbnail((800, 300), Image.LANCZOS)
                img.save(CACHE / (_safe(game_id) + ".logo.png"))
                self.logoReady.emit(game_id)

        threading.Thread(target=work, daemon=True).start()

    @Slot(str, str)
    def loadCandidates(self, game_id, kind="square"):
        g = self._library.game(game_id)
        key = keys.get("steamgrid")
        endpoint, dims = self.KINDS.get(kind, self.KINDS["square"])

        def work():
            if g is None or not key:
                self.choiceFailed.emit(game_id, "Add your SteamGridDB key in the menu to choose art.")
                return
            ids = self._ids_for(key, g)
            data = self._get(key, f"{endpoint}/{ids[0]}/{ids[1]}?{dims}types=static&nsfw=false&humor=false") if ids else None
            if not data:
                self.choiceFailed.emit(game_id, f"SteamGridDB has no {self.NAMES.get(kind, 'art')} for this game.")
                return
            items = [
                {"id": str(i["id"]), "thumb": i["thumb"], "url": i["url"], "style": i.get("style", ""),
                 "square": abs(i.get("width", 1) - i.get("height", 1)) < 8}
                for i in self._best(data, styled=endpoint == "grids")[:36]
            ]
            self.candidatesReady.emit(game_id, items)

        threading.Thread(target=work, daemon=True).start()

    @Slot(str, result="QVariantMap")
    def cropInfo(self, game_id):
        """For the reposition editor: the original image and the current crop."""
        e = self._index.get(game_id) or {}
        orig = CACHE / e["orig"] if e.get("orig") else None
        if not orig or not orig.exists():
            return {}
        return {"url": orig.as_uri() + f"?t={e.get('t', 0)}", "aspect": ART_ASPECT, **e.get("crop", {})}

    @Slot(str, float, float, float)
    def setCrop(self, game_id, cx, cy, zoom):
        e = self._index.get(game_id) or {}
        if not e.get("orig"):
            return

        def work():
            try:
                orig = Image.open(CACHE / e["orig"]).convert("RGB")
            except OSError:
                return
            crop = {"cx": cx, "cy": cy, "zoom": max(1.0, min(4.0, zoom))}
            _crop(orig, **crop).save(CACHE / e["file"], "JPEG", quality=90, optimize=True)
            with self._lock:
                e["crop"] = crop
                e["t"] = int(time.time())
                self._write_index()
            self.ready.emit(game_id)

        threading.Thread(target=work, daemon=True).start()

    def _write_index(self):
        tmp = INDEX.with_suffix(".tmp")
        tmp.write_text(json.dumps(self._index), encoding="utf-8")
        os.replace(tmp, INDEX)

    @Slot(str)
    def reset(self, game_id):
        """Back to the automatic pick."""
        with self._lock:
            self._index.pop(game_id, None)
        self.request(game_id)

    chosen = Signal(str)  # game_id, after a picked image is stored

    @Slot(str, str)
    def choose(self, game_id, url):
        def work():
            try:
                img = self._download(url)
            except (urllib.error.URLError, TimeoutError, OSError, ValueError):
                self.choiceFailed.emit(game_id, "Couldn't download that image. Try again.")
                return
            self._store(game_id, img, "chosen")
            self.chosen.emit(game_id)

        threading.Thread(target=work, daemon=True).start()

    # ------------------------------------------------------------ official Steam art

    def _steam_official(self, appid):
        """Steam's own store art: the banner with the game's logo on it (built like the
        logo-on-hero composite), else the tall library cover, else the header."""
        def get(name):
            try:
                return self._download(STEAM_CDN.format(appid=appid, name=name))
            except (urllib.error.URLError, TimeoutError, OSError, ValueError):
                return None

        hero, logo = get("library_hero.jpg"), get("logo.png")
        if hero and logo:
            return _compose(hero, logo)
        for name in ("library_600x900_2x.jpg", "library_600x900.jpg", "header.jpg"):
            img = get(name)
            if img:
                return img
        return None

    # ------------------------------------------------------------ local fallbacks

    def _steam_local(self, appid):
        from .sources import steam

        root = steam.find_root()
        if not root:
            return None
        d = root / "appcache" / "librarycache" / str(appid)
        for name in ("library_600x900.jpg", "library_hero.jpg", "header.jpg"):
            p = d / name
            if p.exists():
                try:
                    return Image.open(p)
                except OSError:
                    pass
        return None


def _clean(img):
    """Cheap, one-time check at download: no transparent corners and no solid frame."""
    if img.mode in ("RGBA", "LA") or "transparency" in img.info:
        a = img.convert("RGBA").getchannel("A")
        w, h = img.size
        if min(a.getpixel(p) for p in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1))) < 200:
            return False
    arr = np.asarray(img.convert("RGB").resize((128, 128)), dtype=np.float32)
    n = 3
    strips = [arr[1:1 + n, 4:-4], arr[-1 - n:-1, 4:-4], arr[4:-4, 1:1 + n], arr[4:-4, -1 - n:-1]]
    means = [x.reshape(-1, 3).mean(0) for x in strips]
    uniform = sum(x.reshape(-1, 3).std(0).mean() < 12 for x in strips)
    similar = max(float(np.abs(m - means[0]).max()) for m in means) < 30
    return not (uniform >= 3 and similar)


def _compose(hero, logo):
    """A banner cropped square with the game's logo over its lower middle."""
    hero = _square(hero)
    logo = logo.convert("RGBA")
    scale = min(SIZE * 0.8 / logo.width, SIZE * 0.4 / logo.height)
    logo = logo.resize((max(1, int(logo.width * scale)), max(1, int(logo.height * scale))), Image.LANCZOS)
    canvas = hero.convert("RGBA")
    shade = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shade.putalpha(Image.linear_gradient("L").resize((SIZE, SIZE)).point(lambda v: int(v * 0.55)))
    canvas = Image.alpha_composite(canvas, shade)
    canvas.alpha_composite(logo, ((SIZE - logo.width) // 2, int(SIZE * 0.62 - logo.height / 2)))
    return canvas


def _crop(img, cx=0.5, cy=0.5, zoom=1.0):
    """The part of the original shown on the cartridge: the largest ART_ASPECT rectangle,
    shrunk by zoom, centered on (cx, cy) as fractions of the image, kept inside it."""
    w, h = img.size
    cw = min(w, h * ART_ASPECT) / zoom
    ch = cw / ART_ASPECT
    x = min(max(cx * w - cw / 2, 0), w - cw)
    y = min(max(cy * h - ch / 2, 0), h - ch)
    out_w = SIZE
    out_h = round(SIZE / ART_ASPECT)
    return img.crop((round(x), round(y), round(x + cw), round(y + ch))).resize((out_w, out_h), Image.LANCZOS)


def _square(img):
    """Center-crop to a square and scale to SIZE."""
    img = img.convert("RGBA") if img.mode in ("P", "LA") else img
    w, h = img.size
    s = min(w, h)
    img = img.crop(((w - s) // 2, (h - s) // 2, (w - s) // 2 + s, (h - s) // 2 + s))
    return img.resize((SIZE, SIZE), Image.LANCZOS)
