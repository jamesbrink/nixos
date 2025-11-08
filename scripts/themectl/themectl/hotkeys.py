"""Hotkey manifest loader/helpers."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Mapping


def load_manifest(path: Path) -> Mapping[str, Any]:
    data = json.loads(path.read_text())
    if isinstance(data, Mapping):
        return data
    raise ValueError("Hotkey manifest must be a mapping")


def flatten_bindings(bindings: Mapping[str, Any]) -> list[tuple[str, str]]:
    rows: list[tuple[str, str]] = []

    def _flatten(prefix: str, value: Any) -> None:
        if isinstance(value, Mapping):
            for key, sub in value.items():
                next_prefix = f"{prefix}.{key}" if prefix else str(key)
                _flatten(next_prefix, sub)
        else:
            rows.append((prefix, str(value)))

    _flatten("", bindings)
    return rows
