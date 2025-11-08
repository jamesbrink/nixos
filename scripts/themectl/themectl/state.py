"""State helpers for themectl."""

from __future__ import annotations

from pathlib import Path


def read_current_theme(path: Path) -> str | None:
    if not path.exists():
        return None
    try:
        return path.read_text().strip() or None
    except OSError:
        return None
