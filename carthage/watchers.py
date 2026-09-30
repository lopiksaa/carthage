"""Background watchers feeding the UI: Steam's status, the library's files and installs.

Every scan runs in a worker thread; results come back to the UI thread via signals.
"""

import os
import threading
import time
import traceback

from PySide6.QtCore import Property, QFileSystemWatcher, QObject, QTimer, Signal, Slot

from .library import real_games


class LibraryWatcher(QObject):
    """Reloads the real library (in a worker thread) when a launcher's files change —
    e.g. a game finishes installing in Steam, or one is added in Heroic or Lutris."""

    loaded = Signal(object)
    failed = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._watcher = QFileSystemWatcher(self)
        self._debounce = QTimer(self)
        self._debounce.setSingleShot(True)
        self._debounce.setInterval(1500)
        self._debounce.timeout.connect(self.reload)
        self._watcher.directoryChanged.connect(self._dir_changed)
        self._watcher.fileChanged.connect(lambda _: self._debounce.start())
        self._owned_changed.connect(self.reload)
        self._busy = False
        self._rewatch()
        self._owned_timer = QTimer(self)
        self._owned_timer.timeout.connect(self.refresh_owned)
        self._owned_timer.start(3 * 3600 * 1000)
        QTimer.singleShot(1500, self.refresh_owned)

    def refresh_owned(self, force=False):
        def work():
            from . import keys
            from .sources import steam

            _, t = steam.owned_cache()
            key = keys.get("steam")
            root = steam.find_root()
            sid = steam.steam_id64(root) if root else None
            if key and sid and (force or time.time() - t > 60) and steam.refresh_owned(key, sid):
                self._owned_changed.emit()

        threading.Thread(target=work, daemon=True).start()

    _owned_changed = Signal()

    def _dir_changed(self, path):
        from .sources import manual

        # Without games.json (no game added by hand yet) its folder is watched instead; that
        # is also where settings.json is saved, and a settings change is no reason to reload.
        games_file = manual.path()
        if path == str(games_file.parent) and not games_file.exists():
            return
        self._debounce.start()

    def _rewatch(self):
        from .sources import desktop, heroic, lutris, manual, steam

        paths = []
        root = steam.find_root()
        if root:
            paths += steam.watch_paths(root)
        for src in (heroic, lutris, desktop, manual):
            paths += src.watch_paths()
        old = self._watcher.files() + self._watcher.directories()
        if old:
            self._watcher.removePaths(old)
        paths = [p for p in dict.fromkeys(paths) if os.path.exists(p)]
        if paths:
            self._watcher.addPaths(paths)

    def reload(self):
        if self._busy:
            self._debounce.start()
            return
        self._busy = True

        def work():
            try:
                self.loaded.emit(real_games())
            except Exception:  # a broken file must never take the app down
                self.failed.emit(traceback.format_exc(limit=3))
            finally:
                self._busy = False

        threading.Thread(target=work, daemon=True).start()
        self._rewatch()  # editors/Steam replace files, which drops them from the watch


class InstallWatch(QObject):
    """Progress of games being installed, polled every 2 s off the UI thread."""

    changed = Signal()
    _result = Signal(object)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._progress = {}
        self._busy = False
        self._result.connect(self._apply)
        t = QTimer(self)
        t.timeout.connect(self._poll)
        t.start(2000)
        QTimer.singleShot(500, self._poll)

    def _poll(self):
        if self._busy:
            return
        self._busy = True

        def work():
            from .sources import steam

            try:
                self._result.emit({f"steam_{a}": p for a, p in steam.installing().items()})
            except Exception:
                self._result.emit(None)

        threading.Thread(target=work, daemon=True).start()

    def _apply(self, result):
        self._busy = False
        if result is not None and result != self._progress:
            self._progress = result
            self.changed.emit()

    @Property("QVariantMap", notify=changed)
    def progress(self):
        return dict(self._progress)

    @Slot(str, float)
    def simulate(self, game_id, fraction):
        """Demo harness only: pretend a game is installing."""
        self._progress = dict(self._progress, **{game_id: fraction})
        self._busy = True  # stop real polls from overwriting the simulation
        self.changed.emit()
