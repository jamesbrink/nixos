# Unified theme cycling support for Darwin (Alacritty + Ghostty + VSCode + macOS)
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

  # Wallpapers base directory
  wallpapersBaseDir = ../hyprland/wallpapers;

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

  # Theme name to Ghostty built-in theme mapping
  ghosttyThemeMap = {
    "catppuccin-latte" = "catppuccin-latte";
    "catppuccin" = "catppuccin-mocha";
    "everforest" = "Everforest Dark";
    "flexoki-light" = "Flexoki Light";
    "gruvbox" = "GruvboxDark";
    "kanagawa" = "Kanagawa";
    "matte-black" = "Darcula";
    "nord" = "nord";
    "osaka-jade" = "Material";
    "ristretto" = "Monokai Pro Ristretto";
    "rose-pine" = "Rosé Pine";
    "tokyo-night" = "Tokyo Night";
  };

  # Unified theme cycle script
  cycleScript = pkgs.writeScriptBin "cycle-theme" ''
    #!/usr/bin/env bash
    # Unified theme cycling for macOS (Alacritty + Ghostty + VSCode + Wallpaper + System Appearance)

    THEMES_DIR="$HOME/.config/themes"
    CURRENT_THEME_FILE="$HOME/.config/themes/.current-theme"
    WALLPAPERS_DIR="$HOME/.config/themes/wallpapers"
    VSCODE_THEME_MAP="$HOME/.config/themes/vscode-themes.json"
    GHOSTTY_THEME_MAP="$HOME/.config/themes/ghostty-themes.json"

    ALACRITTY_CONFIG="$HOME/.config/alacritty/alacritty.toml"
    GHOSTTY_CONFIG="$HOME/.config/ghostty/config"

    # Get list of themes
    THEMES=($(ls -1 "$THEMES_DIR" | grep -v "^\." | grep -v ".json" | sort))

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

    # Update Alacritty theme
    if [[ -f "$ALACRITTY_CONFIG" && -f "$THEMES_DIR/$NEXT_THEME" ]]; then
      # Remove old [colors] section
      awk '/^\[colors/ {skip=1} /^\[/ && !/^\[colors/ {skip=0} !skip' "$ALACRITTY_CONFIG" > "$ALACRITTY_CONFIG.tmp"
      mv "$ALACRITTY_CONFIG.tmp" "$ALACRITTY_CONFIG"

      # Append new theme colors
      cat "$THEMES_DIR/$NEXT_THEME" >> "$ALACRITTY_CONFIG"

      # Set opacity
      if grep -q "^opacity = " "$ALACRITTY_CONFIG"; then
        sed -i.bak 's/^opacity = .*/opacity = 0.97/' "$ALACRITTY_CONFIG"
      else
        awk '/^\[window\]/ {print; print "opacity = 0.97"; next} 1' "$ALACRITTY_CONFIG" > "$ALACRITTY_CONFIG.tmp"
        mv "$ALACRITTY_CONFIG.tmp" "$ALACRITTY_CONFIG"
      fi

      touch "$ALACRITTY_CONFIG"
    fi

    # Update Ghostty theme
    if [[ -f "$GHOSTTY_CONFIG" && -f "$GHOSTTY_THEME_MAP" ]]; then
      GHOSTTY_THEME=$(${pkgs.jq}/bin/jq -r ".[\"$NEXT_THEME\"]" "$GHOSTTY_THEME_MAP")
      if [[ -n "$GHOSTTY_THEME" && "$GHOSTTY_THEME" != "null" ]]; then
        # Update or add theme line
        if grep -q "^theme = " "$GHOSTTY_CONFIG"; then
          sed -i.bak "s|^theme = .*|theme = $GHOSTTY_THEME|" "$GHOSTTY_CONFIG"
        else
          echo "theme = $GHOSTTY_THEME" >> "$GHOSTTY_CONFIG"
        fi

        # Update or add background opacity
        if grep -q "^background-opacity = " "$GHOSTTY_CONFIG"; then
          sed -i.bak "s|^background-opacity = .*|background-opacity = 0.97|" "$GHOSTTY_CONFIG"
        else
          echo "background-opacity = 0.97" >> "$GHOSTTY_CONFIG"
        fi

        touch "$GHOSTTY_CONFIG"
      fi
    fi

    # Set wallpaper if theme has one
    if [[ -d "$WALLPAPERS_DIR/$NEXT_THEME" ]]; then
      FIRST_WALLPAPER=$(ls -1 "$WALLPAPERS_DIR/$NEXT_THEME" | head -1)
      if [[ -n "$FIRST_WALLPAPER" ]]; then
        ${pkgs.desktoppr}/bin/desktoppr "$WALLPAPERS_DIR/$NEXT_THEME/$FIRST_WALLPAPER"
      fi
    fi

    # Toggle macOS appearance based on theme
    if [[ "$NEXT_THEME" =~ (latte|light) ]]; then
      osascript -e 'tell app "System Events" to tell appearance preferences to set dark mode to false'
    else
      osascript -e 'tell app "System Events" to tell appearance preferences to set dark mode to true'
    fi

    # Update VSCode/Cursor theme
    if [[ -f "$VSCODE_THEME_MAP" ]]; then
      VSCODE_THEME=$(${pkgs.jq}/bin/jq -r ".[\"$NEXT_THEME\"]" "$VSCODE_THEME_MAP")
      if [[ -n "$VSCODE_THEME" && "$VSCODE_THEME" != "null" ]]; then
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
  '';
in
{
  home.packages = [
    cycleScript
    pkgs.desktoppr
    pkgs.jq
  ];

  # Set initial Alacritty opacity
  programs.alacritty.settings.window.opacity = lib.mkForce 0.97;

  # Generate theme files and mappings
  home.file = {
    ".local/bin/cycle-theme" = {
      source = "${cycleScript}/bin/cycle-theme";
    };

    # VSCode theme mapping
    ".config/themes/vscode-themes.json".text = builtins.toJSON (
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

    # Ghostty theme mapping
    ".config/themes/ghostty-themes.json".text = builtins.toJSON ghosttyThemeMap;
  }
  // lib.listToAttrs (
    map (
      themeFile:
      let
        themeDef = import themeFile;
        themeName = themeDef.name;
      in
      {
        name = ".config/themes/${themeName}";
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
          wallpaperDir = "${wallpapersBaseDir}/${themeName}";
        in
        if wallpapers != [ ] then
          map (wallpaper: {
            name = ".config/themes/wallpapers/${themeName}/${wallpaper}";
            value = {
              source = "${wallpaperDir}/${wallpaper}";
            };
          }) wallpapers
        else
          [ ]
      ) themeFiles
    )
  );
}
