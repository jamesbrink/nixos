# Halcyon Working Log

This document tracks the current macOS/Hyprland parity effort. Check off items as they are completed and capture new cleanup work as it appears.

## Active / Upcoming

- [ ] **Walker launcher parity** – confirm the macOS launcher UX (fzf + Raycast fallback) matches the Linux walker configuration and document any gaps.
- [ ] **Finder appearance sync** – Finder still ignores light/dark flips triggered by `cycle-theme`; inspect defaults domains or add a launchagent shim.
- [ ] **Karabiner/AltTab configs** – both apps are installed but unconfigured; capture desired mappings (Hyper key, window previews) and produce managed config files.
- [ ] **Document theme sync workflow** – add README/docs notes on using `external/omarchy` + `generate-themes.sh` so future updates stay reproducible.

## Recently Completed

- [x] **Omarchy submodule** – cloned the upstream repo into `external/omarchy` for canonical icons, wallpapers, and scripts.
- [x] **Shared theme registry** – new `modules/home-manager/hyprland/themes/lib.nix` exposes the theme list and a wallpaper lookup helper so Darwin + Hyprland modules stay in sync.
- [x] **Wallpaper cleanup** – removed duplicated images under `modules/home-manager/hyprland/wallpapers` and now reference the Omarchy assets (with optional local overrides).
- [x] **Runtime theme tooling** – refreshed `generate-themes.sh` to derive paths from the repo root, ensure the submodule exists, and link backgrounds from `external/omarchy`.
- [x] **VSCode/Cursor theme reload** – cycle script now rewrites settings, triggers AppleScript automation (with `THEME_DISABLE_EDITOR_AUTOMATION=1` escape hatch), and refocuses editors just long enough to apply the new palette.
- [x] **Neovim/Ghostty parity** – added `nvr`-powered live reloads plus Ghostty theme-name fixes/custom theme files (matte-black + osaka-jade), then wired `ghostty +reload-config` so macOS mirrors Hyprland immediately.

## Notes

- Keep this list tight and actionable; dump longer-form research in `docs/` if needed.
- When you finish a task, move it to **Recently Completed** with a short note so we have an audit trail.
