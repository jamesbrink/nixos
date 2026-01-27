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


def read_current_background_index(path: Path) -> int:
    """Read the current background index for the active theme.

    Returns 0 if no state exists.
    """
    if not path.exists():
        return 0
    try:
        return int(path.read_text().strip())
    except (OSError, ValueError):
        return 0


def write_background_index(path: Path, index: int) -> None:
    """Write the current background index."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(str(index))
