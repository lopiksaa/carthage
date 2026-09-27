"""Application startup, dev-mode live reload and the scripted demo/screenshot harness."""

import json
import os
import signal
import time
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


def _run_demo(app, root, script_path):
    """GC_DEMO=steps.json: timed commands for automated visual checks.

    Each step: {"at": ms, "do": "<command>", ...} or {"at": ms, "shot": "file.png"}.
    Commands are forwarded to App.qml's demo() function.
    """
    from PySide6.QtGui import QGuiApplication

    wanted = os.environ.get("GC_SCREEN", "")
    screen = next((sc for sc in QGuiApplication.screens() if sc.name() == wanted), None)
    if screen is not None and os.environ.get("QT_QPA_PLATFORM") != "offscreen":
        geo = screen.availableGeometry()
        root.setScreen(screen)
        root.setPosition(geo.x() + (geo.width() - root.width()) // 2, geo.y() + (geo.height() - root.height()) // 2)
    elif os.environ.get("QT_QPA_PLATFORM") == "offscreen":
        # The offscreen screen is small; checks compare shots at the design size.
        root.setWidth(1180)
        root.setHeight(820)

    steps = json.loads(Path(script_path).read_text(encoding="utf-8"))
    timers = []
    state = {"frames": 0, "t": 0.0, "started": False}

    def fire(step):
        if step.get("do") == "fps_start":
            state["frames"] = 0
            state["worst"] = 0.0
            state["t"] = state["last"] = time.monotonic()
        elif step.get("do") == "fps_stop":
            secs = time.monotonic() - state["t"]
            print(f"[demo] {state['frames']} frames in {secs:.2f}s = {state['frames'] / secs:.1f} fps, "
                  f"worst frame {state['worst'] * 1000:.1f} ms", flush=True)
        elif "shot" in step:
            root.grabWindow().save(step["shot"])
            print("[demo] shot", step["shot"], flush=True)
        elif step.get("do") == "exit":
            app.quit()
        elif step.get("do") == "drag":  # press, move in steps, optionally release
            from PySide6.QtCore import QPoint, Qt
            from PySide6.QtTest import QTest

            x0, y0, dx, dy = step["x"], step["y"], step["dx"], step.get("dy", 0)
            QTest.mousePress(root, Qt.LeftButton, Qt.NoModifier, QPoint(x0, y0))
            for i in range(1, 13):
                QTest.mouseMove(root, QPoint(int(x0 + dx * i / 12), int(y0 + dy * i / 12)), 12)
            if step.get("release", True):
                QTest.mouseRelease(root, Qt.LeftButton, Qt.NoModifier, QPoint(x0 + dx, y0 + dy), 10)
        elif step.get("do") == "click":  # a real mouse click at window coordinates
            from PySide6.QtCore import QPoint, Qt
            from PySide6.QtTest import QTest

            button = Qt.RightButton if step.get("button") == "right" else Qt.LeftButton
            QTest.mouseClick(root, button, Qt.NoModifier, QPoint(step["x"], step["y"]))
        else:
            root.setProperty("demoCommand", json.dumps(step))

    def start():
        # Step times count from the first frame on screen, not from process start.
        for step in steps:
            t = QTimer()
            t.setSingleShot(True)
            t.timeout.connect(lambda step=step: fire(step))
            t.start(step["at"])
            timers.append(t)

    def on_frame():
        now = time.monotonic()
        state["worst"] = max(state.get("worst", 0.0), now - state.get("last", now))
        state["last"] = now
        state["frames"] += 1
        if not state["started"]:
            state["started"] = True
            QTimer.singleShot(0, start)

    root.frameSwapped.connect(on_frame)
    return timers


def main(argv=None):
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
    chrome.before_app()
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

    fake = "--fake" in argv or bool(os.environ.get("GC_FAKE_COUNT")) or (
        bool(os.environ.get("GC_DEMO")) and not os.environ.get("GC_REAL")
    )
    backend = Backend(fake=fake)
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
        return 1
    root = engine.rootObjects()[0]

    keep = []
    if dev:
        keep.append(_watch_qml(engine, root))
    if os.environ.get("GC_DEMO"):
        keep.append(_run_demo(app, root, os.environ["GC_DEMO"]))

    return app.exec()
