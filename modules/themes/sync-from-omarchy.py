#!/usr/bin/env python3
"""Sync theme assets from external/omarchy submodule to modules/themes/"""

import argparse
import hashlib
import shutil
import sys
from pathlib import Path
from typing import NamedTuple


class SyncStats(NamedTuple):
    """Statistics for sync operation"""

    copied: int = 0
    skipped: int = 0
    errors: int = 0


class Colors:
    """ANSI color codes"""

    RED = "\033[0;31m"
    GREEN = "\033[0;32m"
    YELLOW = "\033[1;33m"
    BLUE = "\033[0;34m"
    NC = "\033[0m"


def log_info(msg: str) -> None:
    print(f"{Colors.BLUE}[INFO]{Colors.NC} {msg}")


def log_success(msg: str) -> None:
    print(f"{Colors.GREEN}[SUCCESS]{Colors.NC} {msg}")


def log_warn(msg: str) -> None:
    print(f"{Colors.YELLOW}[WARN]{Colors.NC} {msg}")


def log_error(msg: str) -> None:
    print(f"{Colors.RED}[ERROR]{Colors.NC} {msg}")


def log_verbose(msg: str, verbose: bool) -> None:
    if verbose:
        print(f"[VERBOSE] {msg}")


def file_hash(path: Path) -> str:
    """Calculate MD5 hash of file"""
    md5 = hashlib.md5()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            md5.update(chunk)
    return md5.hexdigest()


def files_identical(src: Path, dest: Path) -> bool:
    """Check if two files are identical"""
    if not dest.exists():
        return False
    return file_hash(src) == file_hash(dest)


def sync_file(
    src: Path,
    dest: Path,
    theme_name: str,
    *,
    dry_run: bool,
    force: bool,
    verbose: bool,
    stats: SyncStats,
) -> SyncStats:
    """Sync a single file from src to dest"""
    if not src.exists():
        log_verbose(f"Skipping missing source: {src}", verbose)
        return stats

    # Create destination directory if needed
    if not dry_run:
        dest.parent.mkdir(parents=True, exist_ok=True)

    # Check if files are identical
    if dest.exists():
        if files_identical(src, dest):
            log_verbose(f"Unchanged: {dest.name} for {theme_name}", verbose)
            return stats._replace(skipped=stats.skipped + 1)

        if not force:
            log_warn(
                f"Modified locally: {dest.name} for {theme_name} (use --force to overwrite)"
            )
            return stats._replace(skipped=stats.skipped + 1)

        log_info(f"Overwriting: {dest.name} for {theme_name}")
    else:
        log_info(f"Copying: {dest.name} for {theme_name}")

    if dry_run:
        print(f"  Would copy: {src} -> {dest}")
    else:
        try:
            shutil.copy2(src, dest)
        except Exception as e:
            log_error(f"Failed to copy {src} -> {dest}: {e}")
            return stats._replace(errors=stats.errors + 1)

    return stats._replace(copied=stats.copied + 1)


def sync_wallpapers(
    src_dir: Path,
    dest_dir: Path,
    theme_name: str,
    *,
    dry_run: bool,
    force: bool,
    verbose: bool,
    stats: SyncStats,
) -> SyncStats:
    """Sync wallpapers directory"""
    if not src_dir.exists():
        log_verbose(f"No backgrounds directory for {theme_name}", verbose)
        return stats

    wallpapers = list(src_dir.glob("*.png")) + list(src_dir.glob("*.jpg")) + list(
        src_dir.glob("*.jpeg")
    )

    if not wallpapers:
        log_verbose(f"No wallpapers found for {theme_name}", verbose)
        return stats

    log_info(f"Syncing {len(wallpapers)} wallpapers for {theme_name}")

    if not dry_run:
        dest_dir.mkdir(parents=True, exist_ok=True)

    for wallpaper in wallpapers:
        stats = sync_file(
            wallpaper,
            dest_dir / wallpaper.name,
            theme_name,
            dry_run=dry_run,
            force=force,
            verbose=verbose,
            stats=stats,
        )

    return stats


def sync_theme(
    theme_dir: Path,
    themes_root: Path,
    *,
    dry_run: bool,
    force: bool,
    verbose: bool,
    stats: SyncStats,
) -> SyncStats:
    """Sync a single theme"""
    theme_name = theme_dir.name
    log_info(f"Processing theme: {theme_name}")

    # Sync individual asset files
    asset_files = [
        ("colors.toml", themes_root / "colors" / f"{theme_name}.toml"),
        ("neovim.lua", themes_root / "assets/neovim" / f"{theme_name}.lua"),
        ("vscode.json", themes_root / "assets/vscode" / f"{theme_name}.json"),
        ("btop.theme", themes_root / "assets/btop" / f"{theme_name}.theme"),
        ("icons.theme", themes_root / "assets/icons" / f"{theme_name}.theme"),
    ]

    for src_name, dest_path in asset_files:
        src_path = theme_dir / src_name
        stats = sync_file(
            src_path,
            dest_path,
            theme_name,
            dry_run=dry_run,
            force=force,
            verbose=verbose,
            stats=stats,
        )

    # Sync wallpapers
    stats = sync_wallpapers(
        theme_dir / "backgrounds",
        themes_root / "wallpapers" / theme_name,
        theme_name,
        dry_run=dry_run,
        force=force,
        verbose=verbose,
        stats=stats,
    )

    return stats


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Sync theme assets from external/omarchy submodule"
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="Preview changes without modifying files"
    )
    parser.add_argument(
        "--force", action="store_true", help="Overwrite local modifications"
    )
    parser.add_argument(
        "-v", "--verbose", action="store_true", help="Show detailed output"
    )
    args = parser.parse_args()

    # Determine paths
    script_dir = Path(__file__).parent.resolve()
    repo_root = script_dir.parent.parent
    omarchy_dir = repo_root / "external/omarchy"
    themes_root = script_dir

    # Check if omarchy submodule exists
    if not (omarchy_dir / "themes").exists():
        log_error(f"Omarchy submodule not found at {omarchy_dir}")
        log_info("Run: git submodule update --init --recursive")
        return 1

    # Count themes
    theme_dirs = [d for d in (omarchy_dir / "themes").iterdir() if d.is_dir()]
    log_info(f"Found {len(theme_dirs)} themes in omarchy submodule")

    if args.dry_run:
        log_warn("DRY RUN MODE - No files will be modified")

    log_info(f"Starting sync from {omarchy_dir / 'themes'}")
    print()

    # Sync all themes
    stats = SyncStats()
    for theme_dir in sorted(theme_dirs):
        stats = sync_theme(
            theme_dir,
            themes_root,
            dry_run=args.dry_run,
            force=args.force,
            verbose=args.verbose,
            stats=stats,
        )
        print()

    # Summary
    print()
    log_info("====== Sync Summary ======")
    log_success(f"Copied: {stats.copied} files")
    if stats.skipped > 0:
        log_warn(f"Skipped: {stats.skipped} files")
    if stats.errors > 0:
        log_error(f"Errors: {stats.errors}")
        return 1

    if args.dry_run:
        log_info("Dry run complete. Run without --dry-run to apply changes.")
    else:
        log_success("Sync complete!")

    return 0


if __name__ == "__main__":
    sys.exit(main())
