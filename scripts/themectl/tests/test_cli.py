import json
import textwrap
from pathlib import Path

from typer.testing import CliRunner

from themectl import __version__
from themectl.cli import app

runner = CliRunner()


def _write_config(root: Path, metadata: Path, state: Path) -> Path:
    config_dir = root / ".config" / "themectl"
    config_dir.mkdir(parents=True, exist_ok=True)
    config_path = config_dir / "config.toml"
    config_path.write_text(
        textwrap.dedent(
            f"""
            platform = "darwin"
            theme_metadata = "{metadata}"
            state_file = "{state}"
            [order]
            cycle = ["tokyo-night"]
            """
        ).strip()
    )
    return config_path


def _setup_home(tmp_path: Path, monkeypatch) -> Path:
    home = tmp_path / "home"
    home.mkdir()
    monkeypatch.setenv("HOME", str(home))
    monkeypatch.setenv("THEMECTL_HOME", str(home))
    return home


def test_version_command(tmp_path: Path, monkeypatch) -> None:
    _setup_home(tmp_path, monkeypatch)
    result = runner.invoke(app, ["version"])
    assert result.exit_code == 0
    assert __version__ in result.output


def test_status_with_metadata(tmp_path: Path, monkeypatch) -> None:
    home = _setup_home(tmp_path, monkeypatch)
    metadata = home / "themes.json"
    metadata.write_text(
        json.dumps(
            {
                "themes": [
                    {
                        "name": "Tokyo Night",
                        "slug": "tokyo-night",
                        "nvim": {"colorscheme": "tokyonight"},
                        "vscode": {"theme": "Tokyo Night"},
                        "wallpaper": "/tmp/tokyo.png",
                    }
                ]
            }
        )
    )
    state = home / ".config" / "themes" / ".current-theme"
    state.parent.mkdir(parents=True, exist_ok=True)
    state.write_text("tokyo-night")
    cfg = _write_config(home, metadata, state)

    result = runner.invoke(app, ["status", "--config", str(cfg)])
    assert result.exit_code == 0
    assert "Tokyo Night" in result.output
    assert "Current theme" in result.output


def test_apply_missing_theme(tmp_path: Path, monkeypatch) -> None:
    home = _setup_home(tmp_path, monkeypatch)
    metadata = home / "themes.json"
    metadata.write_text(json.dumps({"themes": []}))
    state = home / ".config" / "themes" / ".current-theme"
    cfg = _write_config(home, metadata, state)

    result = runner.invoke(app, ["apply", "unknown", "--config", str(cfg)])
    assert result.exit_code == 1
    assert "not found" in result.output


def test_apply_known_theme(tmp_path: Path, monkeypatch) -> None:
    home = _setup_home(tmp_path, monkeypatch)
    metadata = home / "themes.json"
    metadata.write_text(
        json.dumps(
            {
                "themes": [
                    {
                        "name": "Rose Pine",
                        "slug": "rose-pine",
                        "nvim": {"colorscheme": "rose-pine"},
                        "alacritty": {
                            "primary": {"background": "#000000", "foreground": "#ffffff"},
                            "normal": {
                                "black": "#000000",
                                "red": "#ff0000",
                                "green": "#00ff00",
                                "yellow": "#ffff00",
                                "blue": "#0000ff",
                                "magenta": "#ff00ff",
                                "cyan": "#00ffff",
                                "white": "#ffffff",
                            },
                            "bright": {
                                "black": "#111111",
                                "red": "#ff4444",
                                "green": "#44ff44",
                                "yellow": "#ffff44",
                                "blue": "#4444ff",
                                "magenta": "#ff44ff",
                                "cyan": "#44ffff",
                                "white": "#ffffff",
                            },
                        },
                        "hyprland": {
                            "activeBorder": "rgba(fafafaee)",
                            "inactiveBorder": "rgba(121212ff)",
                        },
                        "waybar": {
                            "foreground": "#ffffff",
                            "background": "#000000",
                        },
                        "kitty": {
                            "foreground": "#ffffff",
                            "background": "#000000",
                            "selection_foreground": "#ffffff",
                            "selection_background": "#222222",
                            "cursor": "#ffffff",
                            "cursor_text_color": "#000000",
                            "active_border_color": "#ffffff",
                            "inactive_border_color": "#333333",
                            "active_tab_foreground": "#000000",
                            "active_tab_background": "#ffffff",
                            "inactive_tab_foreground": "#555555",
                            "inactive_tab_background": "#111111",
                            "color0": "#000000",
                            "color1": "#ff0000",
                            "color2": "#00ff00",
                            "color3": "#ffff00",
                            "color4": "#0000ff",
                            "color5": "#ff00ff",
                            "color6": "#00ffff",
                            "color7": "#ffffff",
                        },
                        "ghostty": {"theme": "tokyonight_night"},
                        "walker": {
                            "selectedText": "#ffffff",
                            "text": "#ffffff",
                            "base": "#000000",
                            "border": "#ffffff",
                        },
                        "mako": {
                            "textColor": "#ffffff",
                            "borderColor": "#ff0000",
                            "backgroundColor": "#000000",
                        },
                        "swayosd": {
                            "textColor": "#ffffff",
                            "borderColor": "#ffffff",
                            "backgroundColor": "#111111",
                        },
                        "hyprlock": {
                            "outerColor": "#ffffff",
                            "innerColor": "#000000",
                            "fontColor": "#ffffff",
                            "checkColor": "#ff0000",
                        },
                        "browser": {
                            "themeColor": "#ffffff",
                        },
                        "wallpapers": [],
                    }
                ]
            }
        )
    )
    state = home / ".config" / "themes" / ".current-theme"
    cfg = _write_config(home, metadata, state)

    monkeypatch.setattr("themectl.cli.run_reload_hooks", lambda *args, **kwargs: None)
    sync_result = runner.invoke(app, ["sync-assets", "--config", str(cfg)])
    assert sync_result.exit_code == 0

    result = runner.invoke(app, ["apply", "rose-pine", "--config", str(cfg)])
    assert result.exit_code == 0
    assert "Applied" in result.output
    current_link = home / ".config" / "omarchy" / "current" / "theme"
    assert current_link.is_symlink()


