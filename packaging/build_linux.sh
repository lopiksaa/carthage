#!/bin/sh
# Builds Carthage for Linux: dist/Carthage (the app folder), dist/Carthage-<version>-linux.tar.gz
# and dist/Carthage-<version>-x86_64.AppImage. Used by .github/workflows/release.yml; also
# runs locally from the repo root:
#   sh packaging/build_linux.sh [python]
# Needs Python with PySide6 6.11, pillow, numpy, python-xlib and pyinstaller, and readelf. Downloads
# appimagetool if it isn't on PATH.
set -eu
PY="${1:-python3}"
cd "$(dirname "$0")/.."

version=$("$PY" -c "from carthage.version import VERSION; print(VERSION)")
echo "Building Carthage $version"

"$PY" -m PyInstaller packaging/carthage_main.py --name Carthage --noconfirm --paths . \
    --add-data "carthage/qml:carthage/qml" \
    --add-data "carthage/assets:carthage/assets" \
    --hidden-import PySide6.QtQuick3D --hidden-import PySide6.QtMultimedia \
    --hidden-import PySide6.QtSvg --hidden-import PySide6.QtQuickControls2 \
    --hidden-import Xlib \
    --exclude-module gi \
    --collect-submodules carthage
cp LICENSE dist/Carthage/LICENSE.txt
cp THIRD_PARTY_NOTICES.md dist/Carthage/THIRD_PARTY_NOTICES.md
"$PY" packaging/prune_qt_linux.py dist/Carthage
# Libraries every desktop has, which must be the system's own: the graphics driver (Mesa)
# loads into Carthage and needs the C++ runtime, X11 and gbm it was built with. Bundled
# copies from the older build machine make it fail ("Could not initialize GLX").
for lib in libstdc++.so.6 libgcc_s.so.1 libgbm.so.1 libX11.so.6 libX11-xcb.so.1 libXext.so.6 \
    libXrender.so.1 libxcb-glx.so.0 libxcb-randr.so.0 libxcb-render.so.0 libxcb-shm.so.0 \
    libxcb-sync.so.1 libxcb-xfixes.so.0 libxkbcommon.so.0 libfontconfig.so.1 libfreetype.so.6 \
    libharfbuzz.so.0 libexpat.so.1 libz.so.1 libdbus-1.so.3; do
    rm -f "dist/Carthage/_internal/$lib"
done

tar -C dist -czf "dist/Carthage-$version-linux.tar.gz" Carthage

# AppImage: the same folder plus a launcher, desktop entry and icon.
app=dist/Carthage.AppDir
rm -rf "$app"
mkdir -p "$app/usr"
cp -r dist/Carthage "$app/usr/lib"
cat > "$app/AppRun" <<'EOF'
#!/bin/sh
exec "$(dirname "$(readlink -f "$0")")/usr/lib/Carthage" "$@"
EOF
chmod +x "$app/AppRun"
cp carthage/assets/icons/carthage-512.png "$app/io.github.lopiksa.Carthage.png"
cat > "$app/io.github.lopiksa.Carthage.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Carthage
Comment=Game launcher
Exec=Carthage
Icon=io.github.lopiksa.Carthage
Categories=Game;
StartupWMClass=carthage
EOF

tool=$(command -v appimagetool || true)
if [ -z "$tool" ]; then
    tool=dist/appimagetool
    [ -x "$tool" ] || { curl -fsSL -o "$tool" https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage && chmod +x "$tool"; }
fi
# --appimage-extract-and-run: works where FUSE isn't available (CI containers).
ARCH=x86_64 "$tool" --appimage-extract-and-run --no-appstream "$app" "dist/Carthage-$version-x86_64.AppImage"
echo "Done: dist/Carthage-$version-x86_64.AppImage and dist/Carthage-$version-linux.tar.gz"
