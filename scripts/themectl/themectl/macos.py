"""macOS-specific helpers (BSP/native toggles, yabai automation)."""

from __future__ import annotations

import shutil
import subprocess
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Sequence

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


@dataclass(frozen=True)
class _TCCBinaryTarget:
    name: str
    services: tuple[str, ...]


_TCC_TARGETS: tuple[_TCCBinaryTarget, ...] = (
    _TCCBinaryTarget(
        name="yabai",
        services=(
            "kTCCServiceAccessibility",
            "kTCCServiceListenEvent",
            "kTCCServicePostEvent",
            "kTCCServiceScreenCapture",
        ),
    ),
    _TCCBinaryTarget(
        name="skhd",
        services=(
            "kTCCServiceAccessibility",
            "kTCCServiceListenEvent",
            "kTCCServicePostEvent",
        ),
    ),
)

_TCC_SERVICES = sorted(
    {service for target in _TCC_TARGETS for service in target.services}
)
_DENY_PATTERNS = ("yabai", "skhd")


def _candidate_binaries(name: str) -> list[Path]:
    """Collect likely binary paths (Nix + Homebrew) for TCC entries."""

    seen: list[Path] = []

    def add(path: str | Path | None) -> None:
        if not path:
            return
        candidate = Path(path)
        if not candidate.exists():
            return
        normalized = candidate.resolve()
        for entry in (candidate, normalized):
            if entry not in seen:
                seen.append(entry)

    add(shutil.which(name))
    add(Path("/run/current-system/sw/bin") / name)
    add(Path("/opt/homebrew/bin") / name)
    add(Path("/usr/local/bin") / name)
    cellar = Path("/opt/homebrew/Cellar") / name
    if cellar.exists():
        for version in sorted(cellar.iterdir(), reverse=True):
            add(version / "bin" / name)
    return seen


def _tcc_databases(home: Path) -> list[tuple[Path, bool]]:
    """Return (db, needs_sudo) tuples."""

    system_db = Path("/Library/Application Support/com.apple.TCC/TCC.db")
    user_db = home / "Library" / "Application Support" / "com.apple.TCC" / "TCC.db"
    dbs: list[tuple[Path, bool]] = []
    if system_db.exists():
        dbs.append((system_db, True))
    if user_db.exists():
        dbs.append((user_db, False))
    return dbs


def _escape_sql(value: str) -> str:
    return value.replace("'", "''")


def _tcc_statements(client: Path, services: Sequence[str], client_type: int) -> str:
    escaped = _escape_sql(str(client))
    body = []
    for service in services:
        body.append(
            f"""
DELETE FROM access
  WHERE service='{service}'
    AND client='{escaped}'
    AND client_type={client_type};
INSERT OR REPLACE INTO access (
  service, client, client_type,
  auth_value, auth_reason, auth_version,
  csreq, policy_id,
  indirect_object_identifier_type,
  indirect_object_identifier,
  indirect_object_code_identity,
  flags
) VALUES (
  '{service}', '{escaped}', {client_type},
  2, 4, 1,
  NULL, NULL,
  0,
  'UNUSED',
  NULL,
  0
);
""".strip()
        )
    return "\n".join(body)


def _deny_cleanup_sql() -> str:
    if not _TCC_SERVICES:
        return ""
    service_list = ", ".join(f"'{svc}'" for svc in _TCC_SERVICES)
    clauses = []
    for pattern in _DENY_PATTERNS:
        escaped = _escape_sql(pattern)
        clauses.append(
            f"DELETE FROM access WHERE auth_value = 0 AND service IN ({service_list}) AND client LIKE '%{escaped}%';"
        )
    return "\n".join(clauses)


def _apply_tcc_statements(
    db: Path, sql: str, needs_sudo: bool, console: Console | None
) -> bool:
    if not sql.strip():
        return True
    sqlite3 = shutil.which("sqlite3") or "/usr/bin/sqlite3"
    cmd = [sqlite3, str(db)]
    if needs_sudo:
        sudo = shutil.which("sudo") or "/usr/bin/sudo"
        cmd.insert(0, sudo)
    result = subprocess.run(
        cmd,
        input=sql,
        text=True,
        capture_output=True,
    )
    if result.returncode != 0:
        if console:
            console.print(
                Panel(
                    result.stderr.strip() or f"sqlite3 exited {result.returncode}",
                    title=f"TCC update failed ({db})",
                    border_style="red",
                )
            )
        return False
    return True