def test_sync_assets_generates_files(tmp_path: Path, monkeypatch) -> None:
    home = _setup_home(tmp_path, monkeypatch)
    wallpaper = tmp_path / "wall.png"
    wallpaper.write_text("png")
    metadata = home / "themes.json"
    metadata.write_text(
        json.dumps(
            {
                "themes": [
                    {
                        "name": "Test Theme",
                        "slug": "test-theme",
                        "nvim": {"colorscheme": "tokyonight"},
                        "alacritty": {
                            "primary": {"background": "#101010", "foreground": "#f0f0f0"},
                            "normal": {
                                "black": "#101010",
                                "red": "#ff0000",
                                "green": "#00ff00",
                                "yellow": "#ffff00",
                                "blue": "#0000ff",
                                "magenta": "#ff00ff",
                                "cyan": "#00ffff",
                                "white": "#f0f0f0",
                            },
                            "bright": {
                                "black": "#202020",
                                "red": "#ff5555",
                                "green": "#55ff55",
                                "yellow": "#ffff55",
                                "blue": "#5555ff",
                                "magenta": "#ff55ff",
                                "cyan": "#55ffff",
                                "white": "#ffffff",
                            },
                        },
                        "hyprland": {
                            "activeBorder": "rgba(ffffffff)",
                            "inactiveBorder": "rgba(121212ff)",
                        },
                        "waybar": {
                            "foreground": "#ffffff",
                            "background": "#000000",
                        },
                        "kitty": {
                            "foreground": "#ffffff",
                            "background": "#000000",
                            "selection_foreground": "#ffffff",
                            "selection_background": "#111111",
                            "cursor": "#ffffff",
                            "cursor_text_color": "#000000",
                            "active_border_color": "#ffffff",
                            "inactive_border_color": "#444444",
                            "active_tab_foreground": "#000000",
                            "active_tab_background": "#ffffff",
                            "inactive_tab_foreground": "#666666",
                            "inactive_tab_background": "#111111",
                            "color0": "#000000",
                            "color1": "#ff0000",
                            "color2": "#00ff00",
                            "color3": "#ffff00",
                            "color4": "#0000ff",
                            "color5": "#ff00ff",
                            "color6": "#00ffff",
                            "color7": "#ffffff",
                        },
                        "ghostty": {"theme": "tokyonight_night"},
                        "walker": {
                            "selectedText": "#ffffff",
                            "text": "#ffffff",
                            "base": "#000000",
                            "border": "#ffffff",
                        },
                        "mako": {
                            "textColor": "#ffffff",
                            "borderColor": "#ffffff",
                            "backgroundColor": "#000000",
                        },
                        "swayosd": {
                            "textColor": "#ffffff",
                            "borderColor": "#ffffff",
                            "backgroundColor": "#000000",
                        },
                        "hyprlock": {
                            "outerColor": "#ffffff",
                            "innerColor": "#000000",
                            "fontColor": "#ffffff",
                            "checkColor": "#ff0000",
                        },
                        "browser": {"themeColor": "#000000"},
                        "wallpapers": [str(wallpaper)],
                    }
                ]
            }
        )
    )
    state = home / ".config" / "themes" / ".current-theme"
    cfg = _write_config(home, metadata, state)

    result = runner.invoke(app, ["sync-assets", "--config", str(cfg)])
    assert result.exit_code == 0

    theme_dir = home / ".config" / "omarchy" / "themes" / "test-theme"
    assert (theme_dir / "hyprland.conf").exists()
    assert (theme_dir / "alacritty.toml").exists()
    assert (theme_dir / "kitty.conf").exists()
    assert (theme_dir / "ghostty.conf").exists()
    assert (theme_dir / "backgrounds" / wallpaper.name).exists()
