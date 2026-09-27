"""Riot games (League of Legends, VALORANT, Legends of Runeterra, 2XKO…) on Windows, from what
the Riot Client leaves behind — no network.

- installed:  %ProgramData%\\Riot Games\\Metadata\\<product>.<patchline>\\
              <product>.<patchline>.product_settings.yaml (install folder and shortcut name)
- client:     %ProgramData%\\Riot Games\\RiotClientInstalls.json ("rc_default": the path to
              RiotClientServices.exe)
- launch:     the same as Riot's own shortcuts:
              "<RiotClientServices.exe>" --launch-product=<product> --launch-patchline=<patchline>

The game then runs from its install folder, which is how launcher_win.py tracks it. The
YAML is flat "key: value" lines, read without a YAML library.
"""

import json
import os
from pathlib import Path

# Friendly names when the settings file doesn't carry one.
NAMES = {
    "league_of_legends": "League of Legends",
    "valorant": "VALORANT",
    "bacon": "Legends of Runeterra",
    "lion": "2XKO",
}


def riot_dir():
    return Path(os.environ.get("PROGRAMDATA", r"C:\ProgramData")) / "Riot Games"


def _yaml_values(text):
    out = {}
    for line in text.splitlines():
        if ":" not in line or line.startswith((" ", "\t", "#", "-")):
            continue
        key, _, value = line.partition(":")
        out[key.strip()] = value.strip().strip("\"'")
    return out


def client_path(root):
    try:
        data = json.loads((Path(root) / "RiotClientInstalls.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return ""
    for key in ("rc_default", "rc_live", "rc_beta"):
        exe = data.get(key) if isinstance(data, dict) else None
        if exe and Path(exe).is_file():
            return str(Path(exe))
    return ""


def load_from(root):
    """[{id, name, launch, install_dir, short_id}] from a "Riot Games" ProgramData folder."""
    root = Path(root)
    client = client_path(root)
    if not client:
        return []
    games = []
    for f in sorted((root / "Metadata").glob("*/*.product_settings.yaml")):
        stem = f.name[: -len(".product_settings.yaml")]  # league_of_legends.live
        product, _, patchline = stem.partition(".")
        if not product or product == "riot_client":
            continue
        try:
            values = _yaml_values(f.read_text(encoding="utf-8", errors="replace"))
        except OSError:
            continue
        folder = values.get("product_install_full_path", "")
        if not folder or not Path(folder).is_dir():
            continue
        games.append({
            "id": f"riot_{product}" + ("" if patchline in ("", "live") else f"_{patchline}"),
            # shortcut_name is the Start-menu shortcut's file name ("League of Legends.lnk").
            "name": values.get("shortcut_name", "").removesuffix(".lnk") or NAMES.get(product)
                    or product.replace("_", " ").title(),
            "launch": f'"{client}" --launch-product={product} --launch-patchline={patchline or "live"}',
            "install_dir": folder,
            "short_id": product[:6].upper(),
        })
    return games


def load():
    if os.name != "nt":
        return []
    return load_from(riot_dir())
