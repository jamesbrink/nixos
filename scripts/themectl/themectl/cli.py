"""Typer entrypoint for themectl."""

from __future__ import annotations

import shutil
from pathlib import Path
from typing import Any, Mapping, Optional

import typer
from rich import box
from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from typer import Exit

from . import __version__
from .assets import sync_assets
from .config import ThemectlConfig, get_home, load_config
from .hotkeys import flatten_bindings, load_manifest
from .hooks import run_reload_hooks, update_wallpaper
from .macos import (
    MacOSModeController,
    ensure_tcc_permissions,
    ensure_yabai_sa,
)
from .state import (
    read_current_background_path,
    read_current_theme,
    write_background_path,
)
from .themes import Theme, ThemeRepository, load_theme_metadata

console = Console()
app = typer.Typer(no_args_is_help=True, help="Unified theme automation CLI.")


def _load(cfg_path: Optional[Path] = None) -> ThemectlConfig:
    return load_config(cfg_path)


def _load_repo(cfg: ThemectlConfig) -> ThemeRepository:
    return load_theme_metadata(cfg.metadata_path)


def _write_state(cfg: ThemectlConfig, slug: str) -> None:
    path = cfg.state_path
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(slug)


def _safe_symlink(target: Path, link: Path) -> None:
    if link.is_symlink():
        link.unlink()
    elif link.exists():
        if link.is_dir():
            shutil.rmtree(link)
        else:
            link.unlink()
    link.parent.mkdir(parents=True, exist_ok=True)
    link.symlink_to(target)


def _walker_assets_ok(cfg: ThemectlConfig, console: Console) -> bool:
    if cfg.platform != "linux":
        return True

    home = get_home()
    themes_root = home / ".config" / "omarchy" / "themes"
    current_theme = home / ".config" / "omarchy" / "current" / "theme"

    if not themes_root.exists():
        console.print(
            "[red]Walker assets missing under ~/.config/omarchy/themes. Run `themectl sync-assets`.[/red]"
        )
        return False

    ok = True
    missing = sorted(
        path.name
        for path in themes_root.iterdir()
        if path.is_dir() and not (path / "walker.css").exists()
    )
    if missing:
        console.print(
            Panel(
                "Walker CSS not found for:\n- " + "\n- ".join(missing),
                title="Walker themes incomplete",
                border_style="red",
            )
        )
        ok = False

    if not current_theme.is_symlink():
        console.print(
            Panel(
                "Current theme symlink is missing. Run `themectl apply <theme>` so Walker picks up runtime colors.",
                title="Walker symlink missing",
                border_style="yellow",
            )
        )
        ok = False
    else:
        try:
            target = current_theme.resolve()
        except OSError:
            target = None
        if not target or not (target / "walker.css").exists():
            console.print(
                Panel(
                    "Active theme lacks walker.css. Re-run `themectl sync-assets` and `themectl apply <theme>`.",
                    title="Walker runtime theme missing",
                    border_style="red",
                )
            )
            ok = False
    return ok


def _apply_theme(theme: Theme, cfg: ThemectlConfig) -> None:
    home = get_home()
    themes_root = home / ".config" / "omarchy" / "themes"
    theme_dir = themes_root / theme.slug
    if not theme_dir.exists():
        console.print(
            f"[yellow]Theme assets missing for {theme.display_name}. "
            "Run `themectl sync-assets` first.[/yellow]"
        )
        raise Exit(1)

    current_root = home / ".config" / "omarchy" / "current"
    current_root.mkdir(parents=True, exist_ok=True)
    _safe_symlink(theme_dir, current_root / "theme")

    if theme.wallpapers:
        background_dir = theme_dir / "backgrounds"
        local = background_dir / theme.wallpapers[0].name
        if local.exists():
            _safe_symlink(local, current_root / "background")

    _write_state(cfg, theme.slug)


def _cycle_theme(
    cfg: ThemectlConfig, repo: ThemeRepository, direction: str
) -> Theme | None:
    order = [slug.lower() for slug in cfg.order.cycle if repo.get(slug)]
    if not order:
        order = [theme.slug for theme in repo]
    if not order:
        return None
    current = (read_current_theme(cfg.state_path) or order[0]).lower()
    if current not in order:
        current = order[0]
    idx = order.index(current)
    if direction == "prev":
        idx = (idx - 1) % len(order)
    else:
        idx = (idx + 1) % len(order)
    return repo.get(order[idx])


def _platform_manifest_key(name: str) -> str:
    return "darwin" if name == "darwin" else "linux-hyprland"


