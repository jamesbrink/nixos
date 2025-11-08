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
            console.print("[yellow]![/yellow] yabai not found; skipping scripting addition reload")
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
        self.state_path = self.state_path or (self.home / ".bsp-mode-state")

    def current_mode(self) -> str:
        try:
            value = self.state_path.read_text().strip().lower()
            if value in ("bsp", "macos"):
                return value
        except FileNotFoundError:
            pass
        return "bsp"

    def _write_state(self, mode: str) -> None:
        self.state_path.parent.mkdir(parents=True, exist_ok=True)
        self.state_path.write_text(mode)

    def _launchctl(self, action: str, agents: Iterable[str]) -> None:
        for name in agents:
            plist = self.home / "Library" / "LaunchAgents" / f"{name}.plist"
            if not plist.exists():
                continue
            cmd = ["launchctl", action]
            if action == "load":
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

    def _enter_macos(self) -> None:
        self.console.print("[cyan]→[/cyan] Switching to native macOS mode")
        self._launchctl("unload", LAUNCH_AGENTS)
        self._kill_processes(PROCESSES)
        self._set_defaults("com.apple.dock", "autohide", False)
        self._set_defaults("com.apple.finder", "CreateDesktop", True)
        self._restart_dock_and_finder()
        self._update_ghostty_mode("macos")
        self._write_state("macos")
        self.console.print("[green]✓[/green] Native mode ready (Dock/Finder restored)")

    def _enter_bsp(self) -> None:
        self.console.print("[cyan]→[/cyan] Switching to BSP tiling mode")
        self._set_defaults("com.apple.dock", "autohide", True)
        self._set_defaults("com.apple.finder", "CreateDesktop", False)
        self._restart_dock_and_finder()
        time.sleep(3)
        self._launchctl("load", LAUNCH_AGENTS)
        time.sleep(1)
        ensure_yabai_sa(self.console)
        self._update_ghostty_mode("bsp")
        self._write_state("bsp")
        self.console.print("[green]✓[/green] BSP mode ready (yabai/skhd/sketchybar loaded)")

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
