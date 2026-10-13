"""Carthage's test harness: runs the app from a list of timed steps, for scripted screenshots
and checks. Not part of the app or the downloads (the build packs only the carthage package).

    python tools/harness/run.py steps.json            # the demo library (demo_library.py)
    python tools/harness/run.py steps.json --real     # your real library (launches still blocked)

Each step: {"at": ms, "do": "<command>", ...} or {"at": ms, "shot": "file.png"}. Times count
from the first frame. Commands here: fps_start, fps_stop, exit, drag, click, move, genres; every other
command goes to Commands.qml. QT_QPA_PLATFORM=offscreen runs without a window (at the design
size); GC_SCREEN=<screen name> opens it on that screen. GC_RECORD=<file.mp4> records every frame from
the first one to the end (needs ffmpeg): animations then advance one screen refresh per frame
(QML_FIXED_ANIMATION_STEP), so the video is exact however long grabbing takes; timed steps still
run on the clock. (Screen capture on XWayland skipped animation frames.)

A test run never saves settings or play time, never sends anything and never starts a real
game: the app's own guards check GC_DEMO, which this sets.
"""

import json
import os
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent.parent))  # the project, for `import carthage`
sys.path.insert(0, str(HERE))


def main():
    if os.environ.get("GC_RECORD"):
        os.environ["QML_FIXED_ANIMATION_STEP"] = "1"  # (read when the app starts)
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        sys.exit(__doc__)
    script = Path(args[0]).resolve()
    os.environ["GC_DEMO"] = str(script)  # switches on the app's test-run guards

    from PySide6.QtCore import Q_ARG, QMetaObject, QObject, QPoint, Qt, QTimer, QUrl, Slot
    from PySide6.QtGui import QGuiApplication, QImage
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
    if wanted and screen is None and os.environ.get("QT_QPA_PLATFORM") != "offscreen":
        # Never fall back to the main screen: a test window there lands on whoever is using it.
        names = ", ".join(sc.name() for sc in QGuiApplication.screens())
        print(f"[harness] no screen called {wanted!r} (screens: {names}); not opening a window", flush=True)
        return 2
    if screen is not None and os.environ.get("QT_QPA_PLATFORM") != "offscreen":
        geo = screen.availableGeometry()
        root.setScreen(screen)
        root.setPosition(geo.x() + (geo.width() - root.width()) // 2, geo.y() + (geo.height() - root.height()) // 2)
        root.show()  # (Main.qml waits for this on test runs: Backend.testPlacedShow)
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

    steps = json.loads(script.read_text(encoding="utf-8-sig"))  # (Windows PowerShell writes a BOM)
    timers = []
    state = {"frames": 0, "t": 0.0, "started": False}

    def drag(step):
        x0, y0, dx, dy = step["x"], step["y"], step["dx"], step.get("dy", 0)
        QTest.mousePress(root, Qt.LeftButton, Qt.NoModifier, QPoint(x0, y0))
        for i in range(1, 13):
            QTest.mouseMove(root, QPoint(int(x0 + dx * i / 12), int(y0 + dy * i / 12)), 12)
        if step.get("release", True):
            QTest.mouseRelease(root, Qt.LeftButton, Qt.NoModifier, QPoint(x0 + dx, y0 + dy), 10)

    def send_click(pt, button=Qt.LeftButton, double=False):
        """A press and a release (and a double-click) sent straight to the window: unlike QTest's
        click, it doesn't spin a nested event loop for a second (later steps fired inside it)."""
        from PySide6.QtCore import QPointF
        from PySide6.QtGui import QMouseEvent
        p = QPointF(pt)
        g = QPointF(root.mapToGlobal(pt))
        # Real-looking timestamps (pointer handlers like TapHandler ignore events stamped 0).
        clock = [int(time.monotonic() * 1000)]
        def stamp(e, step=20):
            clock[0] += step
            e.setTimestamp(clock[0])
            return e
        def ev(kind, buttons):
            return stamp(QMouseEvent(kind, p, p, g, button, buttons, Qt.NoModifier))
        QGuiApplication.sendEvent(root, stamp(QMouseEvent(QMouseEvent.Type.MouseMove, p, p, g, Qt.NoButton, Qt.NoButton, Qt.NoModifier)))
        QGuiApplication.sendEvent(root, ev(QMouseEvent.Type.MouseButtonPress, button))
        QGuiApplication.sendEvent(root, ev(QMouseEvent.Type.MouseButtonRelease, Qt.NoButton))
        if double:
            QGuiApplication.sendEvent(root, ev(QMouseEvent.Type.MouseButtonPress, button))
            QGuiApplication.sendEvent(root, ev(QMouseEvent.Type.MouseButtonDblClick, button))
            QGuiApplication.sendEvent(root, ev(QMouseEvent.Type.MouseButtonRelease, Qt.NoButton))

    def fire(step):
        if step.get("do") == "lag_start":  # the event loop's worst lateness: real freezes, not idle gaps
            state["lag"] = 0.0
            state["lag_prev"] = time.monotonic()
            t = QTimer()
            t.setTimerType(Qt.PreciseTimer)
            def tick():
                now = time.monotonic()
                state["lag"] = max(state["lag"], now - state["lag_prev"] - 0.010)
                state["lag_prev"] = now
            t.timeout.connect(tick)
            t.start(10)
            state["lag_timer"] = t
        elif step.get("do") == "lag_stop":
            state["lag_timer"].stop()
            print(f"[harness] LAG {step.get('label', '')}: worst freeze {state['lag'] * 1000:.0f} ms", flush=True)
        elif step.get("do") == "frames_start":  # every frame's interval until frames_stop
            state["intervals"] = []
            state["last"] = time.monotonic()
        elif step.get("do") == "frames_stop":
            iv = state.pop("intervals", None) or []
            print(f"[harness] FRAMES {step.get('label', '')}: {len(iv)} frames, intervals {iv[:40]}", flush=True)
            if iv: print("[harness] FRAMESTATS", step.get("label", ""), "n", len(iv), "median", sorted(iv)[len(iv)//2], "p95", sorted(iv)[int(len(iv)*.95)], "max", max(iv[1:] or iv), flush=True)
        elif step.get("do") == "fps_start":
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
            stop_recording()
            app.quit()
        elif step.get("do") == "drag":  # press, move in steps, optionally release
            drag(step)
        elif step.get("do") == "genres":  # {"map": {gameId: [tag, …]}} as if the genre lookup finished
            backend._apply_genres(step["map"])
        elif step.get("do") == "move":  # the real pointer to window coordinates
            QTest.mouseMove(root, QPoint(step["x"], step["y"]))
        elif step.get("do") == "click":  # a real mouse click at window coordinates
            button = Qt.RightButton if step.get("button") == "right" else Qt.LeftButton
            if step.get("timing"):
                print("TIMING click-start", int(time.time() * 1000) % 100000, flush=True)
            send_click(QPoint(step["x"], step["y"]), button)
            if step.get("timing"):
                print("TIMING click-end", int(time.time() * 1000) % 100000, flush=True)
        elif step.get("do") == "pressOnly":  # press without release, then report who grabbed the mouse
            from PySide6.QtCore import QPointF
            from PySide6.QtGui import QMouseEvent
            p = QPointF(step["x"], step["y"]); g = QPointF(root.mapToGlobal(p.toPoint()))
            QGuiApplication.sendEvent(root, QMouseEvent(QMouseEvent.Type.MouseButtonPress, p, p, g, Qt.LeftButton, Qt.LeftButton, Qt.NoModifier))
            gi = root.mouseGrabberItem()
            print("PRESSGRAB", gi.metaObject().className() if gi else None, gi.objectName() if gi else "", gi.parentItem().metaObject().className() if gi and gi.parentItem() else "", flush=True)
            QGuiApplication.sendEvent(root, QMouseEvent(QMouseEvent.Type.MouseButtonRelease, p, p, g, Qt.LeftButton, Qt.NoButton, Qt.NoModifier))
        elif step.get("do") == "grabber":  # prints which item holds the mouse (debugging clicks)
            g = root.mouseGrabberItem()
            print("GRABBER", step.get("label", ""), g.metaObject().className() if g else None, g.objectName() if g else "", flush=True)
        elif step.get("do") == "qtclick":  # QTest's click (blocks ~1 s; for comparison)
            QTest.mouseClick(root, Qt.LeftButton, Qt.NoModifier, QPoint(step["x"], step["y"]))
        elif step.get("do") == "dblclick":
            send_click(QPoint(step["x"], step["y"]), double=True)
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
            from PySide6.QtCore import Q_RETURN_ARG
            where = QMetaObject.invokeMethod(commands, "locate", Qt.DirectConnection, Q_RETURN_ARG("QVariant"),
                                             Q_ARG("QVariant", step["text"]), Q_ARG("QVariant", step.get("nth", 0)))
            parts = str(where).split(",")
            if parts[0] == "none":
                print(f"[harness] MISSING {step['text']!r} ({parts[1]} found)", flush=True)
            else:
                pt = QPoint(int(parts[0]), int(parts[1]))
                if step["do"] == "clickText":
                    send_click(pt)
                elif step["do"] == "rightClickText":
                    send_click(pt, Qt.RightButton)
                else:
                    QTest.mouseMove(root, pt)
                print(f"[harness] {step['do']} {step['text']!r} at {pt.x()},{pt.y()}", flush=True)
        elif commands is not None:
            QMetaObject.invokeMethod(commands, "run", Qt.DirectConnection, Q_ARG("QVariant", step))

    def begin():
        attach()
        start_recording()
        for step in steps:
            t = QTimer()
            t.setSingleShot(True)
            t.setTimerType(Qt.PreciseTimer)  # (coarse timers drift by up to 5%: steps ran out of order)
            t.timeout.connect(lambda step=step: fire(step))
            t.start(step["at"])
            timers.append(t)

    def on_frame():
        now = time.monotonic()
        if state.get("intervals") is not None:
            state["intervals"].append(round((now - state.get("last", now)) * 1000, 1))
        state["worst"] = max(state.get("worst", 0.0), now - state.get("last", now))
        state["last"] = now
        state["frames"] += 1
        if not state["started"]:
            state["started"] = True
            QTimer.singleShot(0, begin)

    recorder = {}

    def start_recording():
        out = os.environ.get("GC_RECORD")
        if out:
            # Frame-exact: animations advance one fixed step per frame, and every frame is
            # grabbed, so the video shows every animation frame however slow grabbing is.
            # Qt's fixed step is one refresh of this screen: play the video back at that rate.
            fps = round(root.screen().refreshRate()) or 60
            dpr = root.devicePixelRatio()
            w, h = int(root.width() * dpr) // 2 * 2, int(root.height() * dpr) // 2 * 2
            recorder["p"] = subprocess.Popen(
                ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgba",
                 "-s", f"{w}x{h}", "-framerate", str(fps), "-i", "-",
                 "-c:v", "libx264", "-preset", "ultrafast", "-crf", "16", "-pix_fmt", "yuv420p", out],
                stdin=subprocess.PIPE)
            recorder["size"] = (w, h)

            def grab():
                p = recorder.get("p")
                if not p:
                    return
                img = root.grabWindow().convertToFormat(QImage.Format_RGBA8888)
                if img.width() != w or img.height() != h:
                    img = img.copy(0, 0, w, h)
                p.stdin.write(bytes(img.constBits()))
                recorder["frames"] = recorder.get("frames", 0) + 1
            root.frameSwapped.connect(grab)
            print(f"[harness] frame-exact recording to {out}", flush=True)
            return
    def stop_recording():
        p = recorder.pop("p", None)
        if p:
            p.stdin.close()
            p.wait(timeout=30)
            print(f"[harness] recorded {recorder.get('frames', 0)} frames", flush=True)

    root.frameSwapped.connect(on_frame)
    try:
        return app.exec()
    finally:
        stop_recording()


if __name__ == "__main__":
    sys.exit(main())