def _manifest_bindings(
    manifest: Mapping[str, Any],
    platform_key: str,
    mode_override: str | None = None,
) -> tuple[str | None, Mapping[str, Any]]:
    platforms = manifest.get("platforms")
    if not isinstance(platforms, Mapping):
        raise KeyError(platform_key)
    target = platforms.get(platform_key)
    if not isinstance(target, Mapping):
        raise KeyError(platform_key)
    if platform_key == "darwin":
        modes = target.get("modes", {})
        if not isinstance(modes, Mapping):
            raise KeyError(platform_key)
        mode_name = mode_override or target.get("default_mode") or "bsp"
        mode = modes.get(mode_name)
        if not isinstance(mode, Mapping):
            raise KeyError(mode_name)
        bindings = mode.get("bindings", {})
        if not isinstance(bindings, Mapping):
            raise KeyError(mode_name)
        return mode_name, bindings
    bindings = target.get("bindings", {})
    if not isinstance(bindings, Mapping):
        raise KeyError(platform_key)
    return None, bindings


@app.callback()
def main() -> None:  # pragma: no cover - Typer callback for --version
    """themectl root command."""


@app.command()
def version() -> None:
    """Print themectl version."""

    console.print(f"themectl {__version__}")


@app.command()
def status(config: Optional[Path] = typer.Option(None, "--config", "-c")) -> None:
    """Show theme status."""

    cfg = _load(config)
    repo = _load_repo(cfg)
    current = read_current_theme(cfg.state_path)

    console.print(f"[bold]Platform:[/bold] {cfg.platform}")
    console.print(f"[bold]Theme metadata:[/bold] {cfg.metadata_path}")
    console.print(f"[bold]State file:[/bold] {cfg.state_path}")
    if current:
        console.print(f"[bold]Current theme:[/bold] {current}")

    if not repo.themes:
        console.print("[yellow]No theme metadata found[/yellow]")
        return

    table = Table(
        title="Available Themes",
        box=box.MINIMAL_DOUBLE_HEAD,
        show_lines=False,
        header_style="bold cyan",
    )
    table.add_column("Name")
    table.add_column("Editors")
    table.add_column("Wallpaper")

    for theme in repo:
        editors = ", ".join(
            filter(
                None,
                [
                    theme.nvim_colorscheme and "nvim",
                    theme.vscode_theme and "vscode",
                    theme.cursor_theme and "cursor",
                ],
            )
        )
        wallpaper = theme.wallpapers[0].name if theme.wallpapers else "—"
        identifiers = {theme.slug, theme.name.lower(), theme.display_name.lower()}
        name = theme.display_name
        if current and current.lower() in identifiers:
            name = f"[bold green]{theme.display_name}[/bold green]"
        table.add_row(name, editors or "—", wallpaper)

    console.print(table)


@app.command()
def apply(
    theme: str,
    config: Optional[Path] = typer.Option(None, "--config", "-c"),
) -> None:
    """Apply a theme and update runtime symlinks."""

    cfg = _load(config)
    repo = _load_repo(cfg)
    match = repo.get(theme)
    if not match:
        console.print(f"[red]Theme '{theme}' not found in {cfg.metadata_path}[/red]")
        raise Exit(1)
    _apply_theme(match, cfg)
    run_reload_hooks(match, cfg, console)
    console.print(
        Panel(
            f"[cyan]Applied[/cyan] {match.display_name} on {cfg.platform}",
            title="themectl",
            border_style="green",
        )
    )


@app.command()
def cycle(
    direction: str = typer.Option("next", "--direction", "-d", help="Cycle direction"),
    config: Optional[Path] = typer.Option(None, "--config", "-c"),
) -> None:
    """Cycle themes in configured order."""

    cfg = _load(config)
    repo = _load_repo(cfg)
    target = _cycle_theme(cfg, repo, direction)
    if not target:
        console.print("[yellow]No themes available to cycle[/yellow]")
        raise Exit(1)
    _apply_theme(target, cfg)
    run_reload_hooks(target, cfg, console)
    console.print(
        Panel(
            f"[cyan]Cycled[/cyan] to {target.display_name} ({direction})",
            title="themectl",
            border_style="green",
        )
    )


