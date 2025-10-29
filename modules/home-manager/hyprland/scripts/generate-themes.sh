#!/usr/bin/env bash
# Generate Omarchy-style theme files from NixOS theme definitions

set -e

THEMES_SOURCE="/home/jamesbrink/Projects/jamesbrink/nixos/modules/home-manager/hyprland/themes"
THEMES_DEST="$HOME/.config/omarchy/themes"

# Create themes directory
mkdir -p "$THEMES_DEST"

# Function to extract value from Nix file
extract_value() {
  local file="$1"
  local key="$2"
  # Extract value and strip Nix comments (after semicolon)
  grep -A1 "$key" "$file" | tail -1 | sed 's/;\s*#.*/;/' | sed 's/.*= "\(.*\)";/\1/' | sed 's/.*= \(.*\);/\1/' | tr -d '"'
}

# Function to extract nested value
extract_nested() {
  local file="$1"
  local section="$2"
  local key="$3"
  # Extract value and strip Nix comments (after semicolon)
  awk "/$section = {/,/};/" "$file" | grep -w "$key" | sed 's/;\s*#.*/;/' | sed 's/.*= "\(.*\)";/\1/' | sed 's/.*= \(.*\);/\1/' | tr -d '"'
}

# Parse Nix theme files and generate config files
for theme_file in "$THEMES_SOURCE"/*.nix; do
  theme_name=$(basename "$theme_file" .nix)
  theme_dir="$THEMES_DEST/$theme_name"

  echo "Generating theme: $theme_name"
  mkdir -p "$theme_dir"

  # Generate hyprland.conf
  active_border=$(extract_nested "$theme_file" "hyprland" "activeBorder")
  inactive_border=$(extract_nested "$theme_file" "hyprland" "inactiveBorder")

  cat > "$theme_dir/hyprland.conf" <<EOF
# Hyprland border colors for $theme_name
general {
  col.active_border = $active_border
  col.inactive_border = $inactive_border
}
EOF

  # Generate waybar.css
  waybar_fg=$(extract_nested "$theme_file" "waybar" "foreground")
  waybar_bg=$(extract_nested "$theme_file" "waybar" "background")

  cat > "$theme_dir/waybar.css" <<EOF
/* Waybar colors for $theme_name */
@define-color foreground $waybar_fg;
@define-color background $waybar_bg;
EOF

  # Generate alacritty.toml - extract all colors
  primary_bg=$(awk '/alacritty = {/,/};/' "$theme_file" | grep -A3 "primary" | grep "background" | sed 's/.*= "\(.*\)";/\1/')
  primary_fg=$(awk '/alacritty = {/,/};/' "$theme_file" | grep -A3 "primary" | grep "foreground" | sed 's/.*= "\(.*\)";/\1/')

  # Normal colors
  normal_black=$(awk '/normal = {/,/};/' "$theme_file" | grep "black" | sed 's/.*= "\(.*\)";/\1/')
  normal_red=$(awk '/normal = {/,/};/' "$theme_file" | grep "red" | sed 's/.*= "\(.*\)";/\1/')
  normal_green=$(awk '/normal = {/,/};/' "$theme_file" | grep "green" | sed 's/.*= "\(.*\)";/\1/')
  normal_yellow=$(awk '/normal = {/,/};/' "$theme_file" | grep "yellow" | sed 's/.*= "\(.*\)";/\1/')
  normal_blue=$(awk '/normal = {/,/};/' "$theme_file" | grep "blue" | sed 's/.*= "\(.*\)";/\1/')
  normal_magenta=$(awk '/normal = {/,/};/' "$theme_file" | grep "magenta" | sed 's/.*= "\(.*\)";/\1/')
  normal_cyan=$(awk '/normal = {/,/};/' "$theme_file" | grep "cyan" | sed 's/.*= "\(.*\)";/\1/')
  normal_white=$(awk '/normal = {/,/};/' "$theme_file" | grep "white" | sed 's/.*= "\(.*\)";/\1/')

  # Bright colors
  bright_black=$(awk '/bright = {/,/};/' "$theme_file" | grep "black" | sed 's/.*= "\(.*\)";/\1/')
  bright_red=$(awk '/bright = {/,/};/' "$theme_file" | grep "red" | sed 's/.*= "\(.*\)";/\1/')
  bright_green=$(awk '/bright = {/,/};/' "$theme_file" | grep "green" | sed 's/.*= "\(.*\)";/\1/')
  bright_yellow=$(awk '/bright = {/,/};/' "$theme_file" | grep "yellow" | sed 's/.*= "\(.*\)";/\1/')
  bright_blue=$(awk '/bright = {/,/};/' "$theme_file" | grep "blue" | sed 's/.*= "\(.*\)";/\1/')
  bright_magenta=$(awk '/bright = {/,/};/' "$theme_file" | grep "magenta" | sed 's/.*= "\(.*\)";/\1/')
  bright_cyan=$(awk '/bright = {/,/};/' "$theme_file" | grep "cyan" | sed 's/.*= "\(.*\)";/\1/')
  bright_white=$(awk '/bright = {/,/};/' "$theme_file" | grep "white" | sed 's/.*= "\(.*\)";/\1/')

  cat > "$theme_dir/alacritty.toml" <<EOF
