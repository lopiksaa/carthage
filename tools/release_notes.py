"""Prints the GitHub release notes for a version, from carthage/whatsnew.py (the same text as
the in-app "What's new" window):  python tools/release_notes.py 0.3.1 > notes.md"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from carthage.version import VERSION  # noqa: E402
from carthage.whatsnew import markdown  # noqa: E402

print(markdown(sys.argv[1] if len(sys.argv) > 1 else VERSION), end="")
