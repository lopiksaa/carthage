"""Starting, watching and stopping games — picks the version for this operating system.

launcher_linux.py (/proc, systemd scopes, Flatpak, X11) and launcher_win.py (psutil,
the registry, Win32 windows) offer the same functions, so sessions.py doesn't care which.
"""

import os

if os.name == "nt":
    from .launcher_win import *  # noqa: F401,F403
else:
    from .launcher_linux import *  # noqa: F401,F403