# Alacritty colors for $theme_name
[colors.primary]
background = "$primary_bg"
foreground = "$primary_fg"

[colors.normal]
black = "$normal_black"
red = "$normal_red"
green = "$normal_green"
yellow = "$normal_yellow"
blue = "$normal_blue"
magenta = "$normal_magenta"
cyan = "$normal_cyan"
white = "$normal_white"

[colors.bright]
black = "$bright_black"
red = "$bright_red"
green = "$bright_green"
yellow = "$bright_yellow"
blue = "$bright_blue"
magenta = "$bright_magenta"
cyan = "$bright_cyan"
white = "$bright_white"
EOF

  # Generate walker.css
  walker_selected=$(extract_nested "$theme_file" "walker" "selectedText")
  walker_text=$(extract_nested "$theme_file" "walker" "text")
  walker_base=$(extract_nested "$theme_file" "walker" "base")
  walker_border=$(extract_nested "$theme_file" "walker" "border")

  cat > "$theme_dir/walker.css" <<EOF
/* Walker launcher colors for $theme_name */
@define-color selected-text $walker_selected;
@define-color text $walker_text;
@define-color base $walker_base;
@define-color border $walker_border;
@define-color foreground $walker_text;
@define-color background $walker_base;
EOF

  # Generate mako config (complete with include directive)
  mako_text=$(extract_nested "$theme_file" "mako" "textColor")
  mako_border=$(extract_nested "$theme_file" "mako" "borderColor")
  mako_bg=$(extract_nested "$theme_file" "mako" "backgroundColor")

  cat > "$theme_dir/mako.ini" <<EOF
# Mako notification config for $theme_name
# Include base settings
include=$HOME/.config/mako/core.ini

# Theme colors
text-color=$mako_text
border-color=$mako_border
background-color=$mako_bg
progress-color=$mako_text
EOF

  # Generate swayosd.css (complete with colors)
  swayosd_bg=$(extract_nested "$theme_file" "swayosd" "backgroundColor")
  swayosd_border=$(extract_nested "$theme_file" "swayosd" "borderColor")
  swayosd_text=$(extract_nested "$theme_file" "swayosd" "textColor")

  cat > "$theme_dir/swayosd.css" <<EOF
/* SwayOSD theme for $theme_name */
window {
  background-color: $swayosd_bg;
  border: 2px solid $swayosd_border;
  border-radius: 0;
}

label, image {
  color: $swayosd_text;
}

progressbar {
  background-color: $swayosd_bg;
}

trough {
  background-color: $swayosd_border;
}

