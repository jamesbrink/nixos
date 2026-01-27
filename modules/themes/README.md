# Theme System

Universal theme module for NixOS and Darwin systems. Provides centralized theme definitions and assets that work consistently across all platforms.

## Overview

This module provides:

- **Theme definitions** - Nix attribute sets defining colors, wallpapers, and app-specific config
- **Synced assets** - Colors, wallpapers, and app themes synced from [Omarchy](https://github.com/omarchy/omarchy)
- **Cross-platform support** - Works identically on Linux (Hyprland) and Darwin (macOS)
- **Theme library** - Helper functions for theme resolution and metadata export

## Directory Structure

```
modules/themes/
├── README.md                   # This file
├── default.nix                 # Main NixOS/Darwin module
├── lib.nix                     # Theme library functions
├── sync-from-omarchy.py        # Asset sync script (Python)
├── sync-from-omarchy.sh        # Asset sync script (Bash, deprecated)
├── definitions/                # Theme definitions (Nix)
│   ├── tokyo-night.nix
│   ├── catppuccin.nix
│   ├── gruvbox.nix
│   └── ... (12 total themes)
├── colors/                     # Color palettes (synced from Omarchy)
│   ├── tokyo-night.toml
│   ├── catppuccin.toml
│   └── ... (14 total)
├── wallpapers/                 # Wallpapers (synced from Omarchy)
│   ├── tokyo-night/
│   ├── catppuccin/
│   └── ... (14 total themes)
└── assets/                     # App-specific assets (synced from Omarchy)
    ├── neovim/                 # Neovim lazy.nvim specs
    ├── vscode/                 # VS Code theme metadata
    ├── btop/                   # btop theme files
    └── icons/                  # Icon theme references
```

## Syncing Assets from Omarchy

The Omarchy submodule (`external/omarchy/`) serves as the upstream source for theme assets. To sync:

```bash
# From repository root
./modules/themes/sync-from-omarchy.py

# Dry run (preview changes)
./modules/themes/sync-from-omarchy.py --dry-run

# Force overwrite local modifications
./modules/themes/sync-from-omarchy.py --force

# Verbose output
./modules/themes/sync-from-omarchy.py --verbose
```

The sync script:

- Copies `colors.toml` from each theme → `colors/{theme}.toml`
- Copies `neovim.lua` → `assets/neovim/{theme}.lua`
- Copies `vscode.json` → `assets/vscode/{theme}.json`
- Copies `btop.theme` → `assets/btop/{theme}.theme`
- Copies `icons.theme` → `assets/icons/{theme}.theme`
- Copies all `backgrounds/*.{png,jpg,jpeg}` → `wallpapers/{theme}/`

## Adding a New Theme

### 1. Add Theme to Omarchy (upstream)

If contributing to [Omarchy](https://github.com/omarchy/omarchy):

```bash
# In external/omarchy/themes/
mkdir my-theme
cd my-theme

# Create required files:
# - colors.toml       (color palette)
# - neovim.lua        (Neovim colorscheme)
# - vscode.json       (VS Code theme reference)
# - btop.theme        (btop colors)
# - icons.theme       (icon theme name)
# - backgrounds/      (wallpapers)
```

### 2. Sync Assets

```bash
cd /path/to/nixos
git submodule update --remote external/omarchy  # Pull latest Omarchy
./modules/themes/sync-from-omarchy.py           # Sync assets
```

### 3. Create Theme Definition

```bash
# modules/themes/definitions/my-theme.nix
{
  name = "my-theme";
  displayName = "My Theme";
  kind = "dark";  # or "light"

  wallpapers = [
    "1-wallpaper.png"
    "2-wallpaper.jpg"
  ];

  alacritty = {
    primary = {
      background = "#1a1b26";
      foreground = "#c0caf5";
    };
    normal = {
      black = "#15161e";
      red = "#f7768e";
      # ... (8 colors)
    };
    bright = {
      black = "#414868";
      red = "#f7768e";
      # ... (8 colors)
    };
  };

  ghostty = {
    # Option 1: Use built-in theme
    theme = "tokyo-night";

    # Option 2: Custom palette
    background = "1a1b26";
    foreground = "c0caf5";
    palette = [
      "0=15161e"
      "1=f7768e"
      # ... (16 colors)
    ];
  };

  vscode.id = "my-theme-vscode";  # VS Code extension ID
  nvim.name = "my-theme";         # Neovim colorscheme name

  hyprland = {
    activeBorder = "rgba(7aa2f7ff)";
    inactiveBorder = "rgba(414868ff)";
  };

  tmux = {
    statusBg = "#1a1b26";
    statusFg = "#c0caf5";
  };

  browser.themeColor = "26,27,38";  # RGB for browser theme (omnibox)
}
```

### 4. Register Theme in lib.nix

```nix
# modules/themes/lib.nix
themeFiles = [
  # ... existing themes
  ./definitions/my-theme.nix
];
```

### 5. Test

```bash
nix build .#darwinConfigurations.halcyon.system --no-link  # Darwin
nix build .#nixosConfigurations.hal9000.config.system.build.toplevel --no-link  # NixOS
```

## Using Themes

### In Nix Modules

```nix
# Import theme library
let
  themeLib = import ../../modules/themes/lib.nix { };
in {
  # Access theme metadata
  programs.myapp.theme = themeLib.themeMetadata;

  # Get wallpaper path
  home.file.".background".source =
    themeLib.getWallpaperSource "tokyo-night" "1-wallpaper.png";
}
```

### In Home Manager (Darwin/Linux)

```nix
# users/jamesbrink-darwin.nix
{
  imports = [
    ../../modules/home-manager/darwin/unified-themes.nix
  ];

  # Theme is automatically applied to:
  # - Alacritty
  # - Ghostty
  # - VS Code
  # - macOS desktop wallpaper
}
```

### With themectl CLI

```bash
themectl status                    # Show current theme
themectl apply tokyo-night         # Apply theme
themectl cycle --direction next    # Cycle to next theme
themectl cycle --direction prev    # Cycle to previous theme
themectl sync-assets               # Sync theme assets
```

## Theme Library Functions

### `buildMetadata(theme)`

Enrich a theme definition with computed fields (slug, resolved wallpaper paths, colors).

### `getWallpaperSource(themeName, fileName)`

Resolve wallpaper path (from `modules/themes/wallpapers/{theme}/{file}`).

### `parseColorsToml(slug)`

Load and parse `colors/{slug}.toml` into Nix attrset.

### `themeMetadataJSON`

Export all theme metadata as JSON (used by themectl CLI).

### `ghosttyConfigText(ghosttyDef)`

Generate Ghostty config text from theme definition.

### `ghosttyThemeMap`

Map theme names to Ghostty theme names (built-in or custom).

## Module Options

When you import `modules/themes` as a NixOS/Darwin module:

### `themes.available`

**Type:** `listOf str` (read-only)
**Description:** List of all available theme names.

### `themes.metadata`

**Type:** `unspecified` (read-only)
**Description:** Complete theme metadata for all themes (list of attrsets).

### `themes.metadataJSON`

**Type:** `str` (read-only)
**Description:** JSON-encoded theme metadata (for themectl).

### `themes.lib`

**Type:** `unspecified` (read-only)
**Description:** Theme library functions (same as `import ./lib.nix { }`).

## Integration Points

### themectl CLI

- Colors bundled at build time from `modules/themes/colors/`
- Reads metadata from `~/.config/themectl/themes.json` (generated by flake)
- Applies themes by writing app configs and reloading

### Darwin (unified-themes.nix)

- Imports `modules/themes/lib.nix`
- Generates Alacritty/Ghostty/VSCode configs
- Runs AppleScript to reload apps
- Uses `desktoppr` to set wallpaper

### Hyprland (hyprland.nix)

- Imports theme from `modules/themes/definitions/{theme}.nix`
- Applies colors to Hyprland borders
- Sets wallpaper via `swww`

## Maintenance

### Update Omarchy Submodule

```bash
git submodule update --remote external/omarchy
./modules/themes/sync-from-omarchy.py
git add modules/themes/
git commit -m "feat(themes): sync assets from Omarchy"
```

### Re-sync Single Theme

```bash
# Edit modules/themes/definitions/my-theme.nix or sync script
./modules/themes/sync-from-omarchy.py --force
```

### Local Wallpaper Overrides

Place wallpapers in `modules/themes/wallpapers/{theme}/` and they'll be preferred over synced ones.

## Architecture Decisions

### Why sync assets instead of referencing Omarchy directly?

- **Faster builds** - No need to evaluate Omarchy submodule on every build
- **Offline-friendly** - All assets committed to repo
- **Version control** - Track exactly which assets are used
- **Customization** - Easy to override individual assets locally

### Why both `.nix` definitions and `.toml` colors?

- **Nix definitions** - Type-safe, validated, rich metadata (wallpapers, nvim, vscode)
- **TOML colors** - Simple format, easily consumed by Python/Rust tools
- **Synced together** - Both maintained from single source (Omarchy)

### Why universal `modules/themes/` instead of `modules/darwin/themes/` + `modules/linux/themes/`?

- **Single source of truth** - All platforms use identical theme data
- **Easier maintenance** - Add theme once, works everywhere
- **Better testing** - Changes validated across all platforms

## Related Documentation

- [CLAUDE.md](../../CLAUDE.md) - Build commands and coding standards
- [HOTKEYS.md](../../HOTKEYS.md) - Theme cycling keybindings
- [themectl CLI](../../scripts/themectl/README.md) - Runtime theme automation
