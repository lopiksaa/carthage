"""Carthage's test harness: runs the app from a list of timed steps, for scripted screenshots
and checks. Not part of the app or the downloads (the build packs only the carthage package).

    python tools/harness/run.py steps.json            # the demo library (demo_library.py)
    python tools/harness/run.py steps.json --real     # your real library (launches still blocked)

Each step: {"at": ms, "do": "<command>", ...} or {"at": ms, "shot": "file.png"}. Times count
from the first frame. Commands here: fps_start, fps_stop, exit, drag, click, move, genres; every other
command goes to Commands.qml. QT_QPA_PLATFORM=offscreen runs without a window (at the design
size); GC_SCREEN=<screen name> opens it on that screen.

A test run never saves settings or play time, never sends anything and never starts a real
game: the app's own guards check GC_DEMO, which this sets.
"""

import json
import os
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent.parent))  # the project, for `import carthage`
sys.path.insert(0, str(HERE))


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        sys.exit(__doc__)
    script = Path(args[0]).resolve()
    os.environ["GC_DEMO"] = str(script)  # switches on the app's test-run guards

    from PySide6.QtCore import Q_ARG, QMetaObject, QObject, QPoint, Qt, QTimer, QUrl, Slot
    from PySide6.QtGui import QGuiApplication
    from PySide6.QtQml import QQmlComponent, QQmlEngine
    from PySide6.QtQuick import QQuickItem
    from PySide6.QtTest import QTest

    from carthage.app import start

    games = None
    if "--real" not in sys.argv:
        from demo_library import demo_games

        games = demo_games()
    started = start([sys.argv[0]], games=games)
    if started is None:
        return 1
    app, engine, root, backend = started

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

    class Helper(QObject):
        """What Commands.qml can't do from QML: find a part by objectName, move the real pointer."""

        @Slot(str, result=QObject)
        def find(self, name):
            return root.findChild(QObject, name)

        @Slot(float, float)
        def mouseMove(self, x, y):
            QTest.mouseMove(root, QPoint(int(x), int(y)))

        @Slot(str, float)
        def install(self, game_id, fraction):
            """Pretend a game is installing (needs --real: the demo library has no install watch)."""
            watch = backend._install
            if watch is not None:
                watch._progress = dict(watch._progress, **{game_id: fraction})
                watch._busy = True  # stop real polls from overwriting the simulation
                watch.changed.emit()

        @Slot(str)
        def finishInstall(self, game_id):
            """An install finishes: the library reloads with the game installed (demo library only)."""
            if backend._fake:
                games = list(backend._library._games)
                for g in games:
                    if g.game_id == game_id:
                        g.installed = True
                backend._library.reset(games)

    helper = Helper()
    commands = None

    def attach():
        nonlocal commands
        app_item = root.findChild(QQuickItem, "app")
        comp = QQmlComponent(engine, QUrl.fromLocalFile(str(HERE / "Commands.qml")))
        commands = comp.createWithInitialProperties({"app": app_item, "harness": helper})
        if commands is None:
            print("[harness] Commands.qml didn't load:", comp.errorString(), flush=True)
            return
        # Ours, not QML's: its garbage collector would otherwise delete it (nothing in QML uses it).
        QQmlEngine.setObjectOwnership(commands, QQmlEngine.ObjectOwnership.CppOwnership)
        commands.setParent(root)

    steps = json.loads(script.read_text(encoding="utf-8"))
    timers = []
    state = {"frames": 0, "t": 0.0, "started": False}

    def drag(step):
        x0, y0, dx, dy = step["x"], step["y"], step["dx"], step.get("dy", 0)
        QTest.mousePress(root, Qt.LeftButton, Qt.NoModifier, QPoint(x0, y0))
        for i in range(1, 13):
            QTest.mouseMove(root, QPoint(int(x0 + dx * i / 12), int(y0 + dy * i / 12)), 12)
        if step.get("release", True):
            QTest.mouseRelease(root, Qt.LeftButton, Qt.NoModifier, QPoint(x0 + dx, y0 + dy), 10)

    def fire(step):
        if step.get("do") == "fps_start":
            state["frames"] = 0
            state["worst"] = 0.0
            state["t"] = state["last"] = time.monotonic()
        elif step.get("do") == "fps_stop":
            secs = time.monotonic() - state["t"]
            print(f"[harness] {state['frames']} frames in {secs:.2f}s = {state['frames'] / secs:.1f} fps, "
                  f"worst frame {state['worst'] * 1000:.1f} ms", flush=True)
        elif "shot" in step:
            root.grabWindow().save(step["shot"])
            print("[harness] shot", step["shot"], flush=True)
        elif step.get("do") == "size":  # {"w": 1900, "h": 1020}: the window's size
            root.resize(step["w"], step["h"])
        elif step.get("do") == "exit":
            app.quit()
        elif step.get("do") == "drag":  # press, move in steps, optionally release
            drag(step)
        elif step.get("do") == "genres":  # {"map": {gameId: [tag, …]}} as if the genre lookup finished
            backend._apply_genres(step["map"])
        elif step.get("do") == "move":  # the real pointer to window coordinates
            QTest.mouseMove(root, QPoint(step["x"], step["y"]))
        elif step.get("do") == "click":  # a real mouse click at window coordinates
            button = Qt.RightButton if step.get("button") == "right" else Qt.LeftButton
            QTest.mouseClick(root, button, Qt.NoModifier, QPoint(step["x"], step["y"]))
        elif step.get("do") == "dblclick":
            QTest.mouseDClick(root, Qt.LeftButton, Qt.NoModifier, QPoint(step["x"], step["y"]))
        elif step.get("do") == "key":  # {"key": "Escape", "mods": "ctrl+shift"} a real key press
            mods = Qt.NoModifier
            for m in (step.get("mods") or "").split("+"):
                mods |= {"ctrl": Qt.ControlModifier, "shift": Qt.ShiftModifier, "alt": Qt.AltModifier}.get(m, Qt.NoModifier)
            key = getattr(Qt, "Key_" + step["key"])
            QTest.keyClick(root, key, mods)
        elif step.get("do") == "type":  # {"text": "hollow"} types into whatever has focus
            for ch in step["text"]:
                QTest.keyClick(root, ch)
        elif step.get("do") == "wheel":  # {"x", "y", "dy": -120 per notch down}
            from PySide6.QtCore import QPointF
            from PySide6.QtGui import QWheelEvent
            pos = QPointF(step["x"], step["y"])
            for _ in range(step.get("notches", 1)):
                ev = QWheelEvent(pos, root.mapToGlobal(pos), QPoint(0, 0), QPoint(0, step.get("dy", -120)),
                                 Qt.NoButton, Qt.NoModifier, Qt.NoScrollPhase, False)
                QGuiApplication.sendEvent(root, ev)
        elif step.get("do") in ("clickText", "hoverText", "rightClickText"):  # {"text": "Play", "nth": 0}
            hits = []

            def walk(item):
                if not item.isVisible() or item.opacity() <= 0.01:
                    return
                t = item.property("text")
                if isinstance(t, str) and t.strip() == step["text"]:
                    r = item.mapRectToScene(item.boundingRect())
                    if r.width() > 0 and 0 <= r.center().x() < root.width() and 0 <= r.center().y() < root.height():
                        hits.append(r.center())
                for c in item.childItems():
                    walk(c)

            walk(root.contentItem())
            for popup_root in root.contentItem().childItems():
                pass
            n = step.get("nth", 0)
            if len(hits) > n:
                pt = QPoint(int(hits[n].x()), int(hits[n].y()))
                QTest.mouseMove(root, pt)
                if step["do"] == "clickText":
                    QTest.mouseClick(root, Qt.LeftButton, Qt.NoModifier, pt)
                elif step["do"] == "rightClickText":
                    QTest.mouseClick(root, Qt.RightButton, Qt.NoModifier, pt)
                print(f"[harness] {step['do']} {step['text']!r} at {pt.x()},{pt.y()}", flush=True)
            else:
                print(f"[harness] MISSING {step['text']!r} ({len(hits)} found)", flush=True)
        elif commands is not None:
            QMetaObject.invokeMethod(commands, "run", Qt.DirectConnection, Q_ARG("QVariant", step))

    def begin():
        attach()
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
            QTimer.singleShot(0, begin)

    root.frameSwapped.connect(on_frame)
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
