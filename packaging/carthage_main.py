"""Entry point for the packaged app (PyInstaller): runs Carthage like `python -m carthage`."""

import os
import ssl
import sys


def _fit_linux_host():
    """The Linux build carries its own libraries; keep them to Carthage itself."""
    # PyInstaller points LD_LIBRARY_PATH at the bundle, so every program Carthage starts
    # (games, Steam, secret-tool, xdg-open) would load the bundle's older libraries and
    # crash. Carthage's own are already loaded; give the children the original value.
    orig = os.environ.pop("LD_LIBRARY_PATH_ORIG", None)
    if orig is not None:
        os.environ["LD_LIBRARY_PATH"] = orig
    else:
        os.environ.pop("LD_LIBRARY_PATH", None)
    # The bundled OpenSSL looks for certificates where Debian keeps them; elsewhere every
    # HTTPS request fails. Point it at the system's own list, or at the one Carthage carries
    # (certifi) on a system that keeps it somewhere else again.
    if not os.environ.get("SSL_CERT_FILE") and not os.path.exists(ssl.get_default_verify_paths().openssl_cafile):
        for path in ("/etc/ssl/certs/ca-certificates.crt",    # Debian, Ubuntu, Arch
                     "/etc/pki/tls/certs/ca-bundle.crt",      # Fedora, RHEL
                     "/etc/ssl/ca-bundle.pem",                # openSUSE
                     "/etc/ssl/cert.pem"):                    # Alpine, others
            if os.path.exists(path):
                os.environ["SSL_CERT_FILE"] = path
                break
        else:
            import certifi

            os.environ["SSL_CERT_FILE"] = certifi.where()


if sys.platform.startswith("linux"):
    _fit_linux_host()

from carthage.app import main  # noqa: E402

sys.exit(main())
