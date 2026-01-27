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
  hyprThemes = import ../../themes/lib.nix {
    omarchySrc = inputs.omarchy or null;
  };

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

in
{
  imports = [
    ../themectl.nix
  ];

  programs.themectl = {
    enable = true;
    platform = "darwin";
    cycle = map (themeFile: (import themeFile).name) themeFiles;
  };

  home.packages = [
    pkgs.desktoppr
    pkgs.neovim-remote
  ];

  # NOTE: Alacritty opacity and decorations are managed by themectl macos-mode
  # - BSP mode: decorations = "buttonless", opacity = 0.97
  # - Native mode: decorations = "full", opacity = 1.0
  # Do NOT set window.opacity or window.decorations here.

  # Generate theme files and mappings
  home.file = {
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
  // ghosttyCustomThemes
  // {
    # Ghostty configuration for Darwin
    ".config/ghostty/config".text = lib.mkDefault ''
      # Dynamic theme colors
      config-file = ?"~/.config/omarchy/current/theme/ghostty.conf"

      # Font
      font-family = "JetBrainsMono Nerd Font"
      font-style = Regular
      font-size = 9

      # Window
      window-theme = ghostty
      window-padding-x = 14
      window-padding-y = 14
      confirm-close-surface=false
      resize-overlay = never

      # Cursor styling
      cursor-style = "block"
      cursor-style-blink = false

      # Cursor styling + SSH session terminfo
      shell-integration-features = no-cursor,ssh-env

      # Keyboard bindings
      keybind = shift+insert=paste_from_clipboard
      keybind = control+insert=copy_to_clipboard
      keybind = super+control+shift+alt+arrow_down=resize_split:down,100
      keybind = super+control+shift+alt+arrow_up=resize_split:up,100
      keybind = super+control+shift+alt+arrow_left=resize_split:left,100
      keybind = super+control+shift+alt+arrow_right=resize_split:right,100

      # Slowdown mouse scrolling
      mouse-scroll-multiplier = 0.95
    '';
  };

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