progress {
  background-color: $swayosd_text;
}
EOF

  # Generate vscode.json
  vscode_theme=$(extract_nested "$theme_file" "vscode" "theme")

  cat > "$theme_dir/vscode.json" <<EOF
{
  "workbench.colorTheme": "$vscode_theme"
}
EOF

  # Generate chromium.theme
  browser_color=$(extract_nested "$theme_file" "browser" "themeColor")
  echo "$browser_color" > "$theme_dir/chromium.theme"

  # Generate hyprlock.conf colors
  hyprlock_outer=$(extract_nested "$theme_file" "hyprlock" "outerColor")
  hyprlock_inner=$(extract_nested "$theme_file" "hyprlock" "innerColor")
  hyprlock_font=$(extract_nested "$theme_file" "hyprlock" "fontColor")
  hyprlock_check=$(extract_nested "$theme_file" "hyprlock" "checkColor")

  # Convert hex colors to rgba for hyprlock
  # Extract RGB from hex colors like #2e3440
  outer_rgb=$(echo "$hyprlock_outer" | sed 's/#//' | sed 's/../0x& /g')
  inner_rgb=$(echo "$hyprlock_inner" | sed 's/#//' | sed 's/../0x& /g')
  font_rgb=$(echo "$hyprlock_font" | sed 's/#//' | sed 's/../0x& /g')
  check_rgb=$(echo "$hyprlock_check" | sed 's/#//' | sed 's/../0x& /g')

  # Convert to decimal
  outer_r=$(($(echo "$outer_rgb" | awk '{print $1}')))
  outer_g=$(($(echo "$outer_rgb" | awk '{print $2}')))
  outer_b=$(($(echo "$outer_rgb" | awk '{print $3}')))

  inner_r=$(($(echo "$inner_rgb" | awk '{print $1}')))
  inner_g=$(($(echo "$inner_rgb" | awk '{print $2}')))
  inner_b=$(($(echo "$inner_rgb" | awk '{print $3}')))

  font_r=$(($(echo "$font_rgb" | awk '{print $1}')))
  font_g=$(($(echo "$font_rgb" | awk '{print $2}')))
  font_b=$(($(echo "$font_rgb" | awk '{print $3}')))

  check_r=$(($(echo "$check_rgb" | awk '{print $1}')))
  check_g=$(($(echo "$check_rgb" | awk '{print $2}')))
  check_b=$(($(echo "$check_rgb" | awk '{print $3}')))

  # Get background color for main color variable
  bg_color=$(echo "$primary_bg" | sed 's/#//' | sed 's/../0x& /g')
  bg_r=$(($(echo "$bg_color" | awk '{print $1}')))
  bg_g=$(($(echo "$bg_color" | awk '{print $2}')))
  bg_b=$(($(echo "$bg_color" | awk '{print $3}')))

  cat > "$theme_dir/hyprlock.conf" <<EOF
# hyprlock colors for $theme_name
\$color = rgba($bg_r,$bg_g,$bg_b,1.0)
\$inner_color = rgba($inner_r,$inner_g,$inner_b,0.8)
\$outer_color = rgba($outer_r,$outer_g,$outer_b,1.0)
\$font_color = rgba($font_r,$font_g,$font_b,1.0)
\$check_color = rgba($check_r,$check_g,$check_b,1.0)
EOF

  # Generate neovim.lua with theme mapping
  # Map theme names to LazyVim colorschemes (matches neovim.nix mapping)
  case "$theme_name" in
    tokyo-night) nvim_colorscheme="tokyonight" ;;
    catppuccin|catppuccin-latte) nvim_colorscheme="catppuccin" ;;
    gruvbox) nvim_colorscheme="gruvbox" ;;
    nord) nvim_colorscheme="nordfox" ;;
    rose-pine) nvim_colorscheme="rose-pine" ;;
    everforest) nvim_colorscheme="everforest" ;;
    kanagawa) nvim_colorscheme="kanagawa" ;;
    matte-black) nvim_colorscheme="tokyonight-night" ;;
    osaka-jade) nvim_colorscheme="tokyonight" ;;
    ristretto) nvim_colorscheme="tokyonight" ;;
    *) nvim_colorscheme="tokyonight" ;;
  esac
  echo "return \"$nvim_colorscheme\"" > "$theme_dir/neovim.lua"

  # Create backgrounds symlink (point to Omarchy's backgrounds if they exist)
  OMARCHY_BACKGROUNDS="$HOME/Projects/jamesbrink/notsure/omarchy/themes/$theme_name/backgrounds"
  if [[ -d "$OMARCHY_BACKGROUNDS" ]]; then
    ln -nsf "$OMARCHY_BACKGROUNDS" "$theme_dir/backgrounds"
  fi

  echo "  ✓ Generated $theme_name"
done

echo ""
echo "Theme generation complete! Themes available in $THEMES_DEST"
echo ""
echo "Available themes:"
ls -1 "$THEMES_DEST"
