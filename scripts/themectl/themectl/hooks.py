"""Runtime automation hooks executed after applying a theme."""

from __future__ import annotations

import json
import os
import platform
import re
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Any, Iterable, Mapping

from rich.console import Console
from rich.panel import Panel

from .config import ThemectlConfig, get_home
from .themes import Theme

EDITOR_SCRIPT = """
on run argv
  set targetApp to item 1 of argv
  set processName to item 2 of argv
  set themeName to item 3 of argv
  tell application targetApp to activate
  delay 0.15
  tell application "System Events"
    if not (exists process processName) then return
    tell process processName
      keystroke "k" using {command down}
      delay 0.05
      keystroke "t" using {command down}
      delay 0.2
      keystroke themeName
      delay 0.1
      key code 36
    end tell
  end tell
end run
"""

GHOSTTY_SCRIPT = """
tell application "System Events"
  if exists process "Ghostty" then
    set frontApp to first application process whose frontmost is true
    set frontName to name of frontApp
    tell application "Ghostty" to activate
    delay 0.05
    keystroke "," using {command down, shift down}
    delay 0.05
    if frontName is not "Ghostty" then
      tell application frontName to activate
    end if
  end if
end tell
"""


def _automation_disabled() -> bool:
    return os.environ.get("THEME_DISABLE_EDITOR_AUTOMATION", "0") == "1"


def _process_running(name: str) -> bool:
    binary = shutil.which("pgrep") or "/usr/bin/pgrep"
    result = subprocess.run(
        [binary, "-x", name],
        capture_output=True,
        text=True,
    )
    return result.returncode == 0


def _read_settings(path: Path) -> dict[str, Any] | None:
    try:
        raw = path.read_text()
    except FileNotFoundError:
        return None
    cleaned = "\n".join(line for line in raw.splitlines() if not line.strip().startswith("//"))
    if not cleaned.strip():
        return {}
    data = json.loads(cleaned)
    if isinstance(data, dict):
        return dict(data)
    return None


