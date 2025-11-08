# themectl

`themectl` is the cross-platform theme automation CLI that replaces the older Bash tooling (`cycle-theme`, `generate-themes.sh`, Omarchy rsync helpers). It consumes a JSON export of our Hyprland theme definitions, generates the per-app assets under `~/.config/omarchy/themes`, and wires into Home Manager on both Linux and macOS.

## Integration

- **Metadata** – The flake now publishes `packages.<system>.themectl-theme-data`, a JSON document built from `modules/home-manager/hyprland/themes/lib.nix`. Home Manager installs it at `~/.config/themectl/themes.json`, and `themectl` reads from there by default.
- **Config** – `~/.config/themectl/config.toml` (managed via Home Manager) sets the platform (`darwin` or `linux`), metadata path, state file, and optional cycle order. Override the location at runtime with `--config` if needed.
- **Assets** – `themectl sync-assets` renders Hyprland/Waybar/Alacritty/Kitty/Ghostty/Mako/SwayOSD/Hyprlock/VSCodium assets and mirrors wallpapers into `~/.config/omarchy/themes/<slug>/`. `themectl apply <theme>` updates `~/.config/omarchy/current/{theme,background}` symlinks and the `.current-theme` tracker.
- **macOS watchdog** – `themectl doctor` ensures the yabai scripting addition is loaded (`sudo yabai --load-sa`) so Cmd+number space switching stays reliable after reboots.

Home Manager modules (`modules/home-manager/hyprland/default.nix` and `modules/home-manager/darwin/unified-themes.nix`) now drop the metadata file into `~/.config/themectl/` so the CLI works out of the box on every host.

## Commands

| Command                           | Purpose                                                                            |
| --------------------------------- | ---------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| `themectl status`                 | Show current platform, metadata path, and available themes (Rich table).           |
| `themectl sync-assets`            | Generate per-theme configs and wallpapers under `~/.config/omarchy/themes`.        |
| `themectl apply <theme>`          | Point `~/.config/omarchy/current/{theme,background}` to the chosen theme.          |
| `themectl cycle [--direction next | prev]`                                                                             | Cycle through the configured order or the full theme list. |
| `themectl doctor`                 | Run sanity checks (metadata present, yabai SA loaded on macOS).                    |
| `themectl macos-mode`             | Placeholder for the future BSP/native toggle (still handled by Hammerspoon today). |

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

- Wire `macos-mode` into launchctl/Hammerspoon for full BSP/native control.
- Add Linux-side hooks (`hyprctl`, `swww`) plus Neovim/VSCode/Ghostty live reloads.
- Ship a `themectl` Python package (via `buildPythonApplication`) and a Home Manager module to expose the CLI consistently across hosts.
