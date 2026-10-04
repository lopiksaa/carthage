"""Application startup and dev-mode live reload. (The test harness is tools/harness/, outside the app.)"""

import os
import signal
import sys
from pathlib import Path

from PySide6.QtCore import QFileSystemWatcher, QTimer, QUrl
from PySide6.QtGui import QIcon, QSurfaceFormat
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuickControls2 import QQuickStyle
from PySide6.QtWidgets import QApplication

from . import card3d  # noqa: F401 — registers CardGeometry for QML ("import Carthage")
from . import chrome
from .backend import Backend
from .render import ImageProvider

APP_ID = "io.github.lopiksa.Carthage"
QML_DIR = Path(__file__).resolve().parent / "qml"


def _watch_qml(engine, root):
    """Dev mode: reload the window's content whenever a QML file changes."""
    watcher = QFileSystemWatcher()
    debounce = QTimer()
    debounce.setSingleShot(True)
    debounce.setInterval(150)

    def rewatch():
        files = [str(p) for p in QML_DIR.glob("*.qml")]
        if watcher.files():
            watcher.removePaths(watcher.files())
        watcher.addPaths(files)

    def reload():
        rewatch()  # editors often replace files, which drops them from the watch list
        engine.clearComponentCache()
        root.setProperty("reloadCount", root.property("reloadCount") + 1)
        print("[dev] QML reloaded", flush=True)

    watcher.addPath(str(QML_DIR))
    rewatch()
    watcher.fileChanged.connect(lambda _: debounce.start())
    watcher.directoryChanged.connect(lambda _: debounce.start())
    debounce.timeout.connect(reload)
    return watcher, debounce


def _first_instance(app, name):
    """True if no other Carthage is running. Otherwise the running one is asked to come to the
    front, and this one should quit. (The packaged app takes a few seconds to appear on Windows;
    clicking its shortcut again used to open a second and a third Carthage.)"""
    from PySide6.QtNetwork import QLocalServer, QLocalSocket

    sock = QLocalSocket()
    sock.connectToServer(name)
    if sock.waitForConnected(500):
        if os.name == "nt":
            import ctypes

            ctypes.windll.user32.AllowSetForegroundWindow(-1)  # ASFW_ANY: it may take the front
        sock.write(b"show\n")
        sock.waitForBytesWritten(500)
        sock.disconnectFromServer()
        return False
    QLocalServer.removeServer(name)  # a leftover from a crash (Linux keeps a socket file)
    server = QLocalServer(app)
    server.listen(name)
    app._instance_server = server  # kept alive with the app
    return True


def _come_forward(server, root):
    """Another launch asked for Carthage: show the window that's already open."""
    while server.hasPendingConnections():
        server.nextPendingConnection().deleteLater()
    if root.visibility() == root.Visibility.Minimized:
        root.showNormal()
    root.show()
    root.raise_()
    root.requestActivate()


def start(argv=None, games=None):
    """Build the app, the backend and the window: (app, engine, root, backend); None if the
    window couldn't load; False if Carthage was already running (it was brought to the front).
    `games`: a library to use instead of the real one (the test harness)."""
    argv = list(sys.argv if argv is None else argv)
    from . import log

    log.setup()
    dev = "--dev" in argv

    # Tagged as a game, not a notification, so Carthage's sounds get their own volume slider.
    os.environ.setdefault(
        "PIPEWIRE_PROPS",
        '{ media.role = "Game" application.name = "Carthage" application.icon-name = "applications-games" }',
    )
    if os.name == "nt":
        # The taskbar groups and pins Carthage by this ID (the installer's shortcuts use it
        # too).
        import ctypes

        ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID("lopiksa.Carthage")
    fmt = QSurfaceFormat.defaultFormat()
    fmt.setSamples(4)
    QSurfaceFormat.setDefaultFormat(fmt)
    QQuickStyle.setStyle(chrome.STYLE)
    app = QApplication(argv)
    app.setApplicationName("carthage")
    app.setApplicationDisplayName("Carthage")
    app.setOrganizationName("lopiksa")
    app.setDesktopFileName(APP_ID)
    # The PNG, not the SVG: Qt's SVG renderer ignores clip-path, so the art window's light
    # circles would spill over the cartridge body.
    app.setWindowIcon(QIcon(str(Path(__file__).resolve().parent / "assets" / "icons" / "carthage-512.png")))
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    # One Carthage at a time (dev mode and test runs may run beside it).
    if not dev and not os.environ.get("GC_DEMO"):
        import getpass

        if not _first_instance(app, "carthage-" + getpass.getuser()):
            return False

    backend = Backend(games=games)
    chrome.setup(app)
    chrome.apply(app, backend.theme.dark)
    backend.theme.changed.connect(lambda: chrome.apply(app, backend.theme.dark))
    from PySide6.QtQml import qmlRegisterSingletonInstance

    qmlRegisterSingletonInstance(Backend, "Carthage", 1, 0, "Backend", backend)
    engine = QQmlApplicationEngine()
    provider = ImageProvider(backend.library, backend.art)
    backend.image_provider = provider
    provider.header_custom = backend.header_custom
    engine.addImageProvider("gc", provider)
    engine.rootContext().setContextProperty("devMode", dev)
    engine.load(QUrl.fromLocalFile(str(QML_DIR / "Main.qml")))
    if not engine.rootObjects():
        return None
    root = engine.rootObjects()[0]
    if dev:
        app._dev_watch = _watch_qml(engine, root)  # kept alive with the app
    server = getattr(app, "_instance_server", None)
    if server is not None:
        server.newConnection.connect(lambda: _come_forward(server, root))
    return app, engine, root, backend


def main(argv=None):
    started = start(argv)
    if started is False:
        return 0  # handed over to the Carthage that's already running
    if started is None:
        return 1
    return started[0].exec()