def _restart_tccd(console: Console | None = None) -> None:
    sudo = shutil.which("sudo") or "/usr/bin/sudo"
    commands = [
        [sudo, "killall", "-9", "tccd"],
        ["killall", "-9", "tccd"],
    ]
    for cmd in commands:
        subprocess.run(
            cmd,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    time.sleep(2)
    if console:
        console.print("[green]✓[/green] Reloaded TCC daemon")


def ensure_tcc_permissions(console: Console | None = None) -> bool:
    """Grant Accessibility/Listen/PostEvent permissions for yabai/skhd.

    Tries tccutil first (works on macOS 26.1+), falls back to direct DB manipulation.
    """

    # Try tccutil first (the reliable method for macOS 26.1+)
    tccutil = shutil.which("tccutil")
    if tccutil and Path(tccutil).exists():
        if console:
            console.print("[cyan]→[/cyan] Using tccutil for TCC permissions (macOS 26.1+ compatible)")
        return _ensure_tcc_with_tccutil(tccutil, console)

    # Fall back to direct database manipulation
    if console:
        console.print("[yellow]![/yellow] tccutil not found; falling back to direct TCC database manipulation")
    return _ensure_tcc_with_database(console)


def _ensure_tcc_with_tccutil(tccutil: str, console: Console | None = None) -> bool:
    """Use jacobsalmela/tccutil to grant accessibility permissions."""

    sudo = shutil.which("sudo") or "/usr/bin/sudo"
    success = True
    granted_any = False

    for target in _TCC_TARGETS:
        clients = _candidate_binaries(target.name)
        if not clients:
            if console:
                console.print(f"[yellow]![/yellow] No {target.name} binary found")
            continue

        # Grant to the primary binary (first in list, usually from `which`)
        primary = clients[0]
        try:
            result = subprocess.run(
                [sudo, tccutil, "-e", str(primary.resolve())],
                capture_output=True,
                text=True,
                timeout=10,
            )
            if result.returncode == 0:
                granted_any = True
                if console:
                    console.print(f"[green]✓[/green] Granted accessibility to {target.name} ({primary})")
            else:
                success = False
                if console:
                    error_msg = result.stderr.strip() or result.stdout.strip() or f"Exit code {result.returncode}"
                    console.print(
                        Panel(
                            f"Failed to grant permissions to {primary}\n{error_msg}",
                            title=f"tccutil failed for {target.name}",
                            border_style="red",
                        )
                    )
        except subprocess.TimeoutExpired:
            success = False
            if console:
                console.print(f"[red]✗[/red] tccutil timed out for {target.name}")
        except Exception as e:
            success = False
            if console:
                console.print(f"[red]✗[/red] Error granting to {target.name}: {e}")

    if not granted_any:
        if console:
            console.print(
                Panel(
                    "No yabai/skhd binaries discovered; run Homebrew or nix-darwin install first.",
                    title="Accessibility grants skipped",
                    border_style="yellow",
                )
            )
        return False

    if success and granted_any:
        _restart_tccd(console)

    return success


def _ensure_tcc_with_database(console: Console | None = None) -> bool:
    """Grant TCC permissions via direct database manipulation (legacy method)."""

    home = get_home()
    dbs = _tcc_databases(home)
    if not dbs:
        if console:
            console.print("[yellow]![/yellow] No TCC database found; skipping grants")
        return True

    touched_db = False
    success = True
    statements: list[str] = []
    cleanup_sql = _deny_cleanup_sql()
    for target in _TCC_TARGETS:
        clients = _candidate_binaries(target.name)
        if not clients:
            continue
        for client in clients:
            for client_type in (0, 1):
                statements.append(_tcc_statements(client, target.services, client_type))

    if not statements:
        if console:
            console.print(
                Panel(
                    "No yabai/skhd binaries discovered; run Homebrew or nix-darwin install first.",
                    title="Accessibility grants skipped",
                    border_style="yellow",
                )
            )
        return False

    for db, needs_sudo in dbs:
        segments = []
        if cleanup_sql:
            segments.append(cleanup_sql)
        stmt_block = "\n".join(stmt for stmt in statements if stmt and stmt.strip())
        if stmt_block:
            segments.append(stmt_block)
        sql = "\n".join(segments)
        if not sql:
            continue
        touched_db = True
        success = _apply_tcc_statements(db, sql, needs_sudo, console) and success

    if success and touched_db:
        _restart_tccd(console)
    return success


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
        ensure_tcc_permissions(self.console)
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
