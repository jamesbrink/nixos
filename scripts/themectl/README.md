# themectl

`themectl` is the cross-platform theme automation CLI that replaces the older Bash tooling (`cycle-theme`, `generate-themes.sh`, Omarchy rsync helpers). It consumes a JSON export of our Hyprland theme definitions, generates the per-app assets under `~/.config/omarchy/themes`, and wires into Home Manager on both Linux and macOS.

## Integration

- **Metadata** – The flake now publishes `packages.<system>.themectl-theme-data`, a JSON document built from `modules/home-manager/hyprland/themes/lib.nix`. The `programs.themectl` Home Manager module installs it at `~/.config/themectl/themes.json`.
- **Config** – The same module provisions `~/.config/themectl/config.toml`, the mutable `.current-theme` file, and ensures the Python CLI is on `$PATH`. Override the location at runtime with `--config` if needed.
- **Assets** – `themectl sync-assets` renders Hyprland/Waybar/Alacritty/Kitty/Ghostty/Mako/SwayOSD/Hyprlock/VSCodium assets and mirrors wallpapers into `~/.config/omarchy/themes/<slug>/`. `themectl apply <theme>` updates `~/.config/omarchy/current/{theme,background}` symlinks and the `.current-theme` tracker.
- **Runtime automation** – `themectl apply`/`cycle` now rewrite VSCode + Cursor settings, poke the AppleScript reloaders, refresh Neovim via `nvr`, rewrite `~/.tmux.conf.local`, drive `hyprctl reload`/`swww img ~/.config/omarchy/current/background` on Linux, and call `ghostty +reload-config` for instant visual parity.
- **macOS watchdog** – `themectl doctor` ensures the yabai scripting addition is loaded (`sudo yabai --load-sa`) so Cmd+number space switching stays reliable after reboots. `themectl macos-mode` controls BSP/native toggles (launchctl, Dock/Finder defaults, Ghostty chrome) and replaces the bespoke Hammerspoon glue.
- **Walker verification (Linux)** – The doctor run now checks that every synced theme ships a `walker.css` and that `~/.config/omarchy/current/theme` points at a valid runtime theme so Walker reflects changes without manual fixes.
- **Hotkey manifest** – `config/hotkeys.yaml` is converted to JSON for both Nix and themectl so SKHD/Hammerspoon/Hyprland share the same bindings, and `themectl hotkeys` can display them on demand.

Home Manager modules (`modules/home-manager/hyprland/default.nix` and `modules/home-manager/darwin/unified-themes.nix`) now drop the metadata file into `~/.config/themectl/` so the CLI works out of the box on every host.

## Commands

| Command                           | Purpose                                                                                     |
| --------------------------------- | ------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| `themectl status`                 | Show current platform, metadata path, and available themes (Rich table).                    |
| `themectl sync-assets`            | Generate per-theme configs and wallpapers under `~/.config/omarchy/themes`.                 |
| `themectl apply <theme>`          | Update the runtime symlinks **and** trigger VSCode/Cursor/Neovim/tmux/Ghostty reload hooks. |
| `themectl cycle [--direction next | prev]`                                                                                      | Iterate through the configured order (or all themes) with the same reload hooks as `apply`. |
| `themectl doctor`                 | Run sanity checks (metadata present, yabai SA on macOS, Walker assets on Linux).            |
| `themectl macos-mode <bsp         | macos                                                                                       | toggle>`                                                                                    | Control BSP/native mode by touching launchctl, Dock/Finder defaults, yabai SA, and Ghostty chrome. |
| `themectl hotkeys`                | Print the manifest-defined keybindings for the current (or overridden) platform/mode.       |

`THEMECTL_HOME` overrides the home directory used for config/state, which keeps the CLI test-friendly.

## Testing

Run the test suite (requires `nix develop` so Typer/Rich/Ruff/BasedPyright/Pytest are available):

```bash
nix develop .#default --command sh -c 'cd scripts/themectl && pytest'
```

The tests rely on temporary homes via `THEMECTL_HOME` and cover:

- CLI smoke tests (version/status/apply/cycle)
- Asset rendering (ensuring Hyprland/Alacritty/etc. files are generated)
- Apply flow (symlink + `.current-theme` updates)

Future work will add mocks for AppleScript/`nvr` so automation hooks can be validated without touching real apps.

## Roadmap

- Backfill integration tests for the Linux reload pipeline (`hyprctl`, `swww`) so regressions are caught without touching a live session.
- Harden the AppleScript automation (better failure reporting, retries when Accessibility permissions are missing).
- Fold the remaining Hyprland launcher helpers into pure `themectl` subcommands once CLI coverage is vetted.
