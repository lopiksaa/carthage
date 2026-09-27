"""Carthage's log file, so problems can be found even in the Windows build (which has no
console): %LOCALAPPDATA%\\Carthage\\carthage.log on Windows, ~/.cache/carthage/carthage.log
elsewhere. Unhandled errors are written there too. Keys and personal data are never logged.
"""

import logging
import os
import sys
from pathlib import Path


def log_path():
    if os.name == "nt":
        base = Path(os.environ.get("LOCALAPPDATA") or Path.home() / "AppData" / "Local") / "Carthage"
    else:
        base = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "carthage"
    base.mkdir(parents=True, exist_ok=True)
    return base / "carthage.log"


def setup():
    handlers = [logging.FileHandler(log_path(), mode="w", encoding="utf-8")]
    if sys.stderr:
        handlers.append(logging.StreamHandler(sys.stderr))
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s",
                        handlers=handlers, force=True)
    from .version import VERSION

    logging.getLogger("carthage").info("Carthage %s on %s, Python %s", VERSION, sys.platform, sys.version.split()[0])

    def hook(kind, value, tb):
        logging.getLogger("carthage").error("Unhandled error", exc_info=(kind, value, tb))

    sys.excepthook = hook
