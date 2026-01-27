---
name: themectl
description: Work with the themectl theme management system. Use this skill when modifying themes, adding new themes, updating theme colors, fixing theme-related issues, or testing theme changes. Provides quick development workflow without requiring full system deployment.
---

# Themectl Development Guide

Manage the cross-platform theme system for NixOS and Darwin.

## Quick Reference

| Task                    | Command                           |
| ----------------------- | --------------------------------- |
| Show current theme      | `themectl status`                 |
| Apply a theme           | `themectl apply <theme-name>`     |
| Cycle to next theme     | `themectl cycle --direction next` |
| Cycle wallpapers        | `themectl cycle-background`       |
| Run health checks       | `themectl doctor`                 |
| Show hotkeys            | `themectl hotkeys`                |
| Toggle macOS BSP/native | `themectl macos-mode --mode bsp`  |

## Development Workflow (No Deploy Required)

### Quick Testing Without Rebuild

For CLI changes, run themectl directly from source:

```bash
# Enter dev shell (has all dependencies)
nix develop --impure

# Run from source
cd scripts/themectl
python -m themectl status
python -m themectl apply tokyo-night

# Or use uv for faster iteration
uv run themectl status
```

### Testing After Theme Definition Changes

Theme definitions are in Nix, so changes require a rebuild:

```bash
# Fast local build (no deploy)
nix build .#darwinConfigurations.halcyon.system --impure

# Activate locally
sudo ./result/sw/bin/darwin-rebuild switch --flake .#halcyon

# Test the theme
themectl apply <theme-name>
```

### Running Tests

```bash
cd scripts/themectl
uv run pytest
uv run pytest -v tests/test_cli.py::test_specific_test
```

## Key File Locations

### Theme Definitions (Nix)

| Path                               | Purpose                                   |
| ---------------------------------- | ----------------------------------------- |
| `modules/themes/definitions/*.nix` | Individual theme color palettes           |
| `modules/themes/lib.nix`           | Theme library functions, metadata builder |
| `modules/themes/default.nix`       | Main theme module                         |

### Theme Definition Structure

Each theme in `modules/themes/definitions/<name>.nix` contains:

```nix
{
  name = "theme-name";
  displayName = "Theme Name";

  # Terminal colors
  alacritty = { primary = { background = "#..."; foreground = "#..."; }; ... };
  kitty = { background = "#..."; foreground = "#..."; color0 = "#..."; ... };
  ghostty = { theme = "..."; background = "#..."; palette = [ "0=#..." ... ]; };

  # Editor themes
  nvim = { colorscheme = "..."; };
  vscode = { theme = "..."; extension = "publisher.name"; };
  cursor = { theme = "..."; extension = "publisher.name"; };  # Optional

  # Desktop colors
  hyprland = { activeBorder = "..."; inactiveBorder = "..."; };
  waybar = { foreground = "#..."; background = "#..."; };
  walker = { ... };

  # Application colors
  tmux = { statusBackground = "#..."; ... };
  btop = { main_bg = "#..."; ... };
  mako = { ... };

  # Wallpapers (filenames in wallpapers/<theme>/)
  wallpapers = [ "0-file.jpg" "1-file.jpg" ];
}
```

### Themectl CLI (Python)

| Path                                  | Purpose                                        |
| ------------------------------------- | ---------------------------------------------- |
| `scripts/themectl/themectl/cli.py`    | Main CLI entry point, commands                 |
| `scripts/themectl/themectl/hooks.py`  | App reload logic (neovim, ghostty, tmux, etc.) |
| `scripts/themectl/themectl/themes.py` | Theme class, metadata parsing                  |
| `scripts/themectl/themectl/assets.py` | Asset generation (alacritty, starship configs) |
| `scripts/themectl/themectl/config.py` | Configuration loading                          |
| `scripts/themectl/tests/`             | Test suite                                     |

### Neovim Colorschemes

| Path                                            | Purpose                                 |
| ----------------------------------------------- | --------------------------------------- |
| `modules/home-manager/editor/neovim.nix`        | Neovim config, colorscheme plugins      |
| `modules/home-manager/editor/nvim-colors/*.lua` | Custom colorschemes (e.g., matte-black) |

### VSCode/Cursor Extensions

| Path                                                | Purpose                          |
| --------------------------------------------------- | -------------------------------- |
| `packages/vscode-extensions/default.nix`            | Custom-packaged theme extensions |
| `modules/home-manager/darwin/cursor-extensions.nix` | Extension installation module    |

### Wallpapers

| Path                                 | Purpose                                      |
| ------------------------------------ | -------------------------------------------- |
| `modules/themes/wallpapers/<theme>/` | Theme wallpapers                             |
| `external/omarchy/`                  | Upstream omarchy submodule (source for sync) |

### Runtime Files (User Home)

| Path                                   | Purpose                     |
| -------------------------------------- | --------------------------- |
| `~/.config/themes/.current`            | Current theme name          |
| `~/.config/themes/.current-background` | Current wallpaper index     |
| `~/.config/alacritty/alacritty.toml`   | Generated alacritty config  |
| `~/.config/ghostty/config`             | Generated ghostty config    |
| `~/.config/nvim/lua/plugins/theme.lua` | Mutable neovim theme config |

## Available Themes

Current themes (check `modules/themes/definitions/`):

- `tokyo-night` - Default, blue/purple
- `catppuccin` - Mocha variant, pastel
- `catppuccin-latte` - Light variant
- `gruvbox` - Warm retro
- `nord` - Arctic blue
- `rose-pine` - Muted rose
- `everforest` - Green forest
- `kanagawa` - Japanese wave
- `matte-black` - Minimal dark (custom nvim colorscheme)
- `osaka-jade` - Green/jade Tokyo Night variant
- `ristretto` - Monokai coffee
- `flexoki-light` - Warm light theme

## Adding a New Theme

1. **Create theme definition**:

   ```bash
   cp modules/themes/definitions/tokyo-night.nix modules/themes/definitions/my-theme.nix
   # Edit with your colors
   ```

2. **Add wallpapers** (optional):

   ```bash
   mkdir -p modules/themes/wallpapers/my-theme
   cp /path/to/wallpaper.jpg modules/themes/wallpapers/my-theme/0-wallpaper.jpg
   ```

3. **Add neovim colorscheme** (if custom):
   - Either use an existing plugin (add to `neovim.nix` colorschemes list)
   - Or create custom colorscheme in `nvim-colors/my-theme.lua`

4. **Add VSCode extension** (if not in marketplace):
   - Package in `packages/vscode-extensions/default.nix`
   - Add to `cursor-extensions.nix`

5. **Build and test**:
   ```bash
   nix build .#darwinConfigurations.halcyon.system --impure
   sudo ./result/sw/bin/darwin-rebuild switch --flake .#halcyon
   themectl apply my-theme
   ```

## Common Issues

### Theme not appearing in themectl status

- Ensure theme definition exports required fields (`name`, `displayName`)
- Check `nix build` for syntax errors

### Neovim colorscheme not loading

- Verify colorscheme plugin is in `neovim.nix` colorschemes list with `lazy = false`
- For custom colorschemes, ensure file is in `nvim-colors/` and added to git
- Check mapping in `themeToColorscheme` table

### VSCode/Cursor theme not applying

- Check if extension is available in marketplace
- For Cursor, may need to package locally (different marketplace)
- Verify `vscode.extension` and `cursor.extension` in theme definition

### Wallpaper not changing

- Ensure wallpaper files exist in `modules/themes/wallpapers/<theme>/`
- Check `wallpapers` array in theme definition matches filenames
- On Darwin, `desktoppr` must be installed
