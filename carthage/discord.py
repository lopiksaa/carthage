"""Discord Rich Presence: "Choosing a Game" in the library, "Browsing Store" in the store.

Optional ("Discord Rich Presence", off by default). Talks to the Discord app on this PC through its
local IPC socket (Linux: $XDG_RUNTIME_DIR/discord-ipc-N, also the Flatpak and Snap copies;
Windows: the named pipe \\\\.\\pipe\\discord-ipc-N). Nothing goes over the network from
Carthage itself, and nothing about the user's games is sent: only which screen is open.

Frames are [opcode: int32 LE][length: int32 LE][JSON]. Opcode 0 is the handshake, 1 a
command (SET_ACTIVITY), 2 close. Discord allows about 5 activity updates per 20 s, so
updates are coalesced. While a game runs Carthage clears its activity, so the game's own
presence (or Discord's game detection) shows instead. The connection stays open while the
setting is on.

Runs in one worker thread; set() only records what should show.
"""

import json
import os
import socket
import struct
import sys
import threading
import time
import uuid
from pathlib import Path

CLIENT_ID = "1553704224133746709"   # the "Carthage" application on discord.com/developers
# The picture: Discord accepts an https URL here (it proxies it as "mp:external/…"), so no
# art asset has to be uploaded to the developer portal. The app icon in the public repo.
LARGE_IMAGE = "https://raw.githubusercontent.com/lopiksaa/carthage/main/carthage/assets/icons/carthage-512.png"
RETRY = 20                          # seconds between attempts while Discord isn't running
MIN_GAP = 4.5                       # seconds between activity updates (Discord: 5 per 20 s)

STATES = {
    "library": ("Choosing a Game", "In the library"),
    "store": ("Browsing Store", "Looking for something new"),
}


def _candidates():
    if sys.platform == "win32":
        return [rf"\\.\pipe\discord-ipc-{i}" for i in range(10)]
    base = [os.environ.get(k) for k in ("XDG_RUNTIME_DIR", "TMPDIR", "TMP", "TEMP")] + ["/tmp"]
    dirs = []
    for b in filter(None, base):
        dirs += [Path(b), Path(b) / "app" / "com.discordapp.Discord", Path(b) / "snap.discord",
                 Path(b) / ".flatpak" / "dev.vencord.Vesktop" / "xdg-run"]
    return [str(d / f"discord-ipc-{i}") for d in dirs for i in range(10)]


class _Conn:
    """One connection to the Discord app (a Unix socket, or a named pipe on Windows)."""

    def __init__(self):
        self.sock = None
        self.pipe = None
        for path in _candidates():
            try:
                if sys.platform == "win32":
                    self.pipe = open(path, "r+b", buffering=0)
                else:
                    if not os.path.exists(path):
                        continue
                    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                    s.settimeout(3)
                    s.connect(path)
                    self.sock = s
                return
            except OSError:
                continue
        raise OSError("Discord isn't running")

    def send(self, op, payload):
        data = json.dumps(payload).encode()
        frame = struct.pack("<ii", op, len(data)) + data
        if self.sock:
            self.sock.sendall(frame)
        else:
            self.pipe.write(frame)
        return self.recv()

    def recv(self):
        head = self._read(8)
        op, n = struct.unpack("<ii", head)
        body = json.loads(self._read(n) or b"{}")
        if op == 2:
            raise OSError(body.get("message", "Discord closed the connection"))
        return body

    def _read(self, n):
        buf = b""
        while len(buf) < n:
            chunk = self.sock.recv(n - len(buf)) if self.sock else self.pipe.read(n - len(buf))
            if not chunk:
                raise OSError("Discord closed the connection")
            buf += chunk
        return buf

    def close(self):
        for f in (self.sock, self.pipe):
            try:
                if f:
                    f.close()
            except OSError:
                pass


class Presence:
    def __init__(self, enabled=lambda: False):
        self._enabled = enabled
        self._want = None          # (details, state) or None to clear
        self._since = int(time.time())
        self._sent = "unset"
        self._wake = threading.Event()
        self._conn = None
        threading.Thread(target=self._run, daemon=True).start()

    def set(self, screen, game_running=False):
        """What Carthage is showing: "library", "store", or anything else for nothing."""
        want = None if game_running or screen not in STATES else STATES[screen]
        if want != self._want:
            if want and (not self._want or want[0] != self._want[0]):
                self._since = int(time.time())
            self._want = want
            self._wake.set()

    def refresh(self):
        """The setting changed: apply it now."""
        self._wake.set()

    def _run(self):
        last = 0.0
        while True:
            self._wake.wait(RETRY)
            self._wake.clear()
            want = self._want if self._enabled() else None
            if want == self._sent and (self._conn or want is None):
                continue
            if want is None and self._conn is None:
                self._sent = None
                continue
            gap = MIN_GAP - (time.monotonic() - last)
            if gap > 0:
                time.sleep(gap)
                want = self._want if self._enabled() else None
            try:
                if self._conn is None:
                    self._conn = _Conn()
                    self._conn.send(0, {"v": 1, "client_id": CLIENT_ID})
                activity = None
                if want:
                    activity = {"details": want[0], "state": want[1], "timestamps": {"start": self._since},
                                "assets": {"large_image": LARGE_IMAGE, "large_text": "Carthage"}}
                self._conn.send(1, {"cmd": "SET_ACTIVITY", "args": {"pid": os.getpid(), "activity": activity},
                                    "nonce": uuid.uuid4().hex})
                self._sent = want
                last = time.monotonic()
                # Switched off: let go of Discord. (Otherwise the connection stays open: Discord
                # is slow to accept a new handshake right after one closes.)
                if not self._enabled():
                    self._conn.close()
                    self._conn = None
            except (OSError, ValueError, struct.error):
                if self._conn:
                    self._conn.close()
                self._conn = None
                self._sent = "unset"
