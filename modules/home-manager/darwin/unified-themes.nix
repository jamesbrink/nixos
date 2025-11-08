# Unified theme cycling support for Darwin (Alacritty + Ghostty + VSCode + macOS)
# Tip: export THEME_DISABLE_EDITOR_AUTOMATION=1 to skip the AppleScript reloads for VSCode/Cursor if they become distracting.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  hyprThemes = import ../hyprland/themes/lib.nix { };

  # Import all Hyprland theme definitions
  themeFiles = hyprThemes.themeFiles;

  # Wallpaper lookup helper (prefers local overrides, falls back to Omarchy submodule)
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

  ghosttyThemeMap = hyprThemes.ghosttyThemeMap;
  ghosttyCustomThemes = hyprThemes.ghosttyCustomThemes;

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

            # Set THEME_DISABLE_EDITOR_AUTOMATION=1 to skip VSCode/Cursor AppleScript reloads.
            reload_editor_theme() {
              local app_name="$1"
              local process_name="$2"
              local theme_name="$3"

              [[ -z "$theme_name" ]] && return

              if [[ "''${THEME_DISABLE_EDITOR_AUTOMATION:-0}" == "1" ]]; then
                echo "  ✓ Updated ''${app_name} theme (automation disabled)"
                return
              fi

              if ! pgrep -x "$process_name" >/dev/null 2>&1; then
                return
              fi

              if /usr/bin/osascript <<APPLESCRIPT "$app_name" "$process_name" "$theme_name" >/dev/null 2>&1; then
    on run argv
      set targetApp to item 1 of argv
      set processName to item 2 of argv
      set themeName to item 3 of argv
      tell application targetApp to activate
      delay 0.15
      tell application "System Events"
        if not (exists process processName) then return
        tell process processName
          keystroke "k" using {command down}
          delay 0.05
          keystroke "t" using {command down}
          delay 0.2
          keystroke themeName
          delay 0.1
          key code 36
        end tell
      end tell
    end run
    APPLESCRIPT
                echo "  ✓ Reloaded ''${app_name} theme"
              else
                echo "  [!] Unable to automate ''${app_name} theme reload (grant accessibility permissions or set THEME_DISABLE_EDITOR_AUTOMATION=1)"
              fi
            }

            reload_vscode_theme() {
              reload_editor_theme "Visual Studio Code" "Code" "$1"
            }

            reload_cursor_theme() {
              reload_editor_theme "Cursor" "Cursor" "$1"
            }

            reload_nvim_theme() {
              local colorscheme="$1"

              if [[ -z "$colorscheme" ]]; then
                return
              fi

              if ! command -v nvr >/dev/null 2>&1; then
                echo "  ✓ Updated Neovim theme"
                return
              fi

              local servers
              servers=$(nvr --serverlist 2>/dev/null | tr ' ' '\n' | grep -v '^$' || true)

              if [[ -z "$servers" ]]; then
                echo "  ✓ Updated Neovim theme (no running instances)"
                return
              fi

              local reloaded=0
              while read -r server; do
                [[ -z "$server" ]] && continue
                if nvr --servername "$server" --remote-expr "execute('colorscheme ''${colorscheme}')" &>/dev/null; then
                  reloaded=$((reloaded + 1))
                fi
              done <<< "$servers"

              if [[ $reloaded -gt 0 ]]; then
                echo "  ✓ Updated Neovim theme (reloaded $reloaded instance(s))"
              else
                echo "  ✓ Updated Neovim theme (no reachable instances)"
              fi
            }

    reload_ghostty_config() {
      if ! pgrep -x Ghostty >/dev/null 2>&1; then
        return
      fi

      /usr/bin/osascript >/dev/null 2>&1 \
        -e 'tell application "System Events"' \
        -e '  if exists process "Ghostty" then' \
        -e '    set frontApp to first application process whose frontmost is true' \
        -e '    set frontName to name of frontApp' \
        -e '    tell application "Ghostty" to activate' \
        -e '    delay 0.05' \
        -e '    keystroke "," using {command down, shift down}' \
        -e '    delay 0.05' \
        -e '    if frontName is not "Ghostty" then' \
        -e '      tell application frontName to activate' \
        -e '    end if' \
        -e '  end if' \
        -e 'end tell'
    }

            mkdir -p "$HOME/.config/ghostty/themes"

            # Get list of themes (exclude directories and JSON files)
            THEMES=()
            for item in "$THEMES_DIR"/*; do
              [[ -f "$item" ]] && [[ ! "$item" =~ \.json$ ]] && [[ ! "$(basename "$item")" =~ ^\. ]] && THEMES+=("$(basename "$item")")
            done
            THEMES=($(printf '%s\n' "''${THEMES[@]}" | sort))

            if [[ ''${#THEMES[@]} -eq 0 ]]; then
              echo "No themes found in $THEMES_DIR"
              exit 1
            fi

            # Read current theme, default to tokyo-night if not set
            CURRENT_THEME=""
            if [[ -f "$CURRENT_THEME_FILE" ]]; then
              CURRENT_THEME=$(cat "$CURRENT_THEME_FILE")
            fi

            # Set default to tokyo-night if no current theme
            if [[ -z "$CURRENT_THEME" ]]; then
              CURRENT_THEME="tokyo-night"
              echo "$CURRENT_THEME" > "$CURRENT_THEME_FILE"
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
                reload_ghostty_config
              fi
            fi

            # Set wallpaper for ALL desktops/screens if theme has one
            if [[ -d "$WALLPAPERS_DIR/$NEXT_THEME" ]]; then
              FIRST_WALLPAPER=$(ls -1 "$WALLPAPERS_DIR/$NEXT_THEME" | head -1)
              if [[ -n "$FIRST_WALLPAPER" ]]; then
                WALLPAPER_PATH="$WALLPAPERS_DIR/$NEXT_THEME/$FIRST_WALLPAPER"
                # desktoppr sets wallpaper for all spaces and all displays by default
                ${pkgs.desktoppr}/bin/desktoppr "$WALLPAPER_PATH"
                echo "Set wallpaper to: $WALLPAPER_PATH"
              fi
            else
              echo "No wallpaper found for theme: $NEXT_THEME"
            fi

            # Toggle macOS appearance based on theme (macOS Tahoe 26 compatible)
            if [[ "$NEXT_THEME" =~ (latte|light) ]]; then
              # Set to light mode
              osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to false'
              defaults delete NSGlobalDomain AppleInterfaceStyle 2>/dev/null || true
              # Set icon appearance for light mode (macOS Tahoe 26)
              defaults write NSGlobalDomain AppleIconAppearanceTheme -string "RegularLight"
            else
              # Set to dark mode
              osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to true'
              defaults write NSGlobalDomain AppleInterfaceStyle -string "Dark"
              # Set icon appearance for dark mode (macOS Tahoe 26)
              defaults write NSGlobalDomain AppleIconAppearanceTheme -string "RegularDark"
            fi

            # Restart Dock, SystemUIServer, and ControlCenter to apply changes immediately
            killall Dock 2>/dev/null || true
            killall SystemUIServer 2>/dev/null || true
            killall ControlCenter 2>/dev/null || true

            # Update VSCode/Cursor theme (preserve inode for file watchers)
            if [[ -f "$VSCODE_THEME_MAP" ]]; then
              VSCODE_THEME=$(${pkgs.jq}/bin/jq -r ".[\"$NEXT_THEME\"]" "$VSCODE_THEME_MAP")
              if [[ -n "$VSCODE_THEME" && "$VSCODE_THEME" != "null" ]]; then
                for SETTINGS_FILE in "$HOME/Library/Application Support/Code/User/settings.json" "$HOME/Library/Application Support/Cursor/User/settings.json"; do
                  if [[ -f "$SETTINGS_FILE" ]]; then
                    # Strip line comments and use jq
                    # IMPORTANT: Use cat to overwrite in-place to preserve inode (VSCode file watcher needs this)
                    grep -v '^\s*//' "$SETTINGS_FILE" > "$SETTINGS_FILE.nocomments"
                    ${pkgs.jq}/bin/jq --arg theme "$VSCODE_THEME" '.["workbench.colorTheme"] = $theme' "$SETTINGS_FILE.nocomments" | cat > "$SETTINGS_FILE"
                    rm -f "$SETTINGS_FILE.nocomments"
                    echo "Updated VSCode/Cursor theme to: $VSCODE_THEME"
                  fi
                done
                reload_vscode_theme "$VSCODE_THEME"
                reload_cursor_theme "$VSCODE_THEME"
              fi
            fi

            # Update Neovim theme
            NEOVIM_THEME_MAP="$HOME/.config/themes/neovim-themes.json"
            if [[ -f "$NEOVIM_THEME_MAP" ]]; then
              NEOVIM_THEME=$(${pkgs.jq}/bin/jq -r ".[\"$NEXT_THEME\"]" "$NEOVIM_THEME_MAP")
              if [[ -n "$NEOVIM_THEME" && "$NEOVIM_THEME" != "null" ]]; then
                NVIM_THEME_FILE="$HOME/.config/nvim/lua/plugins/theme.lua"
                if [[ -f "$NVIM_THEME_FILE" ]]; then
                  if grep -q 'colorscheme =' "$NVIM_THEME_FILE"; then
                    sed -i "" -e "s/colorscheme = \".*\"/colorscheme = \"$NEOVIM_THEME\"/" "$NVIM_THEME_FILE"
                  fi
                  reload_nvim_theme "$NEOVIM_THEME"
                fi
              fi
            fi

            # Update Tmux theme
            TMUX_THEME_MAP="$HOME/.config/themes/tmux-themes.json"
            if [[ -f "$TMUX_THEME_MAP" ]]; then
              # Extract individual color values directly from JSON
              STATUS_BG=$(${pkgs.jq}/bin/jq -r ".[\"$NEXT_THEME\"].statusBackground" "$TMUX_THEME_MAP")
              STATUS_FG=$(${pkgs.jq}/bin/jq -r ".[\"$NEXT_THEME\"].statusForeground" "$TMUX_THEME_MAP")
              WINDOW_CURRENT=$(${pkgs.jq}/bin/jq -r ".[\"$NEXT_THEME\"].windowStatusCurrent" "$TMUX_THEME_MAP")
              PANE_ACTIVE=$(${pkgs.jq}/bin/jq -r ".[\"$NEXT_THEME\"].paneActiveBorder" "$TMUX_THEME_MAP")
              PANE_INACTIVE=$(${pkgs.jq}/bin/jq -r ".[\"$NEXT_THEME\"].paneInactiveBorder" "$TMUX_THEME_MAP")

              if [[ -n "$STATUS_BG" && "$STATUS_BG" != "null" ]]; then

                # Update tmux.conf.local with theme colors
                {
                  echo "# Tmux theme colors (managed by cycle-theme)"
                  echo "set -g status-style \"bg=$STATUS_BG,fg=$STATUS_FG\""
                  echo "set -g window-status-current-style \"bg=$WINDOW_CURRENT,fg=$STATUS_BG\""
                  echo "set -g pane-active-border-style \"fg=$PANE_ACTIVE\""
                  echo "set -g pane-border-style \"fg=$PANE_INACTIVE\""
                } > "$HOME/.tmux.conf.local"

                # Reload tmux if running
                ${pkgs.tmux}/bin/tmux source-file "$HOME/.tmux.conf" 2>/dev/null || true
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
    pkgs.neovim-remote
  ];

  # Set initial Alacritty opacity
  programs.alacritty.settings.window.opacity = lib.mkForce 0.97;

  # Create mutable .current-theme file with tokyo-night as default
  home.activation.createCurrentThemeFile = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    CURRENT_THEME_FILE="${config.home.homeDirectory}/.config/themes/.current-theme"
    mkdir -p "${config.home.homeDirectory}/.config/themes"

    if [[ ! -f "$CURRENT_THEME_FILE" ]]; then
      $DRY_RUN_CMD echo "tokyo-night" > "$CURRENT_THEME_FILE"
      $DRY_RUN_CMD chmod 644 "$CURRENT_THEME_FILE"
      echo "Created default theme file (tokyo-night)"
    fi
  '';

  # Generate theme files and mappings
  home.file = {
    ".config/themectl/themes.json".source =
      inputs.self.packages.${pkgs.stdenv.system}.themectl-theme-data;
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

    # Neovim colorscheme mapping
    ".config/themes/neovim-themes.json".text = builtins.toJSON {
      "tokyo-night" = "tokyonight";
      "catppuccin" = "catppuccin-mocha";
      "catppuccin-latte" = "catppuccin-latte";
      "gruvbox" = "gruvbox";
      "nord" = "nordfox";
      "rose-pine" = "rose-pine";
      "everforest" = "everforest";
      "kanagawa" = "kanagawa";
      "matte-black" = "tokyonight-night";
      "osaka-jade" = "tokyonight";
      "ristretto" = "monokai-pro-ristretto";
      "flexoki-light" = "flexoki-light";
    };

    # Tmux theme mapping (colors from theme definitions)
    ".config/themes/tmux-themes.json".text = builtins.toJSON (
      builtins.listToAttrs (
        map (
          themeFile:
          let
            themeDef = import themeFile;
          in
          {
            name = themeDef.name;
            value = themeDef.tmux;
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
        in
        if wallpapers != [ ] then
          map (wallpaper: {
            name = ".config/themes/wallpapers/${themeName}/${wallpaper}";
            value = {
              source = wallpaperSource themeName wallpaper;
            };
          }) wallpapers
        else
          [ ]
      ) themeFiles
    )
  )
  // ghosttyCustomThemes;

  # LaunchAgent to restore wallpaper on login
  launchd.agents.restore-wallpaper = {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "-c"
        ''
          CURRENT_THEME_FILE="$HOME/.config/themes/.current-theme"
          WALLPAPERS_DIR="$HOME/.config/themes/wallpapers"

          if [[ -f "$CURRENT_THEME_FILE" ]]; then
            CURRENT_THEME=$(cat "$CURRENT_THEME_FILE")
            if [[ -d "$WALLPAPERS_DIR/$CURRENT_THEME" ]]; then
              FIRST_WALLPAPER=$(ls -1 "$WALLPAPERS_DIR/$CURRENT_THEME" | head -1)
              if [[ -n "$FIRST_WALLPAPER" ]]; then
                ${pkgs.desktoppr}/bin/desktoppr "$WALLPAPERS_DIR/$CURRENT_THEME/$FIRST_WALLPAPER"
              fi
            fi
          fi
        ''
      ];
      RunAtLoad = true;
    };
  };
}
