"""Asset synchronization utilities."""

from __future__ import annotations

import json
from pathlib import Path
import shutil
from typing import Mapping

from rich.console import Console

from .config import get_home
from .themes import Theme, ThemeRepository

console = Console()


def _ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def _write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content.rstrip() + "\n")


def _hex_to_rgb(color: str) -> tuple[int, int, int] | None:
    if not isinstance(color, str):
        return None
    value = color.strip()
    if not value.startswith("#") or len(value) not in (4, 7):
        return None
    value = value.lstrip("#")
    if len(value) == 3:
        value = "".join(ch * 2 for ch in value)
    try:
        r = int(value[0:2], 16)
        g = int(value[2:4], 16)
        b = int(value[4:6], 16)
    except ValueError:
        return None
    return (r, g, b)


def _render_hyprland(theme: Theme) -> str:
    hypr = theme.section("hyprland")
    active = hypr.get("activeBorder", "rgba(ffffffff)")
    inactive = hypr.get("inactiveBorder", "rgba(000000ff)")
    return (
        f"# Hyprland border colors for {theme.display_name}\n"
        "general {\n"
        f"  col.active_border = {active}\n"
        f"  col.inactive_border = {inactive}\n"
        "}\n"
    )


def _render_waybar(theme: Theme) -> str:
    waybar = theme.section("waybar")
    fg = waybar.get("foreground", "#ffffff")
    bg = waybar.get("background", "#000000")
    return (
        f"/* Waybar colors for {theme.display_name} */\n"
        f"@define-color foreground {fg};\n"
        f"@define-color background {bg};\n"
    )


def _render_alacritty(theme: Theme) -> str:
    alacritty = theme.section("alacritty")
    if not alacritty:
        return ""

    def render_section(name: str) -> str:
        section = alacritty.get(name, {})
        if not isinstance(section, Mapping):
            return ""
        lines = [f"[colors.{name}]"]
        for key, value in section.items():
            lines.append(f'{key} = "{value}"')
        return "\n".join(lines)

    pieces = [
        f"# Alacritty colors for {theme.display_name}",
        render_section("primary"),
        render_section("normal"),
        render_section("bright"),
    ]
    return "\n\n".join(filter(None, pieces))


def _render_kitty(theme: Theme) -> str:
    kitty = theme.section("kitty")
    if not kitty:
        return ""
    ordered_keys = [
        "foreground",
        "background",
        "selection_foreground",
        "selection_background",
        "cursor",
        "cursor_text_color",
        "url_color",
        "active_border_color",
        "inactive_border_color",
        "active_tab_foreground",
        "active_tab_background",
        "inactive_tab_foreground",
        "inactive_tab_background",
    ]
    lines = [f"# Kitty colors for {theme.display_name}", "", "# Basic colors"]
    for key in ordered_keys:
        if key in kitty:
            lines.append(f"{key.replace('_', ' ')} {kitty[key]}")

    lines.append("\n# The basic 16 colors")
    for i in range(16):
        key = f"color{i}"
        if key in kitty:
            lines.append(f"{key} {kitty[key]}")

    for i in (16, 17):
        key = f"color{i}"
        if key in kitty:
            lines.append(f"{key} {kitty[key]}")

    return "\n".join(lines)


def _render_ghostty(theme: Theme) -> str:
    ghostty = theme.section("ghostty")
    if not ghostty:
        return ""

    if "theme" in ghostty and len(ghostty) == 1:
        return f"theme = {ghostty['theme']}\n"

    lines: list[str] = []
    for key, value in ghostty.items():
        if key == "palette" and isinstance(value, list):
            for entry in value:
                lines.append(f"palette = {entry}")
        else:
            lines.append(f"{key} = {value}")
    return "\n".join(lines)


def _render_walker(theme: Theme) -> str:
    walker = theme.section("walker")
    if not walker:
        return ""
    selected = walker.get("selectedText", "#ffffff")
    text = walker.get("text", "#ffffff")
    base = walker.get("base", "#000000")
    border = walker.get("border", "#ffffff")
    return (
        f"/* Walker launcher colors for {theme.display_name} */\n"
        f"@define-color selected-text {selected};\n"
        f"@define-color text {text};\n"
        f"@define-color base {base};\n"
        f"@define-color border {border};\n"
        f"@define-color foreground {text};\n"
        f"@define-color background {base};\n"
    )


def _render_mako(theme: Theme) -> str:
    mako = theme.section("mako")
    if not mako:
        return ""
    text = mako.get("textColor", "#ffffff")
    border = mako.get("borderColor", "#ffffff")
    background = mako.get("backgroundColor", "#000000")
    progress = mako.get("progressColor", text)
    return (
        f"# Mako notification config for {theme.display_name}\n"
        "include=$HOME/.config/mako/core.ini\n\n"
        f"text-color={text}\n"
        f"border-color={border}\n"
        f"background-color={background}\n"
        f"progress-color={progress}\n"
    )


