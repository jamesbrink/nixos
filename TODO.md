# Halcyon Working Log

This document tracks the current macOS/Hyprland parity effort. Check off items as they are completed and capture new cleanup work as it appears.

## Theme Automation Rewrite (In Progress)

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

- [ ] **Safeguard themectl symlink handling** – update `_safe_symlink` (and associated tests) so replacing `~/.config/omarchy/current/{theme,background}` removes directories safely instead of calling `unlink()` and blowing up on pre-existing folders; ensure `sync-assets` stops following symlinks before `shutil.rmtree`.
- [ ] **Deduplicate macOS theme hotkey** – remove the duplicate Cmd+Shift+T binding so only one daemon (preferably Hammerspoon invoking `themectl cycle`) handles theme changes; keep SKHD focused on tiling/window actions.
- [ ] **Walker launcher parity** – confirm the macOS launcher UX (fzf + Raycast fallback) matches the Linux walker configuration and document any gaps.
- [ ] **Backlog grooming check** – once the above land, revisit Finder sync, Ghostty/VSC reload reliability, and the deployment CLI refresh to keep the Theme Automation track moving without blockers.
- [ ] **Finder appearance sync** – Finder still ignores light/dark flips triggered by `themectl cycle`; inspect defaults domains or add a launchagent shim.
- [ ] **Karabiner/AltTab configs** – both apps are installed but unconfigured; capture desired mappings (Hyper key, window previews) and produce managed config files.
- [ ] **Document theme sync workflow** – add README/docs notes on using `external/omarchy` + `themectl sync-assets` so future updates stay reproducible.
- [ ] **VSCode/Cursor live reload** – AppleScript automation still feels flaky; capture a more reliable trigger (or upstream issue) so theme switching is 100% hands-off.
- [ ] **Ghostty automation polish** – AppleScript reload + opacity tweaks work but still feel brittle; revisit after a cooldown (maybe watch for `ghostty +list-actions` updates or expose a direct CLI).
- [ ] **Yabai focus behavior toggle** – surface the “focus-follows-update”/auto-jump option (whatever yabai flag controls the terminal stealing focus) in `config/hotkeys.yaml` + Nix so BSP mode can keep focus pinned when background windows update.
- [ ] **Hide dock in BSP mode** – when tiling on macOS the Dock should be fully disabled/hidden so yabai layout stays clean; add a toggle in the forthcoming themectl YAML and Darwin modules.
- [ ] **macOS wallpaper multi-space sync** – desktoppr/System Events still only touch the focused Space; investigate LaunchServices APIs or Dock defaults to keep every Space/monitor aligned.
- [ ] **VSCode/Cursor automation redesign** – current AppleScript typing is disruptive; keep automation disabled via the YAML overrides until a non-invasive trigger (CLI or extension API) exists.

## Recently Completed

- [x] **Hyprland reload hooks** – `themectl apply/cycle` now shell into `hyprctl reload` and `swww img ~/.config/omarchy/current/background` so Linux hosts pick up theme changes immediately without manual wallpaper refreshes.
- [x] **Alacritty live reload** – `themectl` issues `alacritty msg config reload` (or SIGUSR1 fallback) so existing terminals update colors in-place on Linux/macos hosts.
- [x] **macOS screenshots** – mapped Cmd+Shift+3/4/5 (and clipboard variants) to `macos-screenshot` so captures land in `~/Pictures/Screenshots` or the clipboard under versioned control.
- [x] **Walker asset verification** – `themectl doctor` now validates Linux walker.css assets and the runtime theme symlink so Walker picks up synced themes without manual fixes.
- [x] **Hotkey manifest exporters** – `config/hotkeys.yaml` feeds SKHD/Hammerspoon/Hyprland bindings plus the new `themectl hotkeys` command, so theme/picker chords stay in sync across platforms.
- [x] **Deduplicate macOS theme hotkey** – removed the redundant SKHD theme binding so only Hammerspoon invokes `themectl cycle`, preventing double theme flips.
- [x] **Walker workflow uses themectl** – Linux Walker picker now shells into `themectl apply` and the legacy `generate-themes.sh` / `theme-set.sh` helpers were removed so Omarchy assets stay managed by the Python CLI.
- [x] **BasedPyright hygiene** – added `[tool.pyright]` config (Python 3.11, CLI-only include) plus type fixes so `cd scripts/themectl && basedpyright` passes alongside pytest/ruff.
- [x] **Alacritty font scaling** – added Cmd+Option+=/- bindings to grow/shrink text without touching the existing Cmd± tiling shortcuts.
- [x] **Alacritty workspace CWD** – new `alacritty-cwd-launch` helper reads the focused space's terminal cwd via Yabai/pgrep/lsof so cmd+Return/launcher hotkeys open in the same path.
- [x] **Omarchy submodule** – cloned the upstream repo into `external/omarchy` for canonical icons, wallpapers, and scripts.
- [x] **Shared theme registry** – new `modules/home-manager/hyprland/themes/lib.nix` exposes the theme list and a wallpaper lookup helper so Darwin + Hyprland modules stay in sync.
- [x] **Wallpaper cleanup** – removed duplicated images under `modules/home-manager/hyprland/wallpapers` and now reference the Omarchy assets (with optional local overrides).
- [x] **Runtime theme tooling** – refreshed `generate-themes.sh` to derive paths from the repo root, ensure the submodule exists, and link backgrounds from `external/omarchy`.
- [x] **Neovim/Ghostty parity** – added `nvr`-powered live reloads plus Ghostty theme-name fixes/custom theme files (matte-black + osaka-jade), then wired `ghostty +reload-config` so macOS mirrors Hyprland immediately.
- [x] **macOS mode automation** – `themectl macos-mode` now flips BSP/native by driving launchctl, Dock/Finder defaults, yabai SA, and Ghostty chrome, with the Hammerspoon hotkey shelling out to the CLI.
- [x] **Editor/terminal reload hooks** – `themectl apply/cycle` rewrites VSCode/Cursor settings, runs the AppleScript reloaders, updates Neovim via `nvr`, rewrites `~/.tmux.conf.local`, and forces `ghostty +reload-config`.
- [x] **Package + module integration** – flake builds the Python CLI, `programs.themectl` installs it + config/state, and Darwin/Hyprland modules now depend on the packaged tool.

## Notes

- Keep this list tight and actionable; dump longer-form research in `docs/` if needed.
- When you finish a task, move it to **Recently Completed** with a short note so we have an audit trail.
- Verification commands: `cd scripts/themectl && ruff check .` / `cd scripts/themectl && basedpyright` (pyright still warns about missing `yaml` stubs until the dev shell ships them).
