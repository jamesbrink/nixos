#!/usr/bin/env bash
# Runtime theme switching (Omarchy-style)

THEMES_DIR="$HOME/.config/omarchy/themes"
CURRENT_THEME_DIR="$HOME/.config/omarchy/current/theme"

# Show help
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
  echo "Usage: theme-set <theme-name>"
  echo "       theme-set --list"
  echo ""
  echo "Switch themes instantly without rebuilding NixOS"
  exit 0
fi

# List available themes
if [[ "$1" == "--list" || "$1" == "-l" ]]; then
  echo "Available themes:"
  ls -1 "$THEMES_DIR" 2>/dev/null || echo "No themes found. Run 'generate-themes' first."
  exit 0
fi

# Check arguments
if [[ -z "$1" ]]; then
  echo "Usage: theme-set <theme-name>"
  echo "Run 'theme-set --list' to see available themes"
  exit 1
fi

THEME_NAME="$1"
THEME_PATH="$THEMES_DIR/$THEME_NAME"

# Check if theme exists
if [[ ! -d "$THEME_PATH" ]]; then
  echo "Error: Theme '$THEME_NAME' not found in $THEMES_DIR"
  echo ""
  echo "Available themes:"
  ls -1 "$THEMES_DIR" 2>/dev/null
  exit 1
fi

echo "Switching to theme: $THEME_NAME"

# Create current directory if it doesn't exist
mkdir -p "$(dirname "$CURRENT_THEME_DIR")"

# Update theme symlink
ln -nsf "$THEME_PATH" "$CURRENT_THEME_DIR"
echo "  ✓ Updated theme symlink"

# Reload Hyprland
if command -v hyprctl &>/dev/null; then
  hyprctl reload &>/dev/null
  echo "  ✓ Reloaded Hyprland"
fi

# Reload Waybar (full restart to reload CSS)
if pgrep waybar &>/dev/null; then
  systemctl --user restart waybar.service 2>/dev/null && echo "  ✓ Reloaded Waybar"
fi

# Reload Mako
if command -v makoctl &>/dev/null; then
  makoctl reload &>/dev/null
  echo "  ✓ Reloaded Mako notifications"
fi

# Reload SwayOSD
if pgrep -x swayosd-server &>/dev/null; then
  pkill -x swayosd-server
  swayosd-server &>/dev/null &
  echo "  ✓ Reloaded SwayOSD"
fi

# Reload Alacritty (touch main config to trigger mtime-based reload)
# Alacritty watches the main config file and reloads when mtime changes
if pgrep -x alacritty &>/dev/null; then
  # Touch the main config file (not the imported theme file)
  # This triggers Alacritty's config watcher for NEW terminal instances
  touch "$HOME/.config/alacritty/alacritty.toml" 2>/dev/null
  echo "  ✓ Signaled Alacritty reload (new terminals)"
fi

# Update VSCode theme
if [[ -f "$THEME_PATH/vscode.json" ]] && [[ -f "$HOME/.config/Code/User/settings.json" ]]; then
  new_theme=$(jq -r '.["workbench.colorTheme"]' "$THEME_PATH/vscode.json")
  if [[ -n "$new_theme" ]]; then
    # Update VSCode settings with new theme
    jq --arg theme "$new_theme" '.["workbench.colorTheme"] = $theme' "$HOME/.config/Code/User/settings.json" > "$HOME/.config/Code/User/settings.json.tmp"
    mv "$HOME/.config/Code/User/settings.json.tmp" "$HOME/.config/Code/User/settings.json"
    echo "  ✓ Updated VSCode theme"
  fi
fi

# Update Neovim theme
if [[ -f "$THEME_PATH/neovim.lua" ]] && [[ -f "$HOME/.config/nvim/lua/plugins/theme.lua" ]]; then
  new_nvim_theme=$(sed 's/return "\(.*\)"/\1/' < "$THEME_PATH/neovim.lua")
  if [[ -n "$new_nvim_theme" ]]; then
    # Update Neovim theme.lua with new colorscheme
    sed -i "s/colorscheme = \".*\"/colorscheme = \"$new_nvim_theme\"/" "$HOME/.config/nvim/lua/plugins/theme.lua"

    # Reload colorscheme in running Neovim instances
    # Find all nvim server sockets and send colorscheme command
    if command -v nvim &>/dev/null; then
      for socket in /run/user/"$(id -u)"/nvim.*.0; do
        if [[ -S "$socket" ]]; then
          nvim --server "$socket" --remote-send "<Cmd>colorscheme $new_nvim_theme<CR>" &>/dev/null || true
        fi
      done
    fi

    echo "  ✓ Updated Neovim theme"
  fi
fi

# Update browser theme (if Chrome/Brave is installed)
if [[ -f "$THEME_PATH/chromium.theme" ]]; then
  rgb_color=$(cut -d'#' -f1 < "$THEME_PATH/chromium.theme" | tr -d ' ')
  # Convert RGB to hex
  IFS=',' read -r r g b <<< "$rgb_color"
  hex_color=$(printf "#%02x%02x%02x" "$r" "$g" "$b")

  # Write managed policy for Chromium
  if command -v google-chrome-stable &>/dev/null; then
    sudo mkdir -p /etc/chromium/policies/managed 2>/dev/null
    echo "{\"BrowserThemeColor\":\"$hex_color\"}" | sudo tee /etc/chromium/policies/managed/color.json >/dev/null 2>&1
    echo "  ✓ Updated Chrome theme"
  fi
fi

# Change wallpaper (Omarchy-style background switching)
BACKGROUNDS_DIR="$THEME_PATH/backgrounds"
CURRENT_BACKGROUND_LINK="$HOME/.config/omarchy/current/background"

if [[ -d "$BACKGROUNDS_DIR" ]] && command -v swww &>/dev/null; then
  # Get first background from theme (follow symlinks with -L)
  FIRST_BACKGROUND=$(find -L "$BACKGROUNDS_DIR" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) | sort | head -1)

  if [[ -n "$FIRST_BACKGROUND" ]]; then
    # Update background symlink for rotate-background script
    ln -nsf "$FIRST_BACKGROUND" "$CURRENT_BACKGROUND_LINK"

    # Set wallpaper with swww
    swww img "$FIRST_BACKGROUND" --transition-type wipe --transition-duration 1 &>/dev/null
    echo "  ✓ Updated wallpaper"
  fi
elif [[ ! -d "$BACKGROUNDS_DIR" ]]; then
  # No backgrounds for this theme, set solid color
  if command -v swww &>/dev/null && [[ -f "$THEME_PATH/alacritty.toml" ]]; then
    # Extract background color from alacritty theme
    bg_color=$(grep "^background" "$THEME_PATH/alacritty.toml" | cut -d'"' -f2 || echo "#000000")
    swww clear "$bg_color" &>/dev/null
    echo "  ✓ Set solid background (no wallpapers for theme)"
  fi
fi

echo ""
echo "Theme switched to: $THEME_NAME"
echo "Note: Spawn new Alacritty terminals to see theme. VSCode/Neovim update automatically."
