"""Removes the parts of Qt that Carthage never loads from a PyInstaller build (Linux).

PySide6's packaging hook copies every QML module and every Qt library, including Qt
WebEngine (about 200 MB), Charts, Maps and so on. This keeps the QML modules Carthage
imports (see KEEP_QML), then keeps only the Qt libraries something that's left links to.

    python packaging/prune_qt_linux.py dist/Carthage
"""

import re
import shutil
import subprocess
import sys
from pathlib import Path

# QML modules Carthage imports (qml/*.qml), plus what they import themselves.
KEEP_QML = {"Qt", "QtCore", "QtQml", "QtQuick", "QtQuick3D", "QtMultimedia"}
# Parts of the kept modules Carthage doesn't use (each links to a big library).
DROP_QML = ["QtQuick/Pdf", "QtQuick/Scene2D", "QtQuick/Scene3D", "QtQuick/VirtualKeyboard", "QtQuick3D/Xr"]
DROP_PLUGINS = ["qmltooling", "platforminputcontexts", "imageformats/libqpdf.so"]


def needed(lib):
    out = subprocess.run(["readelf", "-d", str(lib)], capture_output=True, text=True).stdout
    return re.findall(r"\(NEEDED\).*\[(.+?)\]", out)


def main(app):
    qt = next(Path(app).rglob("PySide6/Qt"))
    for d in (qt / "qml").iterdir():
        if d.is_dir() and d.name not in KEEP_QML:
            shutil.rmtree(d)
    for rel in DROP_QML:
        shutil.rmtree(qt / "qml" / rel, ignore_errors=True)
    for rel in DROP_PLUGINS:
        path = qt / "plugins" / rel
        if path.is_dir():
            shutil.rmtree(path)
        elif path.exists():
            path.unlink()

    # Everything outside Qt/lib that stays is a starting point; follow what it links to.
    # (PyInstaller also puts symlinks to every Qt library next to the app: not starting points.)
    libdir = qt / "lib"
    libs = {p.name: p for p in libdir.iterdir()}
    todo = [p for p in Path(app).rglob("*.so*") if p.is_file() and not p.is_symlink() and p.parent != libdir]
    keep = set()
    while todo:
        for name in needed(todo.pop()):
            if name in libs and name not in keep:
                keep.add(name)
                todo.append(libs[name])
    before = sum(p.stat().st_size for p in libs.values() if p.is_file())
    for name, p in libs.items():
        if name not in keep and p.is_file():
            p.unlink()
    for link in Path(app).rglob("*"):
        if link.is_symlink() and not link.exists():
            link.unlink()
    after = sum(p.stat().st_size for p in libdir.iterdir() if p.is_file())
    print(f"Qt libraries: {before // 2**20} MB -> {after // 2**20} MB")


if __name__ == "__main__":
    main(sys.argv[1])
