"""Gunicorn application factory for the containerized portal."""

from __future__ import annotations

import os
import pathlib

from .config import load_config
from .hub_api import HubApplication
from .portal_runtime import build_portal


def _required_path(name: str) -> pathlib.Path:
    value = os.environ.get(name)
    if not value:
        raise RuntimeError(f"{name} must be set")
    return pathlib.Path(value)


def create_app() -> HubApplication:
    """Build the portal from paths supplied by the container runtime."""
    return build_portal(
        load_config(_required_path("NVIS_CONFIG")),
        web_root=_required_path("NVIS_WEB_ROOT"),
        auth_records_file=_required_path("NVIS_AUTH_RECORDS"),
        session_secret_file=_required_path("NVIS_SESSION_SECRET"),
        credential_root=_required_path("NVIS_CREDENTIAL_ROOT"),
        secure_cookies=os.environ.get("NVIS_INSECURE_HTTP", "").lower()
        not in {"1", "true", "yes"},
    )
