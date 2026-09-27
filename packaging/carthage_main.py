"""Entry point for the packaged app (PyInstaller): runs Carthage like `python -m carthage`."""

import sys

from carthage.app import main

sys.exit(main())
