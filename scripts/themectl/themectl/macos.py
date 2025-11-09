"""macOS-specific helpers (BSP/native toggles, yabai automation)."""

from __future__ import annotations

import shutil
import subprocess
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from rich.console import Console
from rich.panel import Panel

from .config import get_home
from .hooks import reload_ghostty

LAUNCH_AGENTS = (
    "org.nixos.yabai",
    "org.nixos.skhd",
    "org.nixos.sketchybar",
)

PROCESSES = (
    "yabai",
    "skhd",
    "sketchybar",
)


def ensure_yabai_sa(console: Console | None = None) -> bool:
    yabai = shutil.which("yabai")
    if not yabai:
        if console:
            console.print(
                "[yellow]![/yellow] yabai not found; skipping scripting addition reload"
            )
        return True
    sudo = shutil.which("sudo") or "/usr/bin/sudo"
    result = subprocess.run(
        [sudo, yabai, "--load-sa"],
        capture_output=True,
        text=True,
    )
    if result.returncode == 0:
        if console:
            console.print("[green]✓[/green] Ensured yabai scripting addition is loaded")
        return True
    if console:
        console.print(
            Panel(
                result.stderr.strip() or "Unknown yabai error",
                title="yabai --load-sa failed",
                border_style="red",
            )
        )
    return False


