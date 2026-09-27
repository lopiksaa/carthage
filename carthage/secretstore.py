"""Where API keys are kept: the operating system's own password store, never a file.

- Linux: the Secret Service keyring (KDE Wallet / GNOME Keyring) through libsecret.
- Windows: Windows Credential Manager (generic credentials named "Carthage/<service>").

lookup/store/clear block briefly; call them from worker threads (keys.py does).
"""

import sys

IS_WINDOWS = sys.platform == "win32"

if IS_WINDOWS:
    import ctypes
    from ctypes import wintypes

    _advapi = ctypes.WinDLL("advapi32", use_last_error=True)
    CRED_TYPE_GENERIC = 1
    CRED_PERSIST_LOCAL_MACHINE = 2

    class _CRED(ctypes.Structure):
        _fields_ = [
            ("Flags", wintypes.DWORD), ("Type", wintypes.DWORD), ("TargetName", wintypes.LPWSTR),
            ("Comment", wintypes.LPWSTR), ("LastWritten", wintypes.FILETIME),
            ("CredentialBlobSize", wintypes.DWORD), ("CredentialBlob", ctypes.POINTER(ctypes.c_byte)),
            ("Persist", wintypes.DWORD), ("AttributeCount", wintypes.DWORD), ("Attributes", ctypes.c_void_p),
            ("TargetAlias", wintypes.LPWSTR), ("UserName", wintypes.LPWSTR),
        ]

    _advapi.CredReadW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD, ctypes.POINTER(ctypes.POINTER(_CRED))]
    _advapi.CredWriteW.argtypes = [ctypes.POINTER(_CRED), wintypes.DWORD]
    _advapi.CredDeleteW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD]
    _advapi.CredFree.argtypes = [ctypes.c_void_p]

    def _target(service):
        return f"Carthage/{service}"

    def lookup(service):
        p = ctypes.POINTER(_CRED)()
        if not _advapi.CredReadW(_target(service), CRED_TYPE_GENERIC, 0, ctypes.byref(p)):
            return ""
        try:
            c = p.contents
            return ctypes.string_at(c.CredentialBlob, c.CredentialBlobSize).decode("utf-8")
        finally:
            _advapi.CredFree(p)

    def store(service, label, secret):
        blob = secret.encode("utf-8")
        buf = (ctypes.c_byte * len(blob)).from_buffer_copy(blob)
        c = _CRED(Type=CRED_TYPE_GENERIC, TargetName=_target(service), Comment=label,
                  CredentialBlobSize=len(blob), CredentialBlob=buf, Persist=CRED_PERSIST_LOCAL_MACHINE,
                  UserName="Carthage")
        if not _advapi.CredWriteW(ctypes.byref(c), 0):
            raise OSError(ctypes.get_last_error(), "Couldn't save to Windows Credential Manager")

    def clear(service):
        _advapi.CredDeleteW(_target(service), CRED_TYPE_GENERIC, 0)

else:
    # libsecret through PyGObject when the system has it (a normal install); otherwise the
    # `secret-tool` command (the packaged Linux build doesn't bundle PyGObject). Both store
    # the same item: attributes service + xdg:schema, so either one finds the other's keys.
    import shutil
    import subprocess

    SCHEMA_NAME = "io.github.lopiksa.Carthage"
    try:
        import gi

        gi.require_version("Secret", "1")
        from gi.repository import Secret  # noqa: E402
    except (ImportError, ValueError):
        Secret = None

    if Secret is not None:
        SCHEMA = Secret.Schema.new(SCHEMA_NAME, Secret.SchemaFlags.NONE, {"service": Secret.SchemaAttributeType.STRING})

        def lookup(service):
            return Secret.password_lookup_sync(SCHEMA, {"service": service}, None) or ""

        def store(service, label, secret):
            Secret.password_store_sync(SCHEMA, {"service": service}, Secret.COLLECTION_DEFAULT, label, secret, None)

        def clear(service):
            Secret.password_clear_sync(SCHEMA, {"service": service}, None)

    else:
        def _tool(action, service, *extra, secret=None):
            exe = shutil.which("secret-tool")
            if not exe:
                raise OSError("No keyring access: install libsecret (the secret-tool command)")
            return subprocess.run([exe, action, *extra, "service", service, "xdg:schema", SCHEMA_NAME],
                                  input=secret, capture_output=True, text=True, timeout=30)

        def lookup(service):
            r = _tool("lookup", service)
            return r.stdout.rstrip("\n") if r.returncode == 0 else ""

        def store(service, label, secret):
            if _tool("store", service, f"--label={label}", secret=secret).returncode != 0:
                raise OSError("Couldn't save to the keyring")

        def clear(service):
            _tool("clear", service)
