#!/bin/sh
# Installs Carthage for the current user, or updates it (run it again).
set -eu
bin="$HOME/.local/bin"
data="${XDG_DATA_HOME:-$HOME/.local/share}"
repo=https://github.com/lopiksaa/carthage
url=$(curl -fsSL https://api.github.com/repos/lopiksaa/carthage/releases/latest \
    | grep -o '"browser_download_url": *"[^"]*x86_64\.AppImage"' | cut -d'"' -f4)
[ -n "$url" ] || { echo "Couldn't find the latest Carthage download." >&2; exit 1; }

mkdir -p "$bin" "$data/applications" "$data/icons/hicolor/512x512/apps"
echo "Downloading Carthage..."
curl -fL --progress-bar -o "$bin/carthage.part" "$url"
chmod +x "$bin/carthage.part"
mv "$bin/carthage.part" "$bin/carthage"
curl -fsSL -o "$data/icons/hicolor/512x512/apps/io.github.lopiksa.Carthage.png" "$repo/raw/main/carthage/assets/icons/carthage-512.png" || true
cat > "$data/applications/io.github.lopiksa.Carthage.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Carthage
Comment=Game launcher
Exec=$bin/carthage
Icon=io.github.lopiksa.Carthage
Categories=Game;
StartupWMClass=carthage
DESKTOP
echo "Carthage is installed. Open it from your app menu."