@app.command("cycle-background")
def cycle_background(
    direction: str = typer.Option("next", "--direction", "-d", help="Cycle direction"),
    config: Optional[Path] = typer.Option(None, "--config", "-c"),
) -> None:
    """Cycle through wallpapers from ALL themes."""

    cfg = _load(config)

    home = get_home()
    themes_dir = home / ".config" / "omarchy" / "themes"

    if not themes_dir.exists():
        console.print("[yellow]No themes directory found. Run `themectl sync-assets` first.[/yellow]")
        raise Exit(1)

    # Collect ALL wallpapers from ALL themes
    all_backgrounds: list[Path] = []
    for theme_dir in sorted(themes_dir.iterdir()):
        if not theme_dir.is_dir():
            continue
        backgrounds_dir = theme_dir / "backgrounds"
        if not backgrounds_dir.exists():
            continue
        for bg in sorted(backgrounds_dir.iterdir()):
            if bg.is_file() and bg.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp"):
                all_backgrounds.append(bg)

    if not all_backgrounds:
        console.print("[yellow]No wallpapers found in any theme[/yellow]")
        raise Exit(1)

    if len(all_backgrounds) == 1:
        console.print("[cyan]Only one wallpaper available across all themes[/cyan]")
        return

    # Read current background path
    background_state = cfg.state_path.parent / ".current-background-path"
    current_path_str = read_current_background_path(background_state)

    # Find current index in the global list
    current_idx = 0
    if current_path_str:
        current_path = Path(current_path_str)
        for i, bg in enumerate(all_backgrounds):
            if bg == current_path or bg.resolve() == current_path.resolve():
                current_idx = i
                break

    # Calculate next index
    if direction == "prev":
        new_idx = (current_idx - 1) % len(all_backgrounds)
    else:
        new_idx = (current_idx + 1) % len(all_backgrounds)

    # Update symlink to new background
    new_background = all_backgrounds[new_idx]
    current_root = home / ".config" / "omarchy" / "current"
    _safe_symlink(new_background, current_root / "background")

    # Save new background path
    write_background_path(background_state, str(new_background))

    # Update wallpaper
    update_wallpaper(console)

    # Extract theme name from path for display
    theme_name = new_background.parent.parent.name

    console.print(
        Panel(
            f"[cyan]Cycled[/cyan] to wallpaper {new_idx + 1}/{len(all_backgrounds)} ({theme_name}/{new_background.name})",
            title="themectl",
            border_style="green",
        )
    )


@app.command("sync-assets")
def sync_assets_cmd(
    config: Optional[Path] = typer.Option(None, "--config", "-c"),
) -> None:
    """Synchronize Omarchy assets locally."""

    cfg = _load(config)
    repo = _load_repo(cfg)
    if not repo.themes:
        console.print("[yellow]No themes found; cannot sync assets[/yellow]")
        raise Exit(1)
    sync_assets(repo, console)
    console.print(
        Panel(
            "Assets synchronized under ~/.config/omarchy/themes",
            title="themectl",
            border_style="green",
        )
    )


@app.command("macos-mode")
def macos_mode(
    mode: str = typer.Argument(..., help="bsp or native"),
    config: Optional[Path] = typer.Option(None, "--config", "-c"),
) -> None:
    """Toggle macOS BSP/native mode."""

    cfg = _load(config)
    if cfg.platform != "darwin":
        console.print("[red]macos-mode is only available on macOS[/red]")
        raise Exit(1)
    controller = MacOSModeController(console=console)
    try:
        controller.switch(mode)
    except ValueError as exc:
        console.print(f"[red]{exc}[/red]")
        raise Exit(1)


@app.command()
def doctor(
    config: Optional[Path] = typer.Option(None, "--config", "-c"),
) -> None:
    """Run health checks."""

    cfg = _load(config)
    repo = _load_repo(cfg)
    ok = True
    if not cfg.metadata_path.exists():
        console.print(f"[red]Metadata file missing: {cfg.metadata_path}[/red]")
        ok = False
    if not repo.themes:
        console.print(
            "[red]No themes available; run sync-assets after fixing metadata[/red]"
        )
        ok = False
    if cfg.platform == "darwin":
        ok = ensure_yabai_sa(console) and ok
        ok = ensure_tcc_permissions(console) and ok
    if cfg.platform == "linux":
        ok = _walker_assets_ok(cfg, console) and ok
    if ok:
        console.print(
            Panel("All checks passed", title="themectl", border_style="green")
        )
    else:
        raise Exit(1)


@app.command()
def hotkeys(
    config: Optional[Path] = typer.Option(None, "--config", "-c"),
    platform: Optional[str] = typer.Option(
        None,
        "--platform",
        "-p",
        help="Override platform key (darwin or linux-hyprland) when listing hotkeys.",
    ),
) -> None:
    """Show hotkey bindings from the manifest."""

    cfg = _load(config)
    manifest = load_manifest(cfg.hotkeys_path)
    target = platform or _platform_manifest_key(cfg.platform)
    try:
        mode, bindings = _manifest_bindings(manifest, target)
    except KeyError:
        console.print(f"[red]No hotkey bindings defined for {target}[/red]")
        raise Exit(1)

    rows = flatten_bindings(bindings)
    if not rows:
        console.print(f"[yellow]No bindings declared for {target}[/yellow]")
        raise Exit(1)

    subtitle = f"{target}{f'/{mode}' if mode else ''}"
    table = Table(
        title=f"Hotkeys ({subtitle})",
        box=box.MINIMAL_DOUBLE_HEAD,
        header_style="bold cyan",
    )
    table.add_column("Action")
    table.add_column("Chord")
    for action, chord in rows:
        table.add_row(action, chord)
    console.print(table)
