"""API keys: stored in the system's password store (secretstore.py), never in a file, never logged.

Keys are sent only to their own service:
  steam      → api.steampowered.com   (Steam Web API)
  steamgrid  → www.steamgriddb.com    (SteamGridDB)
  itad       → api.isthereanydeal.com (IsThereAnyDeal, for the store's other stores)

All keyring and network calls run in worker threads; results come back via signals.
"""

import json
import threading
import urllib.error
import urllib.request

from PySide6.QtCore import Property, QObject, Signal, Slot

from . import secretstore

LABELS = {"steam": "Carthage: Steam Web API key", "steamgrid": "Carthage: SteamGridDB API key",
          "itad": "Carthage: IsThereAnyDeal API key"}
TIMEOUT = 10


def _lookup(service):
    try:
        return secretstore.lookup(service)
    except Exception:  # keyring locked/unavailable
        return ""


def get(service):
    """Blocking read, for worker threads that need a key."""
    return _lookup(service)


def _check_steam(key, steam_id):
    if not steam_id:
        return False, "Couldn't find your Steam account on this PC to test the key with."
    url = (
        "https://api.steampowered.com/IPlayerService/GetOwnedGames/v1/"
        f"?key={key}&steamid={steam_id}&include_played_free_games=1&format=json"
    )
    try:
        with urllib.request.urlopen(url, timeout=TIMEOUT) as r:
            data = json.load(r).get("response", {})
    except urllib.error.HTTPError as e:
        if e.code in (401, 403):
            return False, "Steam didn't accept this key. Check it was copied completely."
        return False, f"Steam answered with an error ({e.code}). Try again later."
    except (urllib.error.URLError, TimeoutError, OSError):
        return False, "Couldn't reach Steam. Check your internet connection."
    except ValueError:
        return False, "Steam sent an unexpected answer. Try again later."
    if "game_count" not in data:
        return False, "Key works, but your game list is private. In Steam: Profile → Privacy → Game details: Public."
    return True, f"Key works — {data['game_count']} games in your library."


def _check_steamgrid(key):
    req = urllib.request.Request(
        "https://www.steamgriddb.com/api/v2/grids/steam/220?dimensions=512x512",
        headers={"Authorization": f"Bearer {key}", "User-Agent": "Carthage/0.1"},
    )
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
            ok = json.load(r).get("success")
    except urllib.error.HTTPError as e:
        if e.code in (401, 403):
            return False, "SteamGridDB didn't accept this key. Check it was copied completely."
        return False, f"SteamGridDB answered with an error ({e.code}). Try again later."
    except (urllib.error.URLError, TimeoutError, OSError):
        return False, "Couldn't reach SteamGridDB. Check your internet connection."
    except ValueError:
        return False, "SteamGridDB sent an unexpected answer. Try again later."
    return (True, "Key works.") if ok else (False, "SteamGridDB didn't accept this key.")


class Keys(QObject):
    """QML-facing key store. `status` per service: "", "checking", "ok", "error"."""

    changed = Signal()

    def __init__(self, steam_id_fn, parent=None):
        super().__init__(parent)
        self._steam_id = steam_id_fn
        self._has = {"steam": False, "steamgrid": False, "itad": False}
        self._status = {"steam": "", "steamgrid": "", "itad": ""}
        self._message = {"steam": "", "steamgrid": "", "itad": ""}
        # A check that failed for reasons other than the key (offline, service down): setup
        # then lets you go on without it for now.
        self._unreachable = {"steam": False, "steamgrid": False, "itad": False}
        self._steam_found = False
        self._results = []  # delivered to the UI thread via _deliver
        self._refresh()

    def _run(self, fn):
        def work():
            fn()
            self._deliver.emit()

        threading.Thread(target=work, daemon=True).start()

    _deliver = Signal()

    def _refresh(self):
        def work():
            has = {s: bool(_lookup(s)) for s in self._has}
            self._results.append(("has", has))
            try:
                found = bool(self._steam_id())
            except Exception:
                found = False
            self._results.append(("steam", found))

        self._deliver.connect(self._apply)
        self._run(work)

    @Slot()
    def _apply(self):
        while self._results:
            kind, data = self._results.pop(0)
            if kind == "has":
                self._has.update(data)
            elif kind == "steam":
                self._steam_found = data
            elif kind == "status":
                service, status, message, stored = data
                self._status[service] = status
                self._message[service] = message
                self._unreachable[service] = status == "error" and message.startswith(("Couldn't reach", "Couldn't save", "Couldn't find"))
                if status == "error" and (" answered with an error " in message or "unexpected answer" in message
                                          or "is busy" in message):
                    self._unreachable[service] = True
                if stored is not None:
                    self._has[service] = stored
        self.changed.emit()

    def _set_status(self, service, status, message, stored=None):
        self._results.append(("status", (service, status, message, stored)))

    @Property("QVariantMap", notify=changed)
    def has(self):
        return dict(self._has)

    @Property("QVariantMap", notify=changed)
    def status(self):
        return dict(self._status)

    @Property("QVariantMap", notify=changed)
    def message(self):
        return dict(self._message)

    @Property("QVariantMap", notify=changed)
    def unreachable(self):
        return dict(self._unreachable)

    @Property(bool, notify=changed)
    def steamFound(self):
        """A Steam account on this PC (the Steam key needs one to be checked with)."""
        return self._steam_found

    @Slot(str, str)
    def save(self, service, key):
        """Check the key with its service, and store it in the keyring only if it works."""
        key = "".join(key.split())  # pasted keys often carry spaces/newlines
        if service not in self._has or not key:
            return
        self._status[service] = "checking"
        self._message[service] = "Checking…"
        self.changed.emit()

        def work():
            if service == "steam":
                ok, msg = _check_steam(key, self._steam_id())
            elif service == "itad":
                from .itad import check_key

                ok, msg = check_key(key)
            else:
                ok, msg = _check_steamgrid(key)
            # A private game list still means the key itself is valid: keep it.
            valid = ok or "private" in msg
            if valid:
                try:
                    secretstore.store(service, LABELS[service], key)
                except Exception:
                    ok, msg, valid = False, "Couldn't save to your keyring. Is it unlocked?", False
            self._set_status(service, "ok" if ok else "error", msg, True if valid else None)

        self._run(work)

    @Slot(str)
    def remove(self, service):
        def work():
            try:
                secretstore.clear(service)
            except Exception:
                pass
            self._set_status(service, "", "Key removed.", False)

        self._run(work)
