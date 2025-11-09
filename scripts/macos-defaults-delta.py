#!/usr/bin/env python3
"""Compare current macOS defaults against expected values.

Shows a delta of settings we care about (menu bar, dock, etc.) with clean Rich output.
Run with --all to see all settings from key domains.
"""

import argparse
import plistlib
import subprocess
from dataclasses import dataclass
from typing import Any

from rich.console import Console
from rich.table import Table


@dataclass
class Setting:
    """Represents a macOS default setting."""

    domain: str
    key: str
    expected: Any
    description: str
    current_host: bool = False


# Define settings we care about with their expected values
CURATED_SETTINGS = [
    # Menu Bar Settings
    Setting(
        "NSGlobalDomain",
        "_HIHideMenuBar",
        1,
        "Menu bar visible (INVERTED: 1=visible, 0=hide)",
    ),
    Setting(
        "NSGlobalDomain",
        "AppleMenuBarAutoHide",
        0,
        "Menu bar auto-hide (0=visible, 1=hide)",
    ),
    Setting(
        "com.apple.Dock",
        "autohide-menu-bar",
        0,
        "Dock menu bar auto-hide (0=visible, 1=hide)",
    ),
    Setting(
        "com.apple.controlcenter",
        "AutoHideMenuBarOption",
        3,
        "Menu bar mode (0=Always, 1=Desktop, 2=Fullscreen, 3=Never)",
    ),
    # Per-host menu bar settings (should be "not set" to allow global to apply)
    Setting(
        "NSGlobalDomain",
        "_HIHideMenuBar",
        None,
        "Menu bar visible [per-host should be unset]",
        current_host=True,
    ),
    Setting(
        "NSGlobalDomain",
        "AppleMenuBarAutoHide",
        None,
        "Menu bar auto-hide [per-host should be unset]",
        current_host=True,
    ),
    # Dock Settings
    Setting("com.apple.dock", "autohide", None, "Dock auto-hide (managed by themectl)"),
    Setting("com.apple.dock", "autohide-delay", None, "Dock auto-hide delay"),
    Setting(
        "com.apple.dock",
        "autohide-time-modifier",
        None,
        "Dock auto-hide animation time",
    ),
]

# Domains to scan when showing all settings
DOMAINS_TO_SCAN = [
    "NSGlobalDomain",
    "com.apple.dock",
    "com.apple.Dock",
    "com.apple.controlcenter",
    "com.apple.finder",
    "com.apple.menuextra.clock",
    "com.apple.spaces",
    "com.apple.WindowManager",
]

# User Template paths to check for factory defaults
USER_TEMPLATE_PATHS = [
    "/System/Library/User Template/English.lproj/Library/Preferences",
    "/System/Library/User Template/Non_localized/Library/Preferences",
]

# Cache for factory defaults read from User Template
_factory_defaults_cache: dict[tuple[str, str], Any] = {}


def get_factory_default(domain: str, key: str) -> Any:
    """Get factory default value from User Template.

    Args:
        domain: The preference domain
        key: The preference key

    Returns:
        The factory default value, or None if not set
    """
    cache_key = (domain, key)
    if cache_key in _factory_defaults_cache:
        return _factory_defaults_cache[cache_key]

    # Map domain to plist filename
    if domain == "NSGlobalDomain":
        plist_name = ".GlobalPreferences.plist"
    else:
        plist_name = f"{domain}.plist"

    # Try reading from User Template paths
    for template_path in USER_TEMPLATE_PATHS:
        plist_file = f"{template_path}/{plist_name}"
        try:
            with open(plist_file, "rb") as f:
                data = plistlib.load(f)
                value = data.get(key)
                _factory_defaults_cache[cache_key] = value
                return value
        except (FileNotFoundError, PermissionError, plistlib.InvalidFileException):
            continue

    # Not found in any template - factory default is "not set"
    _factory_defaults_cache[cache_key] = None
    return None


def get_default_value(domain: str, key: str, current_host: bool = False) -> Any:
    """Get a macOS default value using the defaults command.

    Args:
        domain: The preference domain (e.g., 'NSGlobalDomain', 'com.apple.dock')
        key: The preference key
        current_host: Whether to use -currentHost flag

    Returns:
        The value, or None if not set
    """
    cmd = ["defaults"]
    if current_host:
        cmd.append("-currentHost")
    cmd.extend(["read", domain, key])

    try:
        result = subprocess.run(
            cmd, capture_output=True, text=True, check=True, timeout=5
        )
        value = result.stdout.strip()

        # Try to convert to int if possible
        try:
            return int(value)
        except ValueError:
            # Try to convert boolean strings
            if value.lower() in ("true", "yes", "1"):
                return 1
            if value.lower() in ("false", "no", "0"):
                return 0
            return value

    except subprocess.CalledProcessError:
        return None
    except subprocess.TimeoutExpired:
        return None


def format_value(value: Any) -> str:
    """Format a value for display."""
    if value is None:
        return "not set"
    if isinstance(value, bool):
        return str(int(value))
    return str(value)


def get_status_color(current: Any, expected: Any) -> str:
    """Get color for status based on whether values match.

    Args:
        current: Current value
        expected: Expected value (None means we don't care)

    Returns:
        Rich color name
    """
    if expected is None:
        return "dim"
    if current == expected:
        return "green"
    return "red"


