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
  if exists process "ghostty" then
    set frontApp to first application process whose frontmost is true
    set frontName to name of frontApp
    tell process "ghostty" to set frontmost to true
    delay 0.1
    keystroke "," using {command down, shift down}
    delay 0.1
    if frontName is not "ghostty" then
      tell process frontName to set frontmost to true
    end if
  end if
end tell
"""

MAC_WALLPAPER_SCRIPT = """
on run argv
  set targetPath to item 1 of argv
  set targetFile to POSIX file targetPath as alias
  tell application "System Events"
    repeat with desktopRef in desktops
      set picture of desktopRef to targetFile
    end repeat
  end tell
end run
"""

MAC_APPEARANCE_SCRIPT = """
on run argv
  set wantDark to (item 1 of argv) is "dark"
  tell application "System Events"
    tell appearance preferences
      if dark mode is not wantDark then set dark mode to wantDark
    end tell
  end tell
end run
"""


def _macos_is_dark() -> bool | None:
    """Return True/False for the current macOS appearance, None if unknown."""
    result = subprocess.run(
        ["/usr/bin/defaults", "read", "-g", "AppleInterfaceStyle"],
        capture_output=True,
        text=True,
    )
    if result.returncode == 0:
        return result.stdout.strip().lower() == "dark"
    # The key is absent entirely when light mode is active.
    if "does not exist" in (result.stderr or ""):
        return False
    return None


def update_system_appearance(theme: Theme, console: Console) -> None:
    """Switch the OS light/dark appearance to match the theme's `kind`.

    macOS: System Events `appearance preferences` (same automation channel the
    wallpaper hook uses, so no new TCC prompt). cmux's app chrome, Ghostty's
    `window-theme = ghostty`, and every native app follow this in real time.
    Linux: gsettings color-scheme, which GTK apps and portals honour.
    """
    want = "light" if theme.is_light else "dark"
    system = platform.system()
    if system == "Darwin":
        if _automation_disabled():
            return
        current = _macos_is_dark()
        if current is not None and current == (want == "dark"):
            console.print(f"[cyan]-[/cyan] macOS appearance already {want}")
            return
        if _run_osascript(MAC_APPEARANCE_SCRIPT, [want]):
            console.print(f"[green]✓[/green] Set macOS appearance to {want}")
        else:
            console.print(
                "[yellow]![/yellow] Could not set macOS appearance "
                "(grant Automation → System Events to your terminal)"
            )
        return
    gsettings = shutil.which("gsettings")
    if not gsettings:
        return
    scheme = "prefer-light" if want == "light" else "prefer-dark"
    result = subprocess.run(
        [gsettings, "set", "org.gnome.desktop.interface", "color-scheme", scheme],
        capture_output=True,
        text=True,
    )
    if result.returncode == 0:
        console.print(f"[green]✓[/green] Set GTK color-scheme to {scheme}")


def _automation_disabled() -> bool:
    return os.environ.get("THEME_DISABLE_EDITOR_AUTOMATION", "0") == "1"


def _process_running(name: str) -> bool:
    if platform.system() == "Darwin":
        # BSD pgrep excludes itself and its ancestors by default, so a terminal
        # running themectl would never be "found". -a includes ancestors.
        args = ["/usr/bin/pgrep", "-a", "-x", name]
    else:
        binary = shutil.which("pgrep") or "/usr/bin/pgrep"
        args = [binary, "-x", name]
    result = subprocess.run(args, capture_output=True, text=True)
    return result.returncode == 0


def _read_settings(path: Path) -> dict[str, Any] | None:
    try:
        raw = path.read_text()
    except FileNotFoundError:
        return None
    data = json.loads(_strip_jsonc(raw)) if raw.strip() else {}
    if isinstance(data, dict):
        return dict(data)
    return None


def _strip_jsonc(raw: str) -> str:
    """Make VSCode-style JSONC (comments + trailing commas) parseable.

    Scans character by character so comment markers inside strings
    (e.g. "https://x/*") are left untouched.
    """
    out: list[str] = []
    i, n = 0, len(raw)
    while i < n:
        ch = raw[i]
        if ch == '"':
            j = i + 1
            while j < n and raw[j] != '"':
                j += 2 if raw[j] == "\\" else 1
            out.append(raw[i : j + 1])
            i = j + 1
        elif raw.startswith("//", i):
            j = raw.find("\n", i)
            i = n if j == -1 else j
        elif raw.startswith("/*", i):
            j = raw.find("*/", i + 2)
            i = n if j == -1 else j + 2
        else:
            out.append(ch)
            i += 1
    return re.sub(r",(\s*[}\]])", r"\1", "".join(out))


def _write_settings(path: Path, data: Mapping[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n")


_COLOR_THEME_RE = re.compile(r'("workbench\.colorTheme"\s*:\s*)"(?:[^"\\]|\\.)*"')


def _set_color_theme(path: Path, theme_name: str) -> None:
    """Rewrite workbench.colorTheme in place, preserving comments/formatting."""
    raw = path.read_text() if path.exists() else ""
    if _COLOR_THEME_RE.search(raw):
        path.write_text(
            _COLOR_THEME_RE.sub(rf"\g<1>{json.dumps(theme_name)}", raw, count=1)
        )
        return
    settings = _read_settings(path) or {}
    settings["workbench.colorTheme"] = theme_name
    _write_settings(path, settings)


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
        _set_color_theme(path, theme_name)
        console.print(f"[green]✓[/green] Updated {label} settings at {path}")
        changed = True
    return changed


def _run_osascript(script: str, args: list[str]) -> bool:
    binary = shutil.which("osascript") or "/usr/bin/osascript"
    with tempfile.NamedTemporaryFile(
        "w", suffix=".applescript", delete=False
    ) as handle:
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
        updated = original.rstrip() + f"\n{replacement}\n"
        count = 1
    if count > 0 and updated != original:
        theme_file.write_text(updated)
        console.print(f"[green]✓[/green] Updated Neovim config to {colorscheme}")


def _get_nvim_colorscheme_command(colorscheme: str, light: bool = False) -> str:
    """Generate the appropriate Lua/Vim command to set a colorscheme.

    Some colorscheme plugins require setup() to select variants:
    - catppuccin: needs flavour set via setup()
    - monokai-pro: needs filter set via setup()

    Also sets vim background (light/dark) from the theme's `kind`.
    """
    bg = "light" if light else "dark"
    bg_cmd = f"set background={bg}"

    # Catppuccin variants: catppuccin-latte, catppuccin-frappe, catppuccin-macchiato, catppuccin-mocha
    if colorscheme.startswith("catppuccin-"):
        flavour = colorscheme.replace("catppuccin-", "")
        return f"lua vim.o.background='{bg}' require('catppuccin').setup({{flavour='{flavour}'}}) vim.cmd('colorscheme catppuccin')"

    # Monokai-pro variants: monokai-pro-ristretto, monokai-pro-classic, etc.
    if colorscheme.startswith("monokai-pro-"):
        filter_name = colorscheme.replace("monokai-pro-", "")
        return f"lua vim.o.background='{bg}' require('monokai-pro').setup({{filter='{filter_name}'}}) vim.cmd('colorscheme monokai-pro')"

    # Default: set background then colorscheme
    return f"{bg_cmd} | colorscheme {colorscheme}"


def _reload_neovim_instances(
    colorscheme: str, console: Console, light: bool = False
) -> None:
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
    cmd = _get_nvim_colorscheme_command(colorscheme, light)
    reloaded = 0
    for server in names:
        # Use -c to send command directly (--remote-expr with execute() doesn't work reliably)
        result = subprocess.run(
            [binary, "--servername", server, "-c", cmd],
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
    # Alacritty.app watches the config file for changes and auto-reloads
    # Use sudo touch since config is a symlink to immutable nix store
    home = get_home()
    config = home / ".config" / "alacritty" / "alacritty.toml"

    if not config.exists():
        console.print("[cyan]-[/cyan] Alacritty config not found; skipping reload")
        return

    sudo = shutil.which("sudo") or "/usr/bin/sudo"
    touch = shutil.which("touch") or "/usr/bin/touch"

    result = subprocess.run(
        [sudo, touch, str(config)],
        capture_output=True,
        text=True,
    )

    if result.returncode == 0:
        console.print("[green]✓[/green] Reloaded Alacritty config (all windows)")
    else:
        console.print(
            Panel(
                f"Unable to touch Alacritty config: {result.stderr.strip()}",
                title="Alacritty reload",
                border_style="yellow",
            )
        )


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
    background = get_home() / ".config" / "omarchy" / "current" / "background"
    if not background.exists():
        return
    target = _wallpaper_target(background)
    system = platform.system()
    if system == "Linux":
        _update_wallpaper_linux(target, console)
    elif system == "Darwin":
        _update_wallpaper_macos(target, console)


def _update_wallpaper_linux(background: Path, console: Console) -> None:
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


def _wallpaper_target(background: Path) -> Path:
    if background.is_symlink():
        try:
            return background.resolve(strict=True)
        except FileNotFoundError:
            return background
    return background


def _update_wallpaper_macos(background: Path, console: Console) -> None:
    desktoppr = shutil.which("desktoppr")
    if desktoppr:
        result = subprocess.run(
            [desktoppr, str(background)],
            capture_output=True,
            text=True,
        )
        if result.returncode == 0:
            console.print("[green]✓[/green] Updated macOS wallpaper via desktoppr")
            return
        console.print(
            Panel(
                result.stderr.strip() or "desktoppr failed",
                title="Wallpaper reload",
                border_style="yellow",
            )
        )

    if _run_osascript(MAC_WALLPAPER_SCRIPT, [str(background)]):
        console.print("[green]✓[/green] Updated macOS wallpaper across desktops")
        return

    console.print(
        Panel(
            "Unable to set wallpaper via System Events (check Accessibility permissions).",
            title="Wallpaper reload",
            border_style="yellow",
        )
    )
    if _write_defaults_wallpaper(background, console):
        _restart_dock(console)


def _write_defaults_wallpaper(background: Path, console: Console) -> bool:
    defaults = shutil.which("defaults") or "/usr/bin/defaults"
    payload = f'{{default = {{ImageFilePath = "{background}"; }};}}'
    result = subprocess.run(
        [
            defaults,
            "-currentHost",
            "write",
            "com.apple.desktop",
            "Background",
            payload,
        ],
        capture_output=True,
        text=True,
    )
    if result.returncode == 0:
        console.print("[green]✓[/green] Updated macOS defaults wallpaper record")
        return True
    console.print(
        Panel(
            result.stderr.strip() or "defaults write failed",
            title="Wallpaper defaults",
            border_style="yellow",
        )
    )
    return False


def _restart_dock(console: Console) -> None:
    result = subprocess.run(
        ["killall", "Dock"],
        capture_output=True,
        text=True,
    )
    if result.returncode == 0:
        console.print("[green]✓[/green] Restarted Dock to apply wallpapers")
    else:
        console.print(
            Panel(
                result.stderr.strip() or "killall Dock failed",
                title="Dock restart",
                border_style="yellow",
            )
        )


def update_ghostty(theme: Theme, console: Console) -> None:
    """Update Ghostty theme in main config file."""
    home = get_home()
    config_file = home / ".config" / "ghostty" / "config"

    if not config_file.exists():
        console.print("[yellow]-[/yellow] Ghostty config not found")
        return

    # Get theme name from theme definition
    ghostty_section = theme.section("ghostty")
    if not ghostty_section:
        console.print(
            f"[yellow]-[/yellow] No Ghostty theme defined for {theme.display_name}"
        )
        return

    theme_name = ghostty_section.get("theme")
    if not theme_name:
        console.print(
            f"[yellow]-[/yellow] No Ghostty theme name for {theme.display_name}"
        )
        return

    # Read and update config
    content = config_file.read_text()
    lines = content.split("\n")
    new_lines = []
    updated = False

    for line in lines:
        if line.startswith("theme =") or line.startswith("theme="):
            new_lines.append(f"theme = {theme_name}")
            updated = True
        else:
            new_lines.append(line)

    if updated:
        config_file.write_text("\n".join(new_lines))
        console.print(f"[green]✓[/green] Updated Ghostty theme to {theme_name}")
    else:
        console.print("[yellow]-[/yellow] No theme line found in Ghostty config")


def reload_cmux(console: Console) -> None:
    """Reload cmux in place (macOS only).

    cmux embeds libghostty and reads ~/.config/ghostty/config for terminal
    colors; `cmux reload-config` re-reads that file plus cmux.json and
    refreshes every terminal surface without a restart. The app chrome
    (sidebar, tabs) follows the macOS appearance, which
    update_system_appearance() flips to match the theme.
    """
    if platform.system() != "Darwin":
        return
    if not _process_running("cmux"):
        console.print("[cyan]-[/cyan] cmux not running; skipping reload")
        return
    binary = shutil.which("cmux") or "/usr/local/bin/cmux"
    if not Path(binary).exists():
        console.print("[yellow]![/yellow] cmux CLI not found; skipping reload")
        return
    result = subprocess.run([binary, "reload-config"], capture_output=True, text=True)
    if result.returncode == 0:
        console.print("[green]✓[/green] Reloaded cmux (Ghostty config + cmux.json)")
    else:
        console.print(
            Panel(
                result.stderr.strip()
                or result.stdout.strip()
                or "cmux reload-config failed",
                title="cmux reload",
                border_style="yellow",
            )
        )


def reload_ghostty(console: Console) -> None:
    """Reload the standalone Ghostty app if it is running.

    Ghostty has no CLI reload action; on macOS we send its reload keystroke
    (Cmd+Shift+,) via System Events. Linux users rely on Ghostty's own
    config-file watcher / keybind.
    """
    config = get_home() / ".config" / "ghostty" / "config"
    if not config.exists():
        return
    if platform.system() != "Darwin":
        console.print("[cyan]-[/cyan] Ghostty reload is manual on Linux (Ctrl+Shift+,)")
        return
    if _automation_disabled():
        return
    if not (_process_running("ghostty") or _process_running("Ghostty")):
        console.print("[cyan]-[/cyan] Ghostty not running; skipping reload")
        return
    if _run_osascript(GHOSTTY_SCRIPT, []):
        console.print("[green]✓[/green] Reloaded Ghostty via automation")
    else:
        console.print("[yellow]![/yellow] Ghostty reload keystroke failed")


def _ensure_extension_installed(
    editor_cmd: str, extension_id: str, console: Console, label: str
) -> None:
    """Install VSCode/Cursor extension if not already installed."""
    binary = shutil.which(editor_cmd)
    if not binary:
        return

    # Check if extension is installed
    result = subprocess.run(
        [binary, "--list-extensions"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return

    installed = result.stdout.strip().split("\n")
    if extension_id.lower() in [ext.lower() for ext in installed]:
        return

    # Install extension
    console.print(f"[cyan]...[/cyan] Installing {label} extension: {extension_id}")
    install_result = subprocess.run(
        [binary, "--install-extension", extension_id],
        capture_output=True,
        text=True,
    )
    if install_result.returncode == 0:
        console.print(f"[green]✓[/green] Installed {label} extension: {extension_id}")
    else:
        console.print(
            f"[yellow]![/yellow] Failed to install {label} extension: {extension_id}"
        )


def _refresh_vscode(theme: Theme, cfg: ThemectlConfig, console: Console) -> None:
    if not cfg.editor_automation.vscode:
        return
    theme_name = theme.vscode_theme
    if not theme_name:
        return

    # Install extension if needed
    extension_id = theme.vscode_extension
    if extension_id:
        _ensure_extension_installed("code", extension_id, console, "VSCode")

    # Update settings.json - VSCode auto-reloads when the file changes
    _update_editor_settings(
        _vscode_settings_paths(cfg.platform), theme_name, console, "VSCode"
    )


def _refresh_cursor(theme: Theme, cfg: ThemectlConfig, console: Console) -> None:
    if not cfg.editor_automation.cursor:
        return
    theme_name = theme.cursor_theme or theme.vscode_theme
    if not theme_name:
        return

    # Install extension if needed
    # cursor_extension="" means explicitly skip (not available in Cursor marketplace)
    # cursor_extension=None means fallback to vscode_extension
    cursor_ext = theme.cursor_extension
    if cursor_ext is None:
        extension_id = theme.vscode_extension
    elif cursor_ext:
        extension_id = cursor_ext
    else:
        extension_id = None  # Empty string = skip installation

    if extension_id:
        _ensure_extension_installed("cursor", extension_id, console, "Cursor")

    # Update settings.json - Cursor auto-reloads when the file changes
    _update_editor_settings(
        _cursor_settings_paths(cfg.platform), theme_name, console, "Cursor"
    )


def _refresh_neovim(theme: Theme, cfg: ThemectlConfig, console: Console) -> None:
    if not cfg.editor_automation.neovim:
        return
    colorscheme = theme.nvim_colorscheme or "tokyonight"
    _update_neovim_theme_file(colorscheme, console)
    _reload_neovim_instances(colorscheme, console, theme.is_light)


def update_btop(theme: Theme, console: Console) -> None:
    """Update btop theme configuration."""
    home = get_home()
    btop_themes_dir = home / ".config" / "btop" / "themes"
    btop_conf = home / ".config" / "btop" / "btop.conf"

    # Check if theme exists in btop themes directory (deployed by Nix)
    theme_file = btop_themes_dir / f"{theme.slug}.theme"

    if not theme_file.exists():
        console.print(
            f"[yellow]-[/yellow] btop theme not available for {theme.display_name}"
        )
        return

    # Update btop.conf to use this theme
    if not btop_conf.exists():
        console.print("[yellow]-[/yellow] btop.conf not found")
        return

    content = btop_conf.read_text()
    lines = content.split("\n")
    new_lines = []
    updated = False

    for line in lines:
        if line.startswith("color_theme"):
            new_lines.append(f'color_theme = "{theme.slug}"')
            updated = True
        else:
            new_lines.append(line)

    if updated:
        btop_conf.write_text("\n".join(new_lines))
        # Send SIGUSR2 to reload config in running btop instances
        try:
            subprocess.run(["pkill", "-USR2", "btop"], capture_output=True)
        except Exception:
            pass  # btop may not be running
        console.print(f"[green]✓[/green] Updated btop theme to {theme.slug}")
    else:
        console.print("[yellow]-[/yellow] No color_theme line found in btop.conf")


def run_reload_hooks(theme: Theme, cfg: ThemectlConfig, console: Console) -> None:
    actions = (
        ("VSCode", lambda: _refresh_vscode(theme, cfg, console)),
        ("Cursor", lambda: _refresh_cursor(theme, cfg, console)),
        ("Neovim", lambda: _refresh_neovim(theme, cfg, console)),
        ("tmux", lambda: _update_tmux_config(theme, console)),
        ("Alacritty", lambda: reload_alacritty(console)),
        ("Hyprland", lambda: reload_hyprland(console)),
        ("Wallpaper", lambda: update_wallpaper(console)),
        ("System appearance", lambda: update_system_appearance(theme, console)),
        ("Ghostty (update)", lambda: update_ghostty(theme, console)),
        ("cmux (reload)", lambda: reload_cmux(console)),
        ("Ghostty (reload)", lambda: reload_ghostty(console)),
        ("btop", lambda: update_btop(theme, console)),
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