def _write_settings(path: Path, data: Mapping[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n")


def _update_editor_settings(
    paths: Iterable[Path],
    theme_name: str,
    console: Console,
    label: str,
) -> bool:
    changed = False
    for path in paths:
        settings = _read_settings(path)
        if settings is None:
            continue
        if settings.get("workbench.colorTheme") == theme_name:
            continue
        settings["workbench.colorTheme"] = theme_name
        _write_settings(path, settings)
        console.print(f"[green]✓[/green] Updated {label} settings at {path}")
        changed = True
    return changed


def _run_osascript(script: str, args: list[str]) -> bool:
    binary = shutil.which("osascript") or "/usr/bin/osascript"
    with tempfile.NamedTemporaryFile("w", suffix=".applescript", delete=False) as handle:
        handle.write(script.strip())
        tmp_path = Path(handle.name)
    try:
        result = subprocess.run(
            [binary, str(tmp_path), *args],
            capture_output=True,
            text=True,
        )
        return result.returncode == 0
    finally:
        tmp_path.unlink(missing_ok=True)


def _trigger_editor_reload(
    app_name: str,
    process_name: str,
    theme_name: str,
    console: Console,
) -> None:
    if platform.system() != "Darwin":
        return
    if _automation_disabled():
        console.print(
            f"[cyan]-[/cyan] {app_name} automation disabled (THEME_DISABLE_EDITOR_AUTOMATION=1)"
        )
        return
    if not _process_running(process_name):
        return
    if _run_osascript(EDITOR_SCRIPT, [app_name, process_name, theme_name]):
        console.print(f"[green]✓[/green] Reloaded {app_name} theme via AppleScript")
    else:
        console.print(
            Panel(
                f"Unable to automate {app_name} theme reload. "
                "Ensure Accessibility permissions are granted to the terminal.",
                title=f"{app_name}",
                border_style="yellow",
            )
        )


def _vscode_settings_paths(platform_name: str) -> list[Path]:
    home = get_home()
    if platform_name == "darwin":
        base = home / "Library" / "Application Support"
        return [base / "Code" / "User" / "settings.json"]
    return [home / ".config" / "Code" / "User" / "settings.json"]


def _cursor_settings_paths(platform_name: str) -> list[Path]:
    home = get_home()
    if platform_name == "darwin":
        base = home / "Library" / "Application Support"
        return [base / "Cursor" / "User" / "settings.json"]
    return [home / ".config" / "Cursor" / "User" / "settings.json"]


def _update_neovim_theme_file(colorscheme: str, console: Console) -> None:
    theme_file = get_home() / ".config" / "nvim" / "lua" / "plugins" / "theme.lua"
    if not theme_file.exists():
        return
    pattern = re.compile(r'colorscheme\s*=\s*"[^"]*"')
    original = theme_file.read_text()
    replacement = f'colorscheme = "{colorscheme}"'
    if pattern.search(original):
        updated, count = pattern.subn(replacement, original, count=1)
    else:
        updated = original.rstrip() + f'\n{replacement}\n'
        count = 1
    if count > 0 and updated != original:
        theme_file.write_text(updated)
        console.print(f"[green]✓[/green] Updated Neovim config to {colorscheme}")


def _reload_neovim_instances(colorscheme: str, console: Console) -> None:
    binary = shutil.which("nvr")
    if not binary:
        console.print("[cyan]-[/cyan] nvr not found; skipping Neovim reload")
        return
    servers = subprocess.run(
        [binary, "--serverlist"],
        capture_output=True,
        text=True,
    )
    if servers.returncode != 0:
        console.print("[yellow]![/yellow] Unable to query nvr servers")
        return
    names = [server.strip() for server in servers.stdout.split() if server.strip()]
    expr = f"execute('colorscheme ''{colorscheme}''')"
    reloaded = 0
    for server in names:
        result = subprocess.run(
            [binary, "--servername", server, "--remote-expr", expr],
            capture_output=True,
            text=True,
        )
        if result.returncode == 0:
            reloaded += 1
    console.print(
        f"[green]✓[/green] Reloaded Neovim theme on {reloaded} instance(s)"
        if reloaded
        else "[cyan]-[/cyan] No Neovim instances reachable via nvr"
    )


def _tmux_config_lines(tmux_section: Mapping[str, str]) -> list[str]:
    return [
        "# Generated by themectl",
        f'set -g status-style "bg={tmux_section.get("statusBackground")},'
        f'fg={tmux_section.get("statusForeground")}"',
        f'set -g window-status-current-style "bg={tmux_section.get("windowStatusCurrent")},'
        f'fg={tmux_section.get("statusBackground")}"',
        f'set -g pane-active-border-style "fg={tmux_section.get("paneActiveBorder")}"',
        f'set -g pane-border-style "fg={tmux_section.get("paneInactiveBorder")}"',
    ]


def _update_tmux_config(theme: Theme, console: Console) -> None:
    tmux_section = theme.section("tmux")
    if not tmux_section:
        return
    if not all(
        key in tmux_section
        for key in ("statusBackground", "statusForeground", "windowStatusCurrent")
    ):
        return
    home = get_home()
    conf_local = home / ".tmux.conf.local"
    conf_local.parent.mkdir(parents=True, exist_ok=True)
    conf_local.write_text("\n".join(_tmux_config_lines(tmux_section)) + "\n")
    binary = shutil.which("tmux")
    if not binary:
        console.print("[cyan]-[/cyan] tmux not found; wrote ~/.tmux.conf.local")
        return
    main_conf = home / ".tmux.conf"
    subprocess.run(
        [binary, "source-file", str(main_conf)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    console.print("[green]✓[/green] Reloaded tmux theme")


def _find_binary(name: str, extra_paths: Iterable[Path]) -> str | None:
    binary = shutil.which(name)
    if binary:
        return binary
    for candidate in extra_paths:
        if candidate.exists():
            return str(candidate)
    return None


def reload_alacritty(console: Console) -> None:
    binary = _find_binary(
        "alacritty",
        [
            Path("/run/current-system/sw/bin/alacritty"),
            Path("/nix/var/nix/profiles/default/bin/alacritty"),
            Path("/Applications/Alacritty.app/Contents/MacOS/alacritty"),
        ],
    )
    if not binary:
        console.print("[cyan]-[/cyan] Alacritty not found; skipping reload")
        return
    result = subprocess.run(
        [binary, "msg", "config", "reload"],
        capture_output=True,
        text=True,
    )
    if result.returncode == 0:
        console.print("[green]✓[/green] Reloaded Alacritty config")
        return
    signaler = shutil.which("pkill") or shutil.which("killall")
    if not signaler:
        console.print(
            Panel(
                "Unable to reload Alacritty config: message API failed and pkill/killall not available.",
                title="Alacritty reload",
                border_style="yellow",
            )
        )
        return
    names = ["alacritty", "Alacritty"]
    for name in names:
        subprocess.run(
            [signaler, "-USR1", name],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    console.print("[yellow]![/yellow] Sent SIGUSR1 to Alacritty (msg reload failed)")


def _discover_hypr_signature() -> str | None:
    signature = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if signature:
        return signature
    runtime_dir = os.environ.get("XDG_RUNTIME_DIR")
    if not runtime_dir:
        return None
    hypr_dir = Path(runtime_dir) / "hypr"
    if not hypr_dir.exists():
        return None
    try:
        candidates = sorted(
            (entry for entry in hypr_dir.iterdir() if entry.is_dir()),
            key=lambda path: path.stat().st_mtime,
            reverse=True,
        )
    except OSError:
        return None
    if not candidates:
        return None
    return candidates[0].name


def reload_hyprland(console: Console) -> None:
    if platform.system() != "Linux":
        return
    binary = shutil.which("hyprctl")
    if not binary:
        console.print("[cyan]-[/cyan] hyprctl not found; skipping Hyprland reload")
        return
    signature = _discover_hypr_signature()
    if not signature:
        console.print("[cyan]-[/cyan] Hyprland signature unavailable; skipping reload")
        return
    env = os.environ.copy()
    env["HYPRLAND_INSTANCE_SIGNATURE"] = signature
    result = subprocess.run(
        [binary, "-i", signature, "reload"],
        capture_output=True,
        text=True,
        env=env,
    )
    if result.returncode == 0:
        console.print("[green]✓[/green] Reloaded Hyprland config")
    else:
        console.print(
            Panel(
                result.stderr.strip() or "hyprctl reload failed",
                title="Hyprland reload",
                border_style="yellow",
            )
        )


def update_wallpaper(console: Console) -> None:
    if platform.system() != "Linux":
        return
    background = get_home() / ".config" / "omarchy" / "current" / "background"
    if not background.exists():
        return
    binary = shutil.which("swww")
    if not binary:
        console.print("[cyan]-[/cyan] swww not found; skipping wallpaper refresh")
        return
    result = subprocess.run(
        [
            binary,
            "img",
            str(background),
            "--transition-type",
            "simple",
            "--transition-step",
            "255",
        ],
        capture_output=True,
        text=True,
    )
    if result.returncode == 0:
        console.print("[green]✓[/green] Updated wallpaper via swww")
    else:
        console.print(
            Panel(
                result.stderr.strip() or "swww img failed",
                title="Wallpaper reload",
                border_style="yellow",
            )
        )


def reload_ghostty(console: Console) -> None:
    config = get_home() / ".config" / "ghostty" / "config"
    if not config.exists():
        return
    binary = shutil.which("ghostty")
    if binary:
        result = subprocess.run(
            [binary, "+reload-config"],
            capture_output=True,
            text=True,
        )
        if result.returncode == 0:
            console.print("[green]✓[/green] Reloaded Ghostty config")
            return
    if platform.system() == "Darwin" and _process_running("Ghostty"):
        if _run_osascript(GHOSTTY_SCRIPT, []):
            console.print("[green]✓[/green] Reloaded Ghostty via automation")
            return
    console.print("[yellow]![/yellow] Ghostty reload skipped (app not running)")


def _refresh_vscode(theme: Theme, cfg: ThemectlConfig, console: Console) -> None:
    if not cfg.editor_automation.vscode:
        return
    theme_name = theme.vscode_theme
    if not theme_name:
        return
    changed = _update_editor_settings(_vscode_settings_paths(cfg.platform), theme_name, console, "VSCode")
    if changed:
        _trigger_editor_reload("Visual Studio Code", "Code", theme_name, console)


def _refresh_cursor(theme: Theme, cfg: ThemectlConfig, console: Console) -> None:
    if not cfg.editor_automation.cursor:
        return
    theme_name = theme.cursor_theme or theme.vscode_theme
    if not theme_name:
        return
    changed = _update_editor_settings(_cursor_settings_paths(cfg.platform), theme_name, console, "Cursor")
    if changed:
        _trigger_editor_reload("Cursor", "Cursor", theme_name, console)


def _refresh_neovim(theme: Theme, cfg: ThemectlConfig, console: Console) -> None:
    if not cfg.editor_automation.neovim:
        return
    colorscheme = theme.nvim_colorscheme or "tokyonight"
    _update_neovim_theme_file(colorscheme, console)
    _reload_neovim_instances(colorscheme, console)


def run_reload_hooks(theme: Theme, cfg: ThemectlConfig, console: Console) -> None:
    actions = (
        ("VSCode", lambda: _refresh_vscode(theme, cfg, console)),
        ("Cursor", lambda: _refresh_cursor(theme, cfg, console)),
        ("Neovim", lambda: _refresh_neovim(theme, cfg, console)),
        ("tmux", lambda: _update_tmux_config(theme, console)),
        ("Alacritty", lambda: reload_alacritty(console)),
        ("Hyprland", lambda: reload_hyprland(console)),
        ("Wallpaper", lambda: update_wallpaper(console)),
        ("Ghostty", lambda: reload_ghostty(console)),
    )
    for label, action in actions:
        try:
            action()
        except Exception as exc:  # pragma: no cover - defensive logging
            console.print(
                Panel(
                  f"{exc}",
                  title=f"{label} automation failed",
                  border_style="red",
                )
            )
