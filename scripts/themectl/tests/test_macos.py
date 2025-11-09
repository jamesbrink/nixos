from io import StringIO
from pathlib import Path

from rich.console import Console

from themectl.macos import MacOSModeController


def _controller(monkeypatch, home: Path) -> MacOSModeController:
    monkeypatch.setenv("THEMECTL_HOME", str(home))
    return MacOSModeController(console=Console(file=StringIO(), record=True), state_path=home / ".bsp-mode-state")


def test_update_alacritty_mode_toggles_decorations(tmp_path: Path, monkeypatch) -> None:
    home = tmp_path / "home"
    config_dir = home / ".config" / "alacritty"
    config_dir.mkdir(parents=True)
    config_file = config_dir / "alacritty.toml"
    config_file.write_text(
        """
[window]
decorations = "buttonless"
opacity = 0.97
"""
    )
    controller = _controller(monkeypatch, home)

    controller._update_alacritty_mode("macos")
    text = config_file.read_text()
    assert 'decorations = "full"' in text

    controller._update_alacritty_mode("bsp")
    text = config_file.read_text()
    assert 'decorations = "buttonless"' in text


def test_update_alacritty_mode_breaks_symlink(tmp_path: Path, monkeypatch) -> None:
    home = tmp_path / "home"
    config_dir = home / ".config" / "alacritty"
    config_dir.mkdir(parents=True)
    template = config_dir / "alacritty.base.toml"
    template.write_text('[window]\ndecorations = "buttonless"\n')
    config = config_dir / "alacritty.toml"
    config.symlink_to(template)
    controller = _controller(monkeypatch, home)

    controller._update_alacritty_mode("macos")

    assert config.is_symlink() is False
    assert 'decorations = "full"' in config.read_text()


def test_update_alacritty_mode_inserts_section_when_missing(tmp_path: Path, monkeypatch) -> None:
    home = tmp_path / "home"
    config_dir = home / ".config" / "alacritty"
    config_dir.mkdir(parents=True)
    config_file = config_dir / "alacritty.toml"
    config_file.write_text('[font]\nsize = 14\n')
    controller = _controller(monkeypatch, home)

    controller._update_alacritty_mode("macos")
    text = config_file.read_text()
    assert "[window]" in text
    assert 'decorations = "full"' in text