def _render_swayosd(theme: Theme) -> str:
    swayosd = theme.section("swayosd")
    if not swayosd:
        return ""
    bg = swayosd.get("backgroundColor", "#000000")
    border = swayosd.get("borderColor", "#ffffff")
    text = swayosd.get("textColor", "#ffffff")
    return f"""/* SwayOSD theme for {theme.display_name} */
window {{
  background-color: {bg};
  border: 2px solid {border};
  border-radius: 0;
}}

label, image {{
  color: {text};
}}

progressbar {{
  background-color: {bg};
}}

trough {{
  background-color: {border};
}}

progress {{
  background-color: {text};
}}
"""


def _render_vscode(theme: Theme) -> str:
    if not theme.vscode_theme:
        return ""
    return json.dumps({"workbench.colorTheme": theme.vscode_theme}, indent=2)


def _render_chromium(theme: Theme) -> str:
    browser = theme.section("browser")
    theme_color = browser.get("themeColor")
    if not theme_color:
        return ""
    return str(theme_color)


def _render_neovim(theme: Theme) -> str:
    colorscheme = theme.nvim_colorscheme or "tokyonight"
    return f'return "{colorscheme}"\n'


def _render_hyprlock(theme: Theme, fallback_hex: str) -> str:
    hyprlock = theme.section("hyprlock")
    if not hyprlock:
        return ""
    outer = _hex_to_rgb(hyprlock.get("outerColor", fallback_hex))
    inner = _hex_to_rgb(hyprlock.get("innerColor", fallback_hex))
    font = _hex_to_rgb(hyprlock.get("fontColor", fallback_hex))
    check = _hex_to_rgb(hyprlock.get("checkColor", fallback_hex))
    base = _hex_to_rgb(fallback_hex)
    if not all([outer, inner, font, check, base]):
        return ""

    def rgba(values: tuple[int, int, int], alpha: float = 1.0) -> str:
        return f"rgba({values[0]},{values[1]},{values[2]},{alpha})"

    return "\n".join(
        [
            f"# hyprlock colors for {theme.display_name}",
            f"$color = {rgba(base)}",
            f"$inner_color = {rgba(inner, 0.8)}",
            f"$outer_color = {rgba(outer)}",
            f"$font_color = {rgba(font)}",
            f"$check_color = {rgba(check)}",
            "",
        ]
    )


def _copy_wallpapers(theme: Theme, dest_dir: Path, console: Console) -> None:
    if not theme.wallpapers:
        return
    _ensure_dir(dest_dir)
    for src in theme.wallpapers:
        if not src or not src.exists():
            console.print(f"[yellow]Skipping missing wallpaper {src}")
            continue
        target = dest_dir / src.name
        shutil.copy2(src, target)


def sync_assets(repo: ThemeRepository, console: Console | None = None) -> None:
    console = console or Console()
    base = get_home() / ".config" / "omarchy"
    themes_root = base / "themes"
    _ensure_dir(themes_root)

    for theme in repo:
        dest = themes_root / theme.slug
        if dest.exists():
            shutil.rmtree(dest)
        dest.mkdir(parents=True)

        hyprland = _render_hyprland(theme)
        if hyprland:
            _write_text(dest / "hyprland.conf", hyprland)

        waybar = _render_waybar(theme)
        if waybar:
            _write_text(dest / "waybar.css", waybar)

        alacritty = _render_alacritty(theme)
        if alacritty:
            _write_text(dest / "alacritty.toml", alacritty)

        kitty = _render_kitty(theme)
        if kitty:
            _write_text(dest / "kitty.conf", kitty)

        ghostty = _render_ghostty(theme)
        if ghostty:
            _write_text(dest / "ghostty.conf", ghostty)

        walker = _render_walker(theme)
        if walker:
            _write_text(dest / "walker.css", walker)

        mako = _render_mako(theme)
        if mako:
            _write_text(dest / "mako.ini", mako)

        swayosd = _render_swayosd(theme)
        if swayosd:
            _write_text(dest / "swayosd.css", swayosd)

        vscode = _render_vscode(theme)
        if vscode:
            _write_text(dest / "vscode.json", vscode)

        chromium = _render_chromium(theme)
        if chromium:
            _write_text(dest / "chromium.theme", chromium)

        neovim = _render_neovim(theme)
        if neovim:
            _write_text(dest / "neovim.lua", neovim)

        alacritty_section = theme.section("alacritty")
        primary_bg = ""
        primary = alacritty_section.get("primary")
        if isinstance(primary, Mapping):
            primary_bg = primary.get("background", "#000000")

        hyprlock = _render_hyprlock(theme, primary_bg or "#000000")
        if hyprlock:
            _write_text(dest / "hyprlock.conf", hyprlock)

        _copy_wallpapers(theme, dest / "backgrounds", console)

        console.print(f"[green]•[/green] Synced {theme.display_name}")
