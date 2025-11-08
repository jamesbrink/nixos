# Halcyon Working Log

This document tracks the current macOS/Hyprland parity effort. Check off items as they are completed and capture new cleanup work as it appears.

## Theme Automation Rewrite (Planned)

- [x] **Design Python CLI architecture** – sketch `scripts/themectl/` layout with subcommands (`apply`, `sync-assets`, `status`, `macos-space-mode`) and define how it imports Omarchy themes + Nix-provided metadata.
- [x] **Add Python dev tooling to flake** – include Ruff (lint/format), BasedPyright (fast Rust Pyright), and Markdownlint; wire them into `devShells` + `treefmt`.
- [x] **Scaffold themectl package** – create `pyproject.toml`, Typer entrypoint, config/theme loaders, and pytest harness as the baseline for future commands.
- [x] **Metadata/status MVP** – parse the generated theme JSON, track current theme state, and present Rich tables via `themectl status`.
- [x] **`apply` stub + sync placeholder** – resolve theme names through the repository, emit structured panels, and prep `sync-assets` for real copying.
- [x] **CLI integration points** – document how Hyprland, nix-darwin, and Hammerspoon call the tool (activation hooks vs. on-demand), including BSP/native toggle glue on macOS.
- [x] **Asset sync refactor** – replace `generate-themes.sh` / ad-hoc rsync with a Python `themectl sync-assets` command that mirrors Omarchy wallpapers, fonts, and templates idempotently.
- [x] **Testing strategy** – outline pytest-style unit tests for parsers + command routing, plus fixture-based tests for VSCode/Ghostty/Alacritty config rewrites without needing a live GUI.
- [x] **macOS SA watchdog** – ensure the CLI can detect when the yabai scripting addition drops (e.g., after reboot) and re-run `sudo yabai --load-sa`/`launchctl kickstart` as part of its macOS mode subcommand or a `themectl doctor`.

## Deployment Tooling Refresh (Planned)

- [ ] **Inventory devshell helpers** – review `flake.nix` commands (`deploy`, `deploy-test`, etc.) and `scripts/` Bash utilities to categorize what belongs in a shared Python CLI vs. one-off shell.
- [ ] **Design deployment CLI** – draft `scripts/opsctl/` (or similar) structure using Typer/Rich for subcommands like `deploy`, `deploy-all`, `health-check`, `secrets`, ensuring consistent logging, prompts, and dry-runs.
- [ ] **Rich output baseline** – add `rich` (and Typer if needed) to the dev shell plus any hosts that run the tool so we have colorized tables/spinners for deployments.
- [ ] **Migration plan** – specify which existing Bash scripts remain (e.g., installer stubs) and how the new Python CLI wraps or replaces them to avoid regressions.
- [ ] **On-host staging model** – ensure the deployment tool syncs rendered configs into `/etc/nixos` (Linux) / `/etc/nix-darwin` (macOS) before activation so `nixos-rebuild` or `darwin-rebuild` keep working without a repo checkout.
- [ ] **Testing & ergonomics** – outline pytest coverage for command parsing and remote execution mocks so agents can iterate locally without touching live hosts.

## Active / Upcoming

- [ ] **Walker launcher parity** – confirm the macOS launcher UX (fzf + Raycast fallback) matches the Linux walker configuration and document any gaps.
- [ ] **Finder appearance sync** – Finder still ignores light/dark flips triggered by `cycle-theme`; inspect defaults domains or add a launchagent shim.
- [ ] **Karabiner/AltTab configs** – both apps are installed but unconfigured; capture desired mappings (Hyper key, window previews) and produce managed config files.
- [ ] **Document theme sync workflow** – add README/docs notes on using `external/omarchy` + `generate-themes.sh` so future updates stay reproducible.
- [ ] **VSCode/Cursor live reload** – AppleScript automation still feels flaky; capture a more reliable trigger (or upstream issue) so theme switching is 100% hands-off.
- [ ] **Ghostty automation polish** – AppleScript reload + opacity tweaks work but still feel brittle; revisit after a cooldown (maybe watch for `ghostty +list-actions` updates or expose a direct CLI).

## Recently Completed

- [x] **macOS screenshots** – mapped Cmd+Shift+3/4/5 (and clipboard variants) to `macos-screenshot` so captures land in `~/Pictures/Screenshots` or the clipboard under versioned control.
- [x] **Alacritty font scaling** – added Cmd+Option+=/- bindings to grow/shrink text without touching the existing Cmd± tiling shortcuts.
- [x] **Alacritty workspace CWD** – new `alacritty-cwd-launch` helper reads the focused space's terminal cwd via Yabai/pgrep/lsof so cmd+Return/launcher hotkeys open in the same path.
- [x] **Omarchy submodule** – cloned the upstream repo into `external/omarchy` for canonical icons, wallpapers, and scripts.
- [x] **Shared theme registry** – new `modules/home-manager/hyprland/themes/lib.nix` exposes the theme list and a wallpaper lookup helper so Darwin + Hyprland modules stay in sync.
- [x] **Wallpaper cleanup** – removed duplicated images under `modules/home-manager/hyprland/wallpapers` and now reference the Omarchy assets (with optional local overrides).
- [x] **Runtime theme tooling** – refreshed `generate-themes.sh` to derive paths from the repo root, ensure the submodule exists, and link backgrounds from `external/omarchy`.
- [x] **Neovim/Ghostty parity** – added `nvr`-powered live reloads plus Ghostty theme-name fixes/custom theme files (matte-black + osaka-jade), then wired `ghostty +reload-config` so macOS mirrors Hyprland immediately.

## Notes

- Keep this list tight and actionable; dump longer-form research in `docs/` if needed.
- When you finish a task, move it to **Recently Completed** with a short note so we have an audit trail.
