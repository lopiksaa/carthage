"""Updates: compares this version with the latest release on the public download repo
(github.com/lopiksaa/carthage) and installs newer ones by itself.

  Windows   downloads the new setup .exe; it installs silently on "Restart Now", or when
            Carthage quits. (The installer closes Carthage and, when asked with /RELAUNCH,
            starts it again.)
  Linux     the AppImage (install.sh installs one): the new AppImage replaces the old file
            ($APPIMAGE) straight away; the next start is the new version.
  Other     (the tarball, or running from source): only says a new version is out, with a
            link to the release page.

Every download is checked against the SHA-256 GitHub publishes for it before it's used.
Only reads GitHub's public API and downloads; nothing about the user is sent. Checks at
startup (after a short delay) and every 6 hours; all network and disk work runs in a
worker thread.
"""

import hashlib
import json
import os
import re
import subprocess
import sys
import threading
import urllib.error
import urllib.request
from pathlib import Path

from PySide6.QtCore import Property, QCoreApplication, QObject, QTimer, Signal, Slot

from .version import VERSION

REPO = "lopiksaa/carthage"
API = f"https://api.github.com/repos/{REPO}/releases/latest"
PAGE = f"https://github.com/{REPO}/releases/latest"
CACHE = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "carthage" / "update"
UA = f"Carthage/{VERSION}"
ERRORS = (urllib.error.URLError, TimeoutError, OSError, ValueError)


def _parse(v):
    return tuple(int(x) for x in re.findall(r"\d+", v or "")[:3]) or (0,)


def _install_kind():
    """How this copy can update itself: "windows", "appimage" or "" (it can't)."""
    if not getattr(sys, "frozen", False):
        return ""  # running from source
    if sys.platform == "win32":
        return "windows"
    image = os.environ.get("APPIMAGE", "")
    if image and os.path.isfile(image) and os.access(os.path.dirname(image), os.W_OK):
        return "appimage"
    return ""


def _asset(release, kind):
    suffix = {"windows": "-windows-setup.exe", "appimage": "-linux-x86_64.AppImage"}.get(kind)
    for a in release.get("assets") or []:
        if suffix and a.get("name", "").endswith(suffix) and (a.get("digest") or "").startswith("sha256:"):
            return a
    return None


