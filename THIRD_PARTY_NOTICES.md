# Third-party notices

Carthage's own code is under the GNU GPL v3.0 or later (see [LICENSE](LICENSE)). The parts
below come from other projects and keep their own licenses.

## Fonts (`carthage/assets/fonts`)

All 21 are under the SIL Open Font License 1.1. Each license, with its copyright line, sits
next to the font as `OFL-<name>.txt`.

| Font | Copyright |
|---|---|
| Nunito | 2014 The Nunito Project Authors (github.com/googlefonts/nunito) |
| DM Mono | 2020 The DM Mono Project Authors (github.com/googlefonts/dm-mono) |
| Chakra Petch | 2018 The Chakra Petch Project Authors (github.com/m4rc1e/Chakra-Petch.git), static weights, cut down to Latin |
| Michroma | 2011 The Michroma Project Authors (github.com/googlefonts/Michroma-font), cut down to Latin |
| Bai Jamjuree | 2018 Bai Jamjuree (github.com/cadsondemak/Bai-Jamjuree), static weights, cut down to Latin |
| Sora | 2019 The Sora Project Authors (github.com/sora-xor/sora-font), static weights, cut down to Latin |
| Red Hat Display | 2024 The Red Hat Project Authors (github.com/RedHatOfficial/RedHatFont), static weights, cut down to Latin |
| Instrument Sans | 2022 The Instrument Sans Project Authors (github.com/Instrument/instrument-sans), static weights, cut down to Latin |
| Orbitron | 2018 The Orbitron Project Authors (github.com/theleagueof/orbitron), with Reserved Font Name: "Orbitron"; the authors’ Medium, Bold and Black files, unmodified |
| Audiowide | 2012, Brian J. Bonislawsky DBA Astigmatic (AOETI), with Reserved Font Names "Audiowide"; unmodified |
| Jura | 2019 The Jura Project Authors (github.com/ossobuffo/jura), static weights, cut down to Latin |
| Righteous | 2011 by Brian J. Bonislawsky DBA Astigmatic (AOETI), cut down to Latin |
| Manrope | 2018 The Manrope Project Authors (github.com/googlefonts/manrope), static weights, cut down to Latin |
| Figtree | 2022 The Figtree Project Authors (github.com/erikdkennedy/figtree), static weights, cut down to Latin |
| Onest | 2021 The Onest Project Authors (github.com/googlefonts/onest), static weights, cut down to Latin |
| Plus Jakarta Sans | 2020 The Plus Jakarta Sans Project Authors (github.com/tokotype/PlusJakartaSans), static weights, cut down to Latin |
| Lexend | 2018 The Lexend Project Authors (github.com/googlefonts/lexend), with Reserved Font Name “RevReading Lexend”, static weights, cut down to Latin |
| Hanken Grotesk | 2021 The Hanken Grotesk Project Authors (github.com/marcologous/hanken-grotesk), static weights, cut down to Latin |
| Albert Sans | 2021 The Albert Sans Project Authors (github.com/usted/Albert-Sans), static weights, cut down to Latin |
| Urbanist | 2021 The Urbanist Project Authors (github.com/coreyhu/Urbanist), static weights, cut down to Latin |

## Interface icons (`carthage/assets/icons/ui`)

These are from KDE's [Breeze icon theme](https://invent.kde.org/frameworks/breeze-icons), ©
KDE contributors, under the GNU LGPL v3.0 or later. `carthage.svg`, `dice.svg` and
`edit-undo.svg` in that folder are Carthage's own.

## Textures (`carthage/assets/textures`)

The normal maps are from Plastic004, Plastic012A, Plastic014A and Plastic017A by
[ambientCG](https://ambientcg.com), under CC0 1.0.

## Sounds (`carthage/assets/sounds`)

The recording `release.wav` is trimmed from "51 UI sound effects" by
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
