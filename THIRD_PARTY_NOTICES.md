# Third-party notices

Carthage's own code is under the GNU GPL v3.0 or later (see [LICENSE](LICENSE)). The parts
below come from other projects and keep their own licenses.

## Fonts (`carthage/assets/fonts`)

All five are under the SIL Open Font License 1.1. Each license, with its copyright line, sits
next to the font as `OFL-<name>.txt`.

| Font | Copyright |
|---|---|
| Nunito | 2014 The Nunito Project Authors (github.com/googlefonts/nunito) |
| DM Mono | 2020 The DM Mono Project Authors (github.com/googlefonts/dm-mono) |
| DotGothic16 | 2020 The DotGothic16 Project Authors (github.com/fontworks-fonts/DotGothic16), cut down to its Latin characters |

## Interface icons (`carthage/assets/icons/ui`)

These are from KDE's [Breeze icon theme](https://invent.kde.org/frameworks/breeze-icons), ©
KDE contributors, under the GNU LGPL v3.0 or later. `carthage.svg`, `dice.svg` and
`edit-undo.svg` in that folder are Carthage's own.

## Texture (`carthage/assets/textures`)

The normal map is from Plastic012A by [ambientCG](https://ambientcg.com/view?id=Plastic012A),
under CC0 1.0.

## Sound (`carthage/assets/sounds/lab`)

The recording `release_2.wav` is trimmed from "51 UI sound effects" by
[Kenney](https://www.kenney.nl), under CC0 1.0. `tools/make_sounds.py` generates all the other
sounds.

## Launcher and store logos (`carthage/assets/logos`)

These logos are trademarks of their owners. Carthage uses them only to show where a game
comes from. Their sources are listed in `carthage/assets/logos/SOURCES.md`.

| Logo | Source | License |
|---|---|---|
| Steam | Wikimedia Commons, "Steam 2016 logo black.svg" | Public domain (trademark of Valve) |
| Flatpak | Wikimedia Commons, "Flatpak Logo.svg", by the Flatpak project | CC BY 3.0 |
| Heroic | Heroic Games Launcher (github.com/Heroic-Games-Launcher/HeroicGamesLauncher) | GPL-3.0 |
| Lutris | Lutris (github.com/lutris/lutris) | GPL-3.0 |
| Battle.net, Epic Games, Riot Games, GOG.com, EA | [Simple Icons](https://simpleicons.org) | CC0 1.0 (trademarks of Blizzard Entertainment, Epic Games, Riot Games, CD PROJEKT and Electronic Arts) |

## In the Windows and Linux builds

The installers and the AppImage include these libraries. Each is under its own license.

| Library | License |
|---|---|
| Qt 6 and Qt for Python (PySide6, Shiboken6) | GNU LGPL v3.0 ([source](https://code.qt.io)) |
| Python | Python Software Foundation License |
| NumPy | BSD 3-Clause |
| Pillow | MIT-CMU (HPND) |
| psutil (Windows) | BSD 3-Clause |
| python-xlib (Linux) | GNU LGPL v2.1 or later |
| PyInstaller bootloader | GPL v2.0 or later, with the bootloader exception |

Qt is linked dynamically. The Qt libraries in a build can be replaced with your own
compatible version.
