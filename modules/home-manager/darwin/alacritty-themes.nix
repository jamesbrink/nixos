# Alacritty theme cycling support for Darwin
{
  config,
  lib,
  pkgs,
  ...
}:

let
  hyprThemes = import ../hyprland/themes/lib.nix { };

  # Import all Hyprland theme definitions
  themeFiles = hyprThemes.themeFiles;

  wallpaperSource = hyprThemes.getWallpaperSource;

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
    WALLPAPERS_DIR="$HOME/.config/alacritty/wallpapers"
    VSCODE_THEME_MAP="$HOME/.config/alacritty/vscode-themes.json"

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
      # Remove old [colors] section using awk (handles TOML sections properly)
      awk '/^\[colors/ {skip=1} /^\[/ && !/^\[colors/ {skip=0} !skip' "$CONFIG_FILE" > "$CONFIG_FILE.tmp"
      mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

      # Append new theme colors
      cat "$THEMES_DIR/$NEXT_THEME" >> "$CONFIG_FILE"

      # Set Alacritty opacity to 0.97 (matching Hyprland)
      if grep -q "^opacity = " "$CONFIG_FILE"; then
        sed -i.bak 's/^opacity = .*/opacity = 0.97/' "$CONFIG_FILE"
      else
        # Add opacity to [window] section if it doesn't exist
        awk '/^\[window\]/ {print; print "opacity = 0.97"; next} 1' "$CONFIG_FILE" > "$CONFIG_FILE.tmp"
        mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
      fi

      # Touch the file to ensure Alacritty detects the change
      touch "$CONFIG_FILE"

      # Set wallpaper if theme has one
      if [[ -d "$WALLPAPERS_DIR/$NEXT_THEME" ]]; then
        FIRST_WALLPAPER=$(ls -1 "$WALLPAPERS_DIR/$NEXT_THEME" | head -1)
        if [[ -n "$FIRST_WALLPAPER" ]]; then
          ${pkgs.desktoppr}/bin/desktoppr "$WALLPAPERS_DIR/$NEXT_THEME/$FIRST_WALLPAPER"
        fi
      fi

      # Toggle macOS appearance based on theme (light themes get light mode, dark themes get dark mode)
      if [[ "$NEXT_THEME" =~ (latte|light) ]]; then
        osascript -e 'tell app "System Events" to tell appearance preferences to set dark mode to false'
      else
        osascript -e 'tell app "System Events" to tell appearance preferences to set dark mode to true'
      fi

      # Update VSCode/Cursor theme if theme map exists
      if [[ -f "$VSCODE_THEME_MAP" ]]; then
        VSCODE_THEME=$(${pkgs.jq}/bin/jq -r ".[\"$NEXT_THEME\"]" "$VSCODE_THEME_MAP")
        if [[ -n "$VSCODE_THEME" && "$VSCODE_THEME" != "null" ]]; then
          # Update VSCode settings
          for SETTINGS_FILE in "$HOME/Library/Application Support/Code/User/settings.json" "$HOME/Library/Application Support/Cursor/User/settings.json"; do
            if [[ -f "$SETTINGS_FILE" ]]; then
              ${pkgs.jq}/bin/jq --arg theme "$VSCODE_THEME" '.["workbench.colorTheme"] = $theme' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
            fi
          done
        fi
      fi

      # Save current theme
      echo "$NEXT_THEME" > "$CURRENT_THEME_FILE"

      # Show notification
      echo "Switched to theme: $NEXT_THEME"
      osascript -e "display notification \"$NEXT_THEME\" with title \"Theme\""
    fi
  '';
in
{
  home.packages = [
    cycleScript
    pkgs.desktoppr
    pkgs.jq
  ];

  # Set initial Alacritty opacity (override shell module setting)
  programs.alacritty.settings.window.opacity = lib.mkForce 0.97;

  # Generate theme files from Hyprland theme definitions and create symlink
  home.file = {
    ".local/bin/alacritty-cycle-theme" = {
      source = "${cycleScript}/bin/alacritty-cycle-theme";
    };
    ".config/alacritty/vscode-themes.json".text = builtins.toJSON (
      builtins.listToAttrs (
        map (
          themeFile:
          let
            themeDef = import themeFile;
          in
          {
            name = themeDef.name;
            value = themeDef.vscode.theme;
          }
        ) themeFiles
      )
    );
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
  )
  // lib.listToAttrs (
    lib.flatten (
      map (
        themeFile:
        let
          themeDef = import themeFile;
          themeName = themeDef.name;
          wallpapers = themeDef.wallpapers or [ ];
        in
        if wallpapers != [ ] then
          map (wallpaper: {
            name = ".config/alacritty/wallpapers/${themeName}/${wallpaper}";
            value = {
              source = wallpaperSource themeName wallpaper;
            };
          }) wallpapers
        else
          [ ]
      ) themeFiles
    )
  );
}