class Updater(QObject):
    changed = Signal()
    _result = Signal(object)
    _state_from_worker = Signal(str, float, str)  # state, progress, path

    def __init__(self, enabled=lambda: True, parent=None):
        super().__init__(parent)
        self._enabled = enabled
        self._kind = _install_kind()
        self._latest = ""
        self._url = PAGE
        self._checking = False
        self._state = ""       # "" | "downloading" | "ready" | "failed"
        self._progress = 0.0
        self._file = ""        # the downloaded installer (Windows)
        self._launched = False
        self._result.connect(self._apply)
        self._state_from_worker.connect(self._set_state)
        threading.Thread(target=self._clean, daemon=True).start()
        QCoreApplication.instance().aboutToQuit.connect(self._install_on_quit)
        QTimer.singleShot(8000, self.check)
        t = QTimer(self)
        t.timeout.connect(self.check)
        t.start(6 * 3600 * 1000)

    def _clean(self):
        """Leftovers from earlier updates: downloaded installers and a half-swapped AppImage.
        (The cache folder only ever holds update downloads.)"""
        try:
            for f in CACHE.glob("*"):
                if f.is_file():
                    f.unlink()
        except OSError:
            pass
        image = os.environ.get("APPIMAGE", "")
        if self._kind == "appimage" and image:
            try:
                Path(image + ".new").unlink(missing_ok=True)
            except OSError:
                pass

    @Slot()
    def check(self):
        if self._checking or self._state in ("downloading", "ready") or not self._enabled():
            return
        self._checking = True
        self.changed.emit()

        def work():
            try:
                req = urllib.request.Request(API, headers={"User-Agent": UA, "Accept": "application/vnd.github+json"})
                with urllib.request.urlopen(req, timeout=15) as r:
                    self._result.emit(json.load(r))
            except ERRORS:
                self._result.emit(None)

        threading.Thread(target=work, daemon=True).start()

    def _apply(self, data):
        self._checking = False
        if data:
            self._latest = (data.get("tag_name") or "").lstrip("v")
            self._url = data.get("html_url") or PAGE
            if self.available and self._kind:
                asset = _asset(data, self._kind)
                if asset:
                    self._download(asset)
        self.changed.emit()

    def _download(self, asset):
        self._state, self._progress = "downloading", 0.0
        kind, latest = self._kind, self._latest

        def work():
            try:
                CACHE.mkdir(parents=True, exist_ok=True)
                part = CACHE / (asset["name"] + ".part")
                digest = hashlib.sha256()
                req = urllib.request.Request(asset["browser_download_url"], headers={"User-Agent": UA})
                with urllib.request.urlopen(req, timeout=30) as r, open(part, "wb") as out:
                    total = int(r.headers.get("Content-Length") or asset.get("size") or 0)
                    done, last = 0, -1.0
                    while chunk := r.read(1 << 20):
                        out.write(chunk)
                        digest.update(chunk)
                        done += len(chunk)
                        if total and done / total - last >= 0.02:
                            last = done / total
                            self._state_from_worker.emit("downloading", last, "")
                if "sha256:" + digest.hexdigest() != asset["digest"]:
                    part.unlink(missing_ok=True)
                    raise ValueError("download doesn't match its checksum")
                if kind == "appimage":
                    # Next to the old one, then swapped in one step (the running copy keeps
                    # working: it's already mounted).
                    image = Path(os.environ["APPIMAGE"])
                    staged = image.with_name(image.name + ".new")
                    _copy(part, staged)  # (the cache may be on another drive)
                    part.unlink(missing_ok=True)
                    staged.chmod(0o755)
                    os.replace(staged, image)
                    path = str(image)
                else:
                    final = CACHE / asset["name"]
                    os.replace(part, final)
                    path = str(final)
                self._state_from_worker.emit("ready", 1.0, path)
            except ERRORS:
                self._state_from_worker.emit("failed", 0.0, "")

        threading.Thread(target=work, daemon=True).start()
        self.changed.emit()

    @Slot(str, float, str)
    def _set_state(self, state, progress, path):
        self._state, self._progress = state, progress
        if path:
            self._file = path
        self.changed.emit()

    def _run_installer(self, relaunch):
        if self._launched or self._kind != "windows" or self._state != "ready" or not self._file:
            return
        self._launched = True
        args = [self._file, "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/SP-"]
        if relaunch:
            args.append("/RELAUNCH")
        flags = getattr(subprocess, "DETACHED_PROCESS", 0) | getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0)
        try:
            subprocess.Popen(args, creationflags=flags, close_fds=True)
        except OSError:
            self._launched = False

    def _install_on_quit(self):
        self._run_installer(relaunch=False)

    @Slot()
    def restartNow(self):
        """Start the new version: Windows installs it (and reopens Carthage); Linux reopens
        the already replaced AppImage."""
        if self._state != "ready":
            return
        if self._kind == "windows":
            self._run_installer(relaunch=True)
            if not self._launched:
                return
        elif self._kind == "appimage":
            try:
                subprocess.Popen([self._file], start_new_session=True, close_fds=True)
            except OSError:
                return
        QCoreApplication.quit()

    @Property(str, constant=True)
    def version(self):
        return VERSION

    @Property(str, notify=changed)
    def latest(self):
        return self._latest

    @Property(bool, notify=changed)
    def available(self):
        return bool(self._latest) and _parse(self._latest) > _parse(VERSION)

    @Property(bool, constant=True)
    def automatic(self):
        """This copy installs updates by itself (else it only links to the download)."""
        return bool(self._kind)

    @Property(str, notify=changed)
    def state(self):
        return self._state

    @Property(float, notify=changed)
    def progress(self):
        return self._progress

    @Property(bool, notify=changed)
    def checking(self):
        return self._checking

    @Slot()
    def download(self):
        from PySide6.QtCore import QUrl
        from PySide6.QtGui import QDesktopServices

        QDesktopServices.openUrl(QUrl(self._url))


def _copy(src, dst):
    import shutil

    shutil.copyfile(src, dst)
