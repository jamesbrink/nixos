"""Configuration loading for themectl."""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Literal, Mapping

import tomllib


def get_home() -> Path:
    override = os.environ.get("THEMECTL_HOME")
    if override:
        return Path(override).expanduser()
    return Path.home()


def default_config_path() -> Path:
    return get_home() / ".config" / "themectl" / "config.toml"


def default_state_path() -> Path:
    return get_home() / ".config" / "themes" / ".current-theme"


def default_hotkeys_path() -> Path:
    return get_home() / ".config" / "themectl" / "hotkeys.yaml"


DEFAULT_CONFIG_PATH = default_config_path()
DEFAULT_STATE_PATH = default_state_path()
DEFAULT_HOTKEYS_PATH = default_hotkeys_path()


@dataclass(slots=True)
class EditorAutomation:
    vscode: bool = True
    cursor: bool = True
    neovim: bool = True


@dataclass(slots=True)
class ThemeOrder:
    cycle: list[str] = field(default_factory=list)


@dataclass(slots=True)
class ThemectlConfig:
    platform: Literal["darwin", "linux"] = "darwin"
    theme_metadata: Path | None = None
    state_file: Path | None = None
    hotkeys_file: Path | None = None
    editor_automation: EditorAutomation = field(default_factory=EditorAutomation)
    order: ThemeOrder = field(default_factory=ThemeOrder)

    @property
    def metadata_path(self) -> Path:
        if self.theme_metadata:
            return self.theme_metadata
        return get_home() / ".config" / "themectl" / "themes.json"

    @property
    def state_path(self) -> Path:
        if self.state_file:
            return self.state_file
        return default_state_path()

    @property
    def hotkeys_path(self) -> Path:
        if self.hotkeys_file:
            return self.hotkeys_file
        return default_hotkeys_path()


def _load_toml(path: Path) -> Mapping[str, Any]:
    with path.open("rb") as handle:
        return tomllib.load(handle)


def load_config(path: Path | None = None) -> ThemectlConfig:
    cfg_path = path or default_config_path()

    if not cfg_path.exists():
        return ThemectlConfig()

    raw = _load_toml(cfg_path)

    editor_raw = raw.get("editor", {})
    order_raw = raw.get("order", {})

    return ThemectlConfig(
        platform=raw.get("platform", "darwin"),
        theme_metadata=Path(raw["theme_metadata"]).expanduser()
        if "theme_metadata" in raw
        else None,
        state_file=Path(raw["state_file"]).expanduser() if "state_file" in raw else None,
        hotkeys_file=Path(raw["hotkeys_file"]).expanduser() if "hotkeys_file" in raw else None,
        editor_automation=EditorAutomation(
            vscode=bool(editor_raw.get("vscode", True)),
            cursor=bool(editor_raw.get("cursor", True)),
            neovim=bool(editor_raw.get("neovim", True)),
        ),
        order=ThemeOrder(
            cycle=list(order_raw.get("cycle", [])),
        ),
    )
