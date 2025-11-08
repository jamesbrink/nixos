# Alacritty theme cycling support for Darwin
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Import all Hyprland theme definitions
  themeFiles = [
    ../hyprland/themes/catppuccin-latte.nix
    ../hyprland/themes/catppuccin.nix
    ../hyprland/themes/everforest.nix
    ../hyprland/themes/flexoki-light.nix
    ../hyprland/themes/gruvbox.nix
    ../hyprland/themes/kanagawa.nix
    ../hyprland/themes/matte-black.nix
    ../hyprland/themes/nord.nix
    ../hyprland/themes/osaka-jade.nix
    ../hyprland/themes/ristretto.nix
    ../hyprland/themes/rose-pine.nix
    ../hyprland/themes/tokyo-night.nix
  ];

  # Generate Alacritty TOML config for a theme
  themeToToml = themeDef: ''
    [colors.primary]
    background = "${themeDef.alacritty.primary.background}"
    foreground = "${themeDef.alacritty.primary.foreground}"

    [colors.normal]
    black = "${themeDef.alacritty.normal.black}"
    red = "${themeDef.alacritty.normal.red}"
    green = "${themeDef.alacritty.normal.green}"
    yellow = "${themeDef.alacritty.normal.yellow}"
    blue = "${themeDef.alacritty.normal.blue}"
    magenta = "${themeDef.alacritty.normal.magenta}"
    cyan = "${themeDef.alacritty.normal.cyan}"
    white = "${themeDef.alacritty.normal.white}"

    [colors.bright]
    black = "${themeDef.alacritty.bright.black}"
    red = "${themeDef.alacritty.bright.red}"
    green = "${themeDef.alacritty.bright.green}"
    yellow = "${themeDef.alacritty.bright.yellow}"
    blue = "${themeDef.alacritty.bright.blue}"
    magenta = "${themeDef.alacritty.bright.magenta}"
    cyan = "${themeDef.alacritty.bright.cyan}"
    white = "${themeDef.alacritty.bright.white}"
  '';

  # Theme cycle script
  cycleScript = pkgs.writeScriptBin "alacritty-cycle-theme" ''
    #!/usr/bin/env bash
    # Cycle through Alacritty themes on macOS

    THEMES_DIR="$HOME/.config/alacritty/themes"
    CONFIG_FILE="$HOME/.config/alacritty/alacritty.toml"
    CURRENT_THEME_FILE="$HOME/.config/alacritty/.current-theme"

    # Get list of themes
    THEMES=($(ls -1 "$THEMES_DIR" | sort))

    if [[ ''${#THEMES[@]} -eq 0 ]]; then
      echo "No themes found in $THEMES_DIR"
      exit 1
    fi

    # Read current theme
    CURRENT_THEME=""
    if [[ -f "$CURRENT_THEME_FILE" ]]; then
      CURRENT_THEME=$(cat "$CURRENT_THEME_FILE")
    fi

    # Find next theme
    NEXT_INDEX=0
    if [[ -n "$CURRENT_THEME" ]]; then
      for i in "''${!THEMES[@]}"; do
        if [[ "''${THEMES[$i]}" == "$CURRENT_THEME" ]]; then
          NEXT_INDEX=$(( (i + 1) % ''${#THEMES[@]} ))
          break
        fi
      done
    fi

    NEXT_THEME="''${THEMES[$NEXT_INDEX]}"

    # Update config with new theme colors
    if [[ -f "$THEMES_DIR/$NEXT_THEME" ]]; then
      # Remove old [colors] section and append new one
      sed -i.bak '/^\[colors/,/^$/d' "$CONFIG_FILE"
      cat "$THEMES_DIR/$NEXT_THEME" >> "$CONFIG_FILE"

      # Save current theme
      echo "$NEXT_THEME" > "$CURRENT_THEME_FILE"

      # Show notification
      echo "Switched to theme: $NEXT_THEME"
      osascript -e "display notification \"$NEXT_THEME\" with title \"Alacritty Theme\""
    fi
  '';
in
{
  home.packages = [ cycleScript ];

  # Generate theme files from Hyprland theme definitions and create symlink
  home.file = {
    ".local/bin/alacritty-cycle-theme" = {
      source = "${cycleScript}/bin/alacritty-cycle-theme";
    };
  }
  // lib.listToAttrs (
    map (
      themeFile:
      let
        themeDef = import themeFile;
        themeName = themeDef.name;
      in
      {
        name = ".config/alacritty/themes/${themeName}";
        value = {
          text = themeToToml themeDef;
        };
      }
    ) themeFiles
  );
}
