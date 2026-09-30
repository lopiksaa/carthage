"""Games added by hand ("Add Game…"), stored in Carthage's own config.

~/.config/carthage/games.json: [{"id", "name", "command", "added"}]
"""

import json
import os
import re
import time
import uuid


def path():
    # chrome.py redirects XDG_CONFIG_HOME for the UI toolkit; use the real one.
    from ..chrome import CONFIG_HOME

    return CONFIG_HOME / "carthage" / "games.json"


def _read():
    try:
        data = json.loads(path().read_text(encoding="utf-8"))
        return data if isinstance(data, list) else []
    except (OSError, ValueError):
        return []


def _write(items):
    p = path()
    p.parent.mkdir(parents=True, exist_ok=True)
    tmp = p.with_suffix(".tmp")
    tmp.write_text(json.dumps(items, indent=2), encoding="utf-8")
    os.replace(tmp, p)


def add(name, command):
    items = _read()
    item = {"id": uuid.uuid4().hex[:10], "name": name.strip(), "command": command.strip(), "added": int(time.time())}
    items.append(item)
    _write(items)
    return item


def remove(game_id):
    _write([i for i in _read() if i.get("id") != game_id])


def watch_paths():
    p = path()
    return [str(p)] if p.exists() else [str(p.parent)] if p.parent.exists() else []


def _fix_command(command):
    """Older Windows builds saved picked programs as "/C:/…" (the file:// URL with its scheme
    cut off); give those back their drive letter."""
    if os.name == "nt":
        command = re.sub(r'^("?)/([A-Za-z]:/)', r"\1\2", command)
    return command


def load():
    return [
        {
            "id": f"manual_{i['id']}",
            "name": i["name"],
            "launch": _fix_command(i["command"]),
            "added": int(i.get("added") or 0),
            "short_id": i["id"][:6].upper(),
        }
        for i in _read()
        if i.get("id") and i.get("name") and i.get("command")
    ]