@dataclass
class MacOSModeController:
    """Switch between BSP tiling and native macOS mode."""

    console: Console
    state_path: Path | None = None

    def __post_init__(self) -> None:
        self.home = get_home()
        self._state_path: Path = self.state_path or (self.home / ".bsp-mode-state")

    @property
    def statefile(self) -> Path:
        return self._state_path

    def current_mode(self) -> str:
        try:
            value = self.statefile.read_text().strip().lower()
            if value in ("bsp", "macos"):
                return value
        except FileNotFoundError:
            pass
        return "bsp"

    def _write_state(self, mode: str) -> None:
        self.statefile.parent.mkdir(parents=True, exist_ok=True)
        self.statefile.write_text(mode)

    def _launchctl(self, action: str, agents: Iterable[str]) -> None:
        for name in agents:
            plist = self.home / "Library" / "LaunchAgents" / f"{name}.plist"
            if not plist.exists():
                continue
            cmd = ["launchctl", action]
            # Use -w flag for both load and unload to persist state across reboots
            if action in ("load", "unload"):
                cmd.append("-w")
            cmd.append(str(plist))
            subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    def _kill_processes(self, processes: Iterable[str]) -> None:
        for name in processes:
            subprocess.run(
                ["killall", name],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )

    def _set_defaults(self, domain: str, key: str, value: bool) -> None:
        subprocess.run(
            [
                "defaults",
                "write",
                domain,
                key,
                "-bool",
                "true" if value else "false",
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

    def _set_menubar_autohide(self, hide: bool) -> None:
        """Set menu bar auto-hide state and post darwin notification.

        Args:
            hide: True to hide menu bar, False to show it
        """
        # Set all four menu bar preference keys
        # _HIHideMenuBar: 0=visible, 1=hide
        subprocess.run(
            [
                "defaults",
                "write",
                "NSGlobalDomain",
                "_HIHideMenuBar",
                "-int",
                "1" if hide else "0",
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        # AppleMenuBarAutoHide: false=visible, true=hide
        self._set_defaults("NSGlobalDomain", "AppleMenuBarAutoHide", hide)
        # Dock autohide-menu-bar: false=visible, true=hide
        self._set_defaults("com.apple.Dock", "autohide-menu-bar", hide)
        # AutoHideMenuBarOption: 3=Never, 0=Always
        subprocess.run(
            [
                "defaults",
                "write",
                "com.apple.controlcenter",
                "AutoHideMenuBarOption",
                "-int",
                "0" if hide else "3",
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

        # Post darwin notification (same as System Preferences)
        notification = (
            "com.apple.HIToolbox.hideFrontMenuBar"
            if hide
            else "com.apple.HIToolbox.showFrontMenuBar"
        )
        subprocess.run(
            ["notifyutil", "-p", notification],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

    def _restart_dock_and_finder(self) -> None:
        for name in ("Dock", "Finder"):
            subprocess.run(
                ["killall", name],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )

    def _update_ghostty_mode(self, mode: str) -> None:
        config = self.home / ".config" / "ghostty" / "config"
        if not config.exists():
            return
        titlebar = "hidden" if mode == "bsp" else "transparent"
        opacity = "0.97" if mode == "bsp" else "1.0"
        lines = config.read_text().splitlines()

        def upsert(key: str, value: str) -> None:
            nonlocal lines
            replaced = False
            for idx, line in enumerate(lines):
                if line.strip().startswith(f"{key} ="):
                    lines[idx] = f"{key} = {value}"
                    replaced = True
                    break
            if not replaced:
                lines.append(f"{key} = {value}")

        upsert("macos-titlebar-style", titlebar)
        upsert("background-opacity", opacity)
        config.write_text("\n".join(lines) + "\n")
        reload_ghostty(self.console)

    def _update_alacritty_mode(self, mode: str) -> None:
        config = self.home / ".config" / "alacritty" / "alacritty.toml"
        if not config.exists():
            return
        if config.is_symlink():
            try:
                source = config.resolve(strict=True)
                contents = source.read_text()
            except OSError:
                contents = ""
            try:
                config.unlink()
            except OSError:
                return
            config.parent.mkdir(parents=True, exist_ok=True)
            config.write_text(contents)
        decorations = "buttonless" if mode == "bsp" else "full"
        lines = config.read_text().splitlines()
        in_window = False
        window_header_index: int | None = None
        updated = False
        for idx, line in enumerate(lines):
            stripped = line.strip()
            if stripped.startswith("[") and stripped.endswith("]"):
                in_window = stripped.lower() == "[window]"
                if in_window:
                    window_header_index = idx
                continue
            if in_window and stripped.startswith("decorations"):
                indent = line[: len(line) - len(line.lstrip())]
                lines[idx] = f'{indent}decorations = "{decorations}"'
                updated = True
                break
            if in_window and stripped.startswith("[") and stripped.endswith("]"):
                break
        if not updated:
            insert_line = f'decorations = "{decorations}"'
            if window_header_index is not None:
                lines.insert(window_header_index + 1, insert_line)
            else:
                lines.extend(["", "[window]", insert_line])
        config.write_text("\n".join(lines) + "\n")

    def _enter_macos(self) -> None:
        self.console.print("[cyan]→[/cyan] Switching to native macOS mode")
        self._launchctl("unload", LAUNCH_AGENTS)
        self._kill_processes(PROCESSES)
        self._set_defaults("com.apple.dock", "autohide", False)
        self._set_defaults("com.apple.finder", "CreateDesktop", True)
        self._set_menubar_autohide(hide=False)  # Show menu bar in native mode
        self._restart_dock_and_finder()
        self._update_ghostty_mode("macos")
        self._update_alacritty_mode("macos")
        self._write_state("macos")
        self.console.print(
            "[green]✓[/green] Native mode ready (Dock/Finder/MenuBar restored)"
        )

    def _enter_bsp(self) -> None:
        self.console.print("[cyan]→[/cyan] Switching to BSP tiling mode")
        self._set_defaults("com.apple.dock", "autohide", True)
        self._set_defaults("com.apple.finder", "CreateDesktop", False)
        self._set_menubar_autohide(hide=True)  # Hide menu bar in BSP mode
        self._restart_dock_and_finder()
        time.sleep(3)
        self._launchctl("load", LAUNCH_AGENTS)
        time.sleep(1)
        ensure_yabai_sa(self.console)
        self._update_ghostty_mode("bsp")
        self._update_alacritty_mode("bsp")
        self._write_state("bsp")
        self.console.print(
            "[green]✓[/green] BSP mode ready (yabai/skhd/sketchybar/MenuBar hidden)"
        )

    def switch(self, requested: str) -> None:
        requested = requested.lower()
        if requested == "toggle":
            target = "macos" if self.current_mode() == "bsp" else "bsp"
        elif requested in ("macos", "native"):
            target = "macos"
        elif requested in ("bsp", "tiling"):
            target = "bsp"
        else:
            raise ValueError("Mode must be one of: bsp, macos, native, toggle")
        if target == self.current_mode():
            self.console.print(f"[cyan]-[/cyan] Already in {target.upper()} mode")
            return
        if target == "macos":
            self._enter_macos()
        else:
            self._enter_bsp()
