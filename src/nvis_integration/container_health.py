"""Minimal unauthenticated liveness probe for container runtimes."""

from __future__ import annotations

import urllib.request


def main() -> None:
    with urllib.request.urlopen("http://127.0.0.1:8787/", timeout=3) as response:
        if response.status != 200:
            raise SystemExit(1)
        response.read(1)


if __name__ == "__main__":
    main()