def get_all_domain_settings(domain: str) -> dict[str, Any]:
    """Get all settings for a domain.

    Args:
        domain: The preference domain

    Returns:
        Dictionary of key-value pairs
    """
    try:
        # Use 'export' to get XML plist format which is parseable
        result = subprocess.run(
            ["defaults", "export", domain, "-"],
            capture_output=True,
            check=True,
            timeout=10,
        )
        # Parse plist output
        return plistlib.loads(result.stdout)
    except (
        subprocess.CalledProcessError,
        subprocess.TimeoutExpired,
        plistlib.InvalidFileException,
    ):
        return {}


def show_curated_settings(console: Console) -> None:
    """Show curated settings with current, global, factory, and nix expected values."""
    table = Table(
        title="macOS Defaults Delta (Curated)", show_header=True, header_style="bold"
    )
    table.add_column("Domain", style="cyan", width=22)
    table.add_column("Key", style="blue", width=25)
    table.add_column("Current", justify="center", width=10)
    table.add_column("Global", justify="center", width=10)
    table.add_column("Factory", justify="center", width=10)
    table.add_column("Nix Expected", justify="center", width=10)
    table.add_column("Description", width=35)

    mismatches = 0
    for setting in CURATED_SETTINGS:
        current = get_default_value(setting.domain, setting.key, setting.current_host)
        global_val = get_default_value(setting.domain, setting.key, False)
        factory = get_factory_default(setting.domain, setting.key)

        current_str = format_value(current)
        global_str = format_value(global_val)
        factory_str = format_value(factory)
        expected_str = format_value(setting.expected)

        # Color current based on whether it matches our expected Nix value
        if setting.expected is None:
            current_color = "dim"
        elif current == setting.expected:
            current_color = "green"
        else:
            current_color = "red"
            mismatches += 1

        table.add_row(
            setting.domain,
            setting.key,
            f"[{current_color}]{current_str}[/]",
            f"[dim]{global_str}[/]",
            f"[dim]{factory_str}[/]",
            f"[dim]{expected_str}[/]",
            f"[dim]{setting.description}[/]",
        )

    console.print(table)

    if mismatches > 0:
        console.print(f"\n[yellow]Found {mismatches} mismatched setting(s)[/yellow]")
    else:
        console.print("\n[green]All settings match expected values ✓[/green]")


def show_all_settings(console: Console) -> None:
    """Show all settings from key domains with delta information."""
    # Build a lookup of expected values from curated settings
    expected_map: dict[tuple[str, str, bool], tuple[Any, str]] = {}
    for setting in CURATED_SETTINGS:
        key = (setting.domain, setting.key, setting.current_host)
        expected_map[key] = (setting.expected, setting.description)

    for domain in DOMAINS_TO_SCAN:
        settings = get_all_domain_settings(domain)
        if not settings:
            continue

        table = Table(title=f"{domain}", show_header=True, header_style="bold cyan")
        table.add_column("Key", style="blue", width=25)
        table.add_column("Current", justify="center", width=10)
        table.add_column("Global", justify="center", width=10)
        table.add_column("Factory", justify="center", width=10)
        table.add_column("Nix Expected", justify="center", width=10)
        table.add_column("Description", width=35)

        for key, value in sorted(settings.items()):
            # Check if we have expected value and factory default
            lookup_key = (domain, key, False)
            expected_info = expected_map.get(lookup_key)
            factory = get_factory_default(domain, key)
            global_val = get_default_value(domain, key, False)

            # Format current value
            if isinstance(value, (dict, list)):
                current_str = (
                    str(value)[:7] + "..." if len(str(value)) > 10 else str(value)
                )
            elif isinstance(value, bytes):
                current_str = "binary"
            else:
                current_str = format_value(value)

            global_str = format_value(global_val)
            factory_str = format_value(factory)

            if expected_info:
                expected_val, description = expected_info
                expected_str = format_value(expected_val)

                # Color current based on whether it matches Nix expected
                if expected_val is None:
                    current_color = "dim"
                elif value == expected_val:
                    current_color = "green"
                else:
                    current_color = "red"

                table.add_row(
                    key,
                    f"[{current_color}]{current_str}[/]",
                    f"[dim]{global_str}[/]",
                    f"[dim]{factory_str}[/]",
                    f"[dim]{expected_str}[/]",
                    f"[dim]{description}[/]",
                )
            else:
                # No expected value - just show current, global, and factory
                table.add_row(
                    key,
                    f"[dim]{current_str}[/]",
                    f"[dim]{global_str}[/]",
                    f"[dim]{factory_str}[/]",
                    "[dim]-[/]",
                    "[dim]-[/]",
                )

        console.print(table)
        console.print()


def main() -> None:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Compare macOS defaults against expected values"
    )
    parser.add_argument(
        "--all",
        action="store_true",
        help="Show all settings from key domains instead of curated list",
    )
    args = parser.parse_args()

    console = Console()

    if args.all:
        show_all_settings(console)
    else:
        show_curated_settings(console)


if __name__ == "__main__":
    main()
