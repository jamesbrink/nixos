# Ghostty theme cycling support for Darwin
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

  # Theme cycle script
  cycleScript = pkgs.writeScriptBin "ghostty-cycle-theme" ''
    #!/usr/bin/env bash
    # Cycle through Ghostty themes on macOS

    CONFIG_FILE="$HOME/.config/ghostty/config"
    CURRENT_THEME_FILE="$HOME/.config/ghostty/.current-theme"
    WALLPAPERS_DIR="$HOME/.config/ghostty/wallpapers"
    VSCODE_THEME_MAP="$HOME/.config/ghostty/vscode-themes.json"
    mkdir -p "$HOME/.config/ghostty/themes"

    reload_ghostty_config() {
      local ghostty_bin=""

      if command -v ghostty >/dev/null 2>&1; then
        ghostty_bin="$(command -v ghostty)"
      elif [[ -x "/Applications/Ghostty.app/Contents/MacOS/ghostty" ]]; then
        ghostty_bin="/Applications/Ghostty.app/Contents/MacOS/ghostty"
      fi

      [[ -z "$ghostty_bin" ]] && return
      pgrep -x Ghostty >/dev/null 2>&1 || return
      "$ghostty_bin" +reload-config >/dev/null 2>&1 || true
    }

    # Theme name to Ghostty built-in theme mapping
    declare -A THEME_MAP=(
      ["catppuccin-latte"]="catppuccin-latte"
      ["catppuccin"]="catppuccin-mocha"
      ["everforest"]="Everforest Dark - Hard"
      ["flexoki-light"]="flexoki-light"
      ["gruvbox"]="GruvboxDark"
      ["kanagawa"]="Kanagawa Wave"
      ["matte-black"]="matte-black"
      ["nord"]="nord"
      ["osaka-jade"]="osaka-jade"
      ["ristretto"]="Monokai Pro Ristretto"
      ["rose-pine"]="rose-pine"
      ["tokyo-night"]="tokyonight_night"
    )

    # Get list of themes (sorted keys)
    THEMES=($(printf '%s\n' "''${!THEME_MAP[@]}" | sort))

    if [[ ''${#THEMES[@]} -eq 0 ]]; then
      echo "No themes configured"
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
    GHOSTTY_THEME="''${THEME_MAP[$NEXT_THEME]}"

    # Update Ghostty config
    if [[ -n "$GHOSTTY_THEME" ]]; then
      # Update or add theme line
      if grep -q "^theme = " "$CONFIG_FILE"; then
        sed -i.bak "s|^theme = .*|theme = $GHOSTTY_THEME|" "$CONFIG_FILE"
      else
        echo "theme = $GHOSTTY_THEME" >> "$CONFIG_FILE"
      fi

      # Update or add background opacity
      if grep -q "^background-opacity = " "$CONFIG_FILE"; then
        sed -i.bak "s|^background-opacity = .*|background-opacity = 0.97|" "$CONFIG_FILE"
      else
        echo "background-opacity = 0.97" >> "$CONFIG_FILE"
      fi

      # Reload Ghostty config (Ghostty auto-reloads on config change)
      touch "$CONFIG_FILE"
      reload_ghostty_config

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
    pkgs.jq
  ];

  # Generate wallpaper symlinks and script symlink
  home.file = {
    ".local/bin/ghostty-cycle-theme" = {
      source = "${cycleScript}/bin/ghostty-cycle-theme";
    };
    ".config/ghostty/vscode-themes.json".text = builtins.toJSON (
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
            name = ".config/ghostty/wallpapers/${themeName}/${wallpaper}";
            value = {
              source = wallpaperSource themeName wallpaper;
            };
          }) wallpapers
        else
          [ ]
      ) themeFiles
    )
  )
  // hyprThemes.ghosttyCustomThemes;
}
