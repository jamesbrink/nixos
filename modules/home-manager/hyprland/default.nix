# Hyprland window manager configuration with theme system
#
# To switch themes:
# 1. Change the `selectedTheme` variable below to one of the available themes
# 2. Run: nixos-rebuild switch --flake /etc/nixos/#default
# 3. Run: hyprctl reload (to reload without logging out)
#
# Available themes:
#   - tokyo-night   (default, dark blue/purple cyberpunk aesthetic)
#   - catppuccin    (pastel macchiato dark theme)
#   - gruvbox       (warm retro dark theme)
#   - nord          (cool arctic dark theme)
#   - rose-pine     (muted mauve moon theme)
#
# Each theme includes colors for:
#   - Hyprland (borders)
#   - Alacritty (terminal)
#   - GTK (system theme)
#   - VSCode (editor)
#   - Icons (theme pack)
#
{
  config,
  pkgs,
  lib,
  ...
}:

let
  # Select theme - change this to switch themes
  selectedTheme = "ristretto";

  # Load theme configuration
  themeConfig = import (./themes + "/${selectedTheme}.nix");

  # Resolve GTK theme package
  gtkThemePackage =
    if themeConfig.gtk.themePackage == "catppuccin-gtk" then
      pkgs.catppuccin-gtk.override {
        accents = [ "blue" ];
        variant = "macchiato";
      }
    else
      pkgs.${themeConfig.gtk.themePackage};

  # Resolve icon theme package
  iconThemePackage = pkgs.${themeConfig.gtk.iconPackage};

  # Font configuration (Omarchy uses CaskaydiaMono, but JetBrainsMono is similar)
  fontFamily = "JetBrainsMono Nerd Font";
  fontSize = 12; # Default font size for terminals, editors
  fontSizeLauncher = 18; # Walker application launcher
  fontSizeStatusBar = 14; # Waybar status bar
  fontSizePowerMenu = 16; # wlogout power menu
  fontSizeGtk = 10; # GTK applications default

  # Wallpaper path (first wallpaper from theme)
  wallpaperPath =
    if (builtins.length themeConfig.wallpapers) > 0 then
      "${./wallpapers}/${selectedTheme}/${builtins.head themeConfig.wallpapers}"
    else
      null;
in
{
  # Hyprland window manager
  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      # Omarchy-style keybindings
      "$mod" = "SUPER";

      # Visual settings - Omarchy style (sharp corners)
      decoration = {
        rounding = 0;
      };

      # Theme colors
      general = {
        "col.active_border" = themeConfig.hyprland.activeBorder;
        "col.inactive_border" = themeConfig.hyprland.inactiveBorder;
      };

      # Dwindle layout configuration (Omarchy-style)
      dwindle = {
        pseudotile = true; # Enable pseudotiling
        preserve_split = true; # Preserve split direction
        force_split = 2; # Always split on the right (Omarchy default)
      };

      # Layer rules - disable animations for Walker (Omarchy-style)
      layerrule = [
        "noanim, walker"
      ];

      # Window rules (Omarchy-style)
      windowrule = [
        # Suppress maximize events for all windows
        "suppressevent maximize, class:.*"

        # Base opacity for all windows (subtle transparency)
        "opacity 0.97 0.9, class:.*"

        # Fix some dragging issues with XWayland
        "nofocus,class:^$,title:^$,xwayland:1,floating:1,fullscreen:0,pinned:0"

        # Terminal scroll sensitivity (touchpad)
        "scrolltouchpad 1.5, class:(Alacritty|kitty)"
        "scrolltouchpad 0.2, class:com.mitchellh.ghostty"

        # Browser types - tag identification
        "tag +chromium-based-browser, class:([cC]hrom(e|ium)|[bB]rave-browser|Microsoft-edge|Vivaldi-stable)"
        "tag +firefox-based-browser, class:([fF]irefox|zen|librewolf)"

        # Force chromium-based browsers into a tile to deal with --app bug
        "tile, tag:chromium-based-browser"

        # Only subtle opacity change for browsers
        "opacity 1 0.97, tag:chromium-based-browser"
        "opacity 1 0.97, tag:firefox-based-browser"

        # Some video sites should never have opacity applied to them
        "opacity 1.0 1.0, initialTitle:((?i)(?:[a-z0-9-]+\\.)*youtube\\.com_/|app\\.zoom\\.us_/wc/home)"

        # No transparency on media windows
        "opacity 1 1, class:^(zoom|vlc|mpv|org.kde.kdenlive|com.obsproject.Studio|com.github.PintaProject.Pinta|imv|org.gnome.NautilusPreviewer)$"

        # Floating windows - tag identification
        "tag +floating-window, class:(blueberry.py|Impala|Wiremix|org.gnome.NautilusPreviewer|com.gabm.satty|Omarchy|About|TUI.float)"
        "tag +floating-window, class:(xdg-desktop-portal-gtk|sublime_text|DesktopEditors|org.gnome.Nautilus), title:^(Open.*Files?|Open [F|f]older.*|Save.*Files?|Save.*As|Save|All Files)"

        # Floating window settings
        "float, tag:floating-window"
        "center, tag:floating-window"
        "size 800 600, tag:floating-window"

        # Fullscreen screensaver
        "fullscreen, class:Screensaver"

        # Picture-in-picture overlays
        "tag +pip, title:(Picture.{0,1}in.{0,1}[Pp]icture)"
        "float, tag:pip"
        "pin, tag:pip"
        "size 600 338, tag:pip"
        "keepaspectratio, tag:pip"
        "noborder, tag:pip"
        "opacity 1 1, tag:pip"
        "move 100%-w-40 4%, tag:pip"
      ];

      # Startup services
      "exec-once" = [
        # Waybar is now managed by systemd service (see programs.waybar.systemd.enable below)
        # Mako is now managed by services.mako (see below)
        "swayosd-server" # OSD server for volume/brightness overlays
        "wl-paste --type text --watch cliphist store" # Clipboard history for text
        "wl-paste --type image --watch cliphist store" # Clipboard history for images
        "${pkgs.swww}/bin/swww-daemon" # Wallpaper daemon
      ]
      ++ (if wallpaperPath != null then [ "${pkgs.swww}/bin/swww img ${wallpaperPath}" ] else [ ]);

      bind = [
        # Applications
        "$mod, RETURN, exec, spawn-terminal-here"
        "$mod SHIFT, F, exec, thunar" # File manager
        "$mod SHIFT, B, exec, google-chrome-stable"
        "$mod SHIFT ALT, B, exec, google-chrome-stable --incognito"
        "$mod SHIFT, M, exec, spotify"
        "$mod SHIFT, N, exec, alacritty -e nvim"
        "$mod SHIFT, T, exec, alacritty -e btop"
        "$mod SHIFT, D, exec, alacritty -e lazydocker"
        "$mod SHIFT, G, exec, signal-desktop"
        "$mod SHIFT, O, exec, obsidian"
        "$mod SHIFT, Y, exec, google-chrome-stable --new-window https://youtube.com"

        # Menus
        "$mod, SPACE, exec, walker"
        "$mod CTRL, E, exec, walker --modules emoji"
        "$mod, ESCAPE, exec, wlogout"
        "$mod, K, exec, show-keybindings" # Key bindings menu (Omarchy-style)
        "$mod SHIFT, SPACE, exec, toggle-waybar" # Toggle status bar (Omarchy-style)

        # Window Management
        "$mod, W, killactive,"
        "$mod, J, togglesplit,"
        "$mod, P, pseudo,"
        "$mod, T, togglefloating,"
        "$mod, F, fullscreen, 0"
        "$mod CTRL, F, fullscreen, 1"
        "$mod, left, movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up, movefocus, u"
        "$mod, down, movefocus, d"
        "$mod SHIFT, left, swapwindow, l"
        "$mod SHIFT, right, swapwindow, r"
        "$mod SHIFT, up, swapwindow, u"
        "$mod SHIFT, down, swapwindow, d"

        # Workspaces
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"
        "$mod, 0, workspace, 10"
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"
        "$mod SHIFT, 0, movetoworkspace, 10"
        "$mod, TAB, workspace, e+1"
        "$mod SHIFT, TAB, workspace, e-1"

        # Window Cycling
        "ALT, TAB, cyclenext,"
        "ALT SHIFT, TAB, cyclenext, prev"

        # Window Resizing
        "$mod, minus, resizeactive, -40 0"
        "$mod, equal, resizeactive, 40 0"
        "$mod SHIFT, minus, resizeactive, 0 -40"
        "$mod SHIFT, equal, resizeactive, 0 40"

        # Groups
        "$mod, G, togglegroup,"
        "$mod ALT, left, moveintogroup, l"
        "$mod ALT, right, moveintogroup, r"
        "$mod ALT, up, moveintogroup, u"
        "$mod ALT, down, moveintogroup, d"
        "$mod ALT, TAB, changegroupactive, f"
        "$mod ALT SHIFT, TAB, changegroupactive, b"

        # Clipboard history
        "$mod CTRL, V, exec, cliphist list | walker --dmenu | cliphist decode | wl-copy"

        # Background rotation (Omarchy-style)
        "$mod CTRL, SPACE, exec, rotate-background"

        # Theme picker (Omarchy-style)
        "$mod SHIFT CTRL, SPACE, exec, theme-picker"

        # Captures (screenshots) - Omarchy-style with hyprshot + satty
        ", PRINT, exec, screenshot-annotate region"
        "SHIFT, PRINT, exec, screenshot-annotate window"
        # macOS-style screenshots (direct save + clipboard, no annotation)
        "$mod CTRL SHIFT, 3, exec, screenshot-direct output"
        "$mod CTRL SHIFT, 4, exec, screenshot-direct region"
        "$mod CTRL SHIFT, 5, exec, screenshot-direct window"
        # Alternative screenshot keybindings with annotation (easier to find on K2 Keychron)
        "$mod, S, exec, screenshot-annotate region" # Super+S for region (with annotation)
        "$mod SHIFT, S, exec, screenshot-annotate window" # Super+Shift+S for window (with annotation)
        "$mod CTRL, S, exec, screenshot-annotate output" # Super+Ctrl+S for full screen (with annotation)

        # Screen recordings - Omarchy-style with wl-screenrec
        "ALT, PRINT, exec, screen-record region"
        "ALT SHIFT, PRINT, exec, screen-record region audio"
        "CTRL ALT, PRINT, exec, screen-record output"
        "CTRL ALT SHIFT, PRINT, exec, screen-record output audio"
        # Alternative screen recording keybindings (easier to find on K2 Keychron)
        "$mod, R, exec, screen-record region" # Super+R for region
        "$mod SHIFT, R, exec, screen-record region audio" # Super+Shift+R for region with audio
        "$mod CTRL, R, exec, screen-record output" # Super+Ctrl+R for full screen
        "$mod CTRL SHIFT, R, exec, screen-record output audio" # Super+Ctrl+Shift+R for full screen with audio

        # Notifications (mako is managed by services.mako)
        "$mod, comma, exec, makoctl dismiss"
        "$mod SHIFT, comma, exec, makoctl dismiss -a"
        "$mod CTRL, comma, exec, makoctl mode -t dnd"

        # Scroll workspace switching
        "$mod, mouse_down, workspace, e+1"
        "$mod, mouse_up, workspace, e-1"
      ];

      # Repeating bindings (for media keys with SwayOSD + audio feedback)
      binde = [
        ", XF86AudioRaiseVolume, exec, volume-feedback raise"
        ", XF86AudioLowerVolume, exec, volume-feedback lower"
        ", XF86MonBrightnessUp, exec, swayosd-client --brightness raise"
        ", XF86MonBrightnessDown, exec, swayosd-client --brightness lower"
      ];

      # Non-repeating media bindings
      bindl = [
        ", XF86AudioMute, exec, volume-feedback mute-toggle"
        ", XF86AudioMicMute, exec, swayosd-client --input-volume mute-toggle"
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioNext, exec, playerctl next"
        ", XF86AudioPrev, exec, playerctl previous"
      ];

      # Mouse bindings
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];

      # TODO: Enable gesture bindings when Hyprland is upgraded to 0.51+
      # Gesture bindings (3-finger swipes) for fullscreen toggle
      # These require Hyprland 0.51+ with the new gesture system
      # Current version: 0.49.0 - commenting out until upgrade
      # gesture = [
      #   "3, up, fullscreen" # Swipe up to toggle fullscreen
      #   "3, down, fullscreen" # Swipe down to toggle fullscreen
      # ];

      # Touchpad gestures (3-finger swipe)
      gestures = {
        workspace_swipe = true;
        workspace_swipe_fingers = 3;
        workspace_swipe_distance = 300; # Lower = less distance needed to switch
        workspace_swipe_cancel_ratio = 0.15; # Higher = easier to cancel swipe (default 0.5)
        workspace_swipe_min_speed_to_force = 30; # Minimum speed to force workspace change
        workspace_swipe_forever = true; # Continue swiping through multiple workspaces
      };

      # Input configuration (touchpad behavior)
      input = {
        touchpad = {
          natural_scroll = true; # Inverted scrolling (macOS-style)
          clickfinger_behavior = true; # Two-finger right-click
          disable_while_typing = true; # Prevent accidental taps
          tap-to-click = false; # Require click for selection
        };
      };
    };

    # Runtime theme switching support (Omarchy-style)
    # This allows switching themes without rebuilding NixOS
    # Source order: NixOS theme (above) → Runtime theme (below)
    # Runtime theme overrides NixOS theme when symlink exists
    extraConfig = ''
      # Source runtime theme if it exists (for theme-set command)
      source = ~/.config/omarchy/current/theme/hyprland.conf
    '';
  };

  # Walker configuration (Omarchy-style launcher)
  xdg.configFile."walker/config.toml".text = ''
    # Theme configuration
    theme = "omarchy-default"
    theme_base = []
    theme_location = ["~/.config/walker/themes/"]
    hotreload_theme = true

    # Basic behavior
    close_when_open = true
    force_keyboard_focus = true
    timeout = 60

    [search]
    placeholder = " Search..."

    [list]
    max_entries = 200
    cycle = true

    # Applications module
    [builtins.applications]
    refresh = true
    context_aware = true
    placeholder = " Search..."
    icon = ""
    hidden = true

    [builtins.applications.actions]
    enabled = false

    # Emoji module
    [builtins.emojis]
    name = "Emojis"
    icon = ""
    prefix = ":"
    exec = "wl-copy"

    # Clipboard module
    [builtins.clipboard]
    hidden = true
    exec = "wl-copy"
    max_entries = 10

    # Calculator
    [builtins.calc]
    name = "Calculator"
    icon = ""
    min_chars = 3
    prefix = "="

    # File finder
    [builtins.finder]
    use_fd = true
    icon = "file"
    name = "Finder"
    preview_images = true
    hidden = false
    prefix = "."

    # Windows switcher
    [builtins.windows]
    switcher_only = true
    hidden = true

    # Runner
    [builtins.runner]
    switcher_only = true
    hidden = true

    # Hidden modules
    [builtins.bookmarks]
    hidden = true

    [builtins.commands]
    hidden = true

    [builtins.custom_commands]
    hidden = true

    [builtins.ssh]
    hidden = true

    [builtins.websearch]
    switcher_only = true
    hidden = true

    [builtins.translation]
    hidden = true

    [builtins.symbols]
    hidden = true

    [builtins.hyprland_keybinds]
    path = "~/.config/hypr/hyprland.conf"
    hidden = true
  '';

  # Walker theme - base CSS (Omarchy-style)
  xdg.configFile."walker/themes/omarchy-default.css".text = ''
    /* Reset all elements */
    #window,
    #box,
    #search,
    #password,
    #input,
    #prompt,
    #clear,
    #typeahead,
    #list,
    child,
    scrollbar,
    slider,
    #item,
    #text,
    #label,
    #sub,
    #activationlabel {
      all: unset;
    }

    * {
      font-family: ${fontFamily};
      font-size: ${toString fontSizeLauncher}px;
    }

    /* Window */
    #window {
      background: transparent;
      color: @text;
    }

    /* Main box container */
    #box {
      background: alpha(@base, 0.95);
      padding: 20px;
      border: 2px solid @border;
      border-radius: 0px;
    }

    /* Search container */
    #search {
      background: @base;
      padding: 10px;
      margin-bottom: 0;
    }

    /* Hide prompt icon */
    #prompt {
      opacity: 0;
      min-width: 0;
      margin: 0;
    }

    /* Hide clear button */
    #clear {
      opacity: 0;
      min-width: 0;
    }

    /* Input field */
    #input {
      background: none;
      color: @text;
      padding: 0;
    }

    #input placeholder {
      opacity: 0.5;
      color: @text;
    }

    /* Hide typeahead */
    #typeahead {
      opacity: 0;
    }

    /* List */
    #list {
      background: transparent;
    }

    /* List items */
    child {
      padding: 0px 12px;
      background: transparent;
      border-radius: 0;
    }

    child:selected,
    child:hover {
      background: transparent;
    }

    /* Item layout */
    #item {
      padding: 0;
    }

    #item.active {
      font-style: italic;
    }

    /* Icon */
    #icon {
      margin-right: 10px;
      -gtk-icon-transform: scale(0.7);
    }

    /* Text */
    #text {
      color: @text;
      padding: 14px 0;
    }

    #label {
      font-weight: normal;
    }

    /* Selected state */
    child:selected #text,
    child:selected #label,
    child:hover #text,
    child:hover #label {
      color: @selected-text;
    }

    /* Hide sub text */
    #sub {
      opacity: 0;
      font-size: 0;
      min-height: 0;
    }

    /* Hide activation label */
    #activationlabel {
      opacity: 0;
      min-width: 0;
    }

    /* Scrollbar styling */
    scrollbar {
      opacity: 0;
    }

    /* Hide spinner */
    #spinner {
      opacity: 0;
    }

    /* Hide AI elements */
    #aiScroll,
    #aiList,
    .aiItem {
      opacity: 0;
      min-height: 0;
    }

    /* Bar entry (switcher) */
    #bar {
      opacity: 0;
      min-height: 0;
    }

    .barentry {
      opacity: 0;
    }

    /* Import runtime theme colors from symlink (must be last!) */
    @import url("file://${config.home.homeDirectory}/.config/omarchy/current/theme/walker.css");
  '';

  # Walker theme - Tokyo Night colors (separate file for proper CSS variable order)
  xdg.configFile."walker/themes/tokyo-night.css".text = ''
    @define-color selected-text ${themeConfig.walker.selectedText};
    @define-color text ${themeConfig.walker.text};
    @define-color base ${themeConfig.walker.base};
    @define-color border ${themeConfig.walker.border};
    @define-color foreground ${themeConfig.walker.foreground};
    @define-color background ${themeConfig.walker.background};
  '';

  # Walker theme - omarchy-default TOML (main launcher dimensions)
  xdg.configFile."walker/themes/omarchy-default.toml".text = ''
    [ui.window.box]
    width = 664
    min_width = 664
    max_width = 664
    height = 396
    min_height = 396
    max_height = 396

    # List constraints are critical - without these, the window shrinks when empty
    [ui.window.box.scroll.list]
    height = 300
    min_height = 300
    max_height = 300

    [ui.window.box.scroll.list.item.icon]
    pixel_size = 40
  '';

  # Walker theme - keybindings (larger for keybindings menu)
  xdg.configFile."walker/themes/keybindings.css".text = ''
    /* Import base CSS first - it will import tokyo-night.css at the end */
    @import url("file://${config.home.homeDirectory}/.config/walker/themes/omarchy-default.css");
  '';

  xdg.configFile."walker/themes/keybindings.toml".text = ''
    [ui.window.box]
    width = 964
    min_width = 964
    max_width = 964
    height = 664
    min_height = 664
    max_height = 664

    [ui.window.box.search]
    hide = false

    [ui.window.box.scroll]
    v_align = "fill"
    h_align = "fill"
    min_width = 964
    width = 964
    max_width = 964
    min_height = 664
    height = 664
    max_height = 664

    [ui.window.box.scroll.list]
    v_align = "fill"
    h_align = "fill"
    min_width = 900
    width = 900
    max_width = 900
    min_height = 600
    height = 600
    max_height = 600

    [ui.window.box.scroll.list.item]
    h_align = "fill"
    min_width = 900
    width = 900
    max_width = 900

    [ui.window.box.scroll.list.item.activation_label]
    hide = true

    [ui.window.box.scroll.list.placeholder]
    v_align = "start"
    h_align = "fill"
    hide = false
    min_width = 900
    width = 900
    max_width = 900
  '';

  # Custom scripts
  home.file.".local/bin/spawn-terminal-here" = {
    text = ''
      #!/usr/bin/env bash
      # Get the working directory of the currently focused window (Omarchy-style)
      # Get terminal PID from active window
      terminal_pid=$(${pkgs.hyprland}/bin/hyprctl activewindow -j | ${pkgs.jq}/bin/jq -r '.pid')

      # Get the shell PID (child process of terminal)
      shell_pid=$(${pkgs.procps}/bin/pgrep -P "$terminal_pid" | head -n1)

      if [[ -n "$shell_pid" ]] && [[ -d "/proc/$shell_pid/cwd" ]]; then
        WORK_DIR=$(readlink -f "/proc/$shell_pid/cwd" 2>/dev/null)
        ${pkgs.alacritty}/bin/alacritty --working-directory "$WORK_DIR"
      else
        ${pkgs.alacritty}/bin/alacritty
      fi
    '';
    executable = true;
  };

  home.file.".local/bin/volume-feedback" = {
    text = ''
      #!/usr/bin/env bash
      # Wrapper for SwayOSD with macOS-style audio feedback

      ACTION="$1"

      case "$ACTION" in
        raise)
          swayosd-client --output-volume raise
          # Play feedback sound at 50% volume to avoid being too loud
          paplay --volume=32768 /run/current-system/sw/share/sounds/freedesktop/stereo/audio-volume-change.oga 2>/dev/null &
          ;;
        lower)
          swayosd-client --output-volume lower
          paplay --volume=32768 /run/current-system/sw/share/sounds/freedesktop/stereo/audio-volume-change.oga 2>/dev/null &
          ;;
        mute-toggle)
          swayosd-client --output-volume mute-toggle
          ;;
        *)
          echo "Usage: volume-feedback {raise|lower|mute-toggle}"
          exit 1
          ;;
      esac
    '';
    executable = true;
  };

  # Keybindings viewer (Omarchy-style with Walker)
  home.file.".local/bin/show-keybindings" = {
    text = ''
      #!/usr/bin/env bash
      # Display Hyprland keybindings in Walker (Omarchy-style)

      # Fetch and parse keybindings from Hyprland
      hyprctl -j binds | \
        ${pkgs.jq}/bin/jq -r '.[] | "\(.modmask),\(.key)@\(.keycode),\(.description),\(.dispatcher),\(.arg)"' | \
        ${pkgs.gnused}/bin/sed -r \
            -e 's/null//' \
            -e 's/@0//' \
            -e 's/,@/,code:/' \
            -e 's/^0,/,/' \
            -e 's/^1,/SHIFT,/' \
            -e 's/^4,/CTRL,/' \
            -e 's/^5,/SHIFT CTRL,/' \
            -e 's/^8,/ALT,/' \
            -e 's/^9,/SHIFT ALT,/' \
            -e 's/^12,/CTRL ALT,/' \
            -e 's/^13,/SHIFT CTRL ALT,/' \
            -e 's/^64,/SUPER,/' \
            -e 's/^65,/SUPER SHIFT,/' \
            -e 's/^68,/SUPER CTRL,/' \
            -e 's/^69,/SUPER SHIFT CTRL,/' \
            -e 's/^72,/SUPER ALT,/' \
            -e 's/^73,/SUPER SHIFT ALT,/' \
            -e 's/^76,/SUPER CTRL ALT,/' \
            -e 's/^77,/SUPER SHIFT CTRL ALT,/' | \
        sort -u | \
        ${pkgs.gawk}/bin/awk -F, '
      {
          # Combine the modifier and key (first two fields)
          key_combo = $1 " + " $2;

          # Clean up: strip leading "+" if present, trim spaces
          gsub(/^[ \t]*\+?[ \t]*/, "", key_combo);
          gsub(/[ \t]+$/, "", key_combo);

          # Use description, if set
          action = $3;

          if (action == "") {
              # Reconstruct the command from the remaining fields
              for (i = 4; i <= NF; i++) {
                  action = action $i (i < NF ? "," : "");
              }

              # Clean up trailing commas, remove leading "exec, ", and trim
              sub(/,$/, "", action);
              gsub(/(^|,)[[:space:]]*exec[[:space:]]*,?/, "", action);
              gsub(/^[ \t]+|[ \t]+$/, "", action);
              gsub(/[ \t]+/, " ", key_combo);

              # Escape XML entities
              gsub(/&/, "\\&amp;", action);
              gsub(/</, "\\&lt;", action);
              gsub(/>/, "\\&gt;", action);
              gsub(/"/, "\\&quot;", action);
          }

          if (action != "") {
              printf "%-35s → %s\n", key_combo, action;
          }
      }' | \
        ${pkgs.walker}/bin/walker --dmenu --theme keybindings -p 'Keybindings'
    '';
    executable = true;
  };

  # Recording indicator for Waybar
  home.file.".local/bin/waybar-recording-indicator" = {
    text = ''
      #!/usr/bin/env bash
      # Check if screen recording is active (wf-recorder)

      if ${pkgs.procps}/bin/pgrep -x wf-recorder >/dev/null; then
        echo '{"text": "󰻂", "tooltip": "Stop recording", "class": "active"}'
      else
        echo '{"text": ""}'
      fi
    '';
    executable = true;
  };

  # Toggle Waybar visibility (Omarchy-style)
  home.file.".local/bin/toggle-waybar" = {
    text = ''
      #!/usr/bin/env bash
      # Toggle waybar visibility using systemd service

      if ${pkgs.systemd}/bin/systemctl --user is-active --quiet waybar.service; then
        ${pkgs.systemd}/bin/systemctl --user stop waybar.service
      else
        ${pkgs.systemd}/bin/systemctl --user start waybar.service
      fi
    '';
    executable = true;
  };

  # Theme picker (Omarchy-style)
  home.file.".local/bin/theme-picker" = {
    text = ''
      #!/usr/bin/env bash
      # Interactive theme picker using Walker (Omarchy-style)

      THEMES_DIR="${config.home.homeDirectory}/.config/omarchy/themes"
      CURRENT_THEME_LINK="${config.home.homeDirectory}/.config/omarchy/current/theme"

      # Get list of themes with proper formatting (Title Case with spaces)
      get_theme_list() {
        ${pkgs.findutils}/bin/find "$THEMES_DIR" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) 2>/dev/null | \
          ${pkgs.coreutils}/bin/sort | \
          while read -r path; do
            ${pkgs.coreutils}/bin/basename "$path" | \
              ${pkgs.gnused}/bin/sed -E 's/(^|-)([a-z])/\1\u\2/g; s/-/ /g'
          done
      }

      # Get current theme name with proper formatting
      get_current_theme() {
        if [[ -L "$CURRENT_THEME_LINK" ]]; then
          ${pkgs.coreutils}/bin/basename "$(${pkgs.coreutils}/bin/readlink "$CURRENT_THEME_LINK")" | \
            ${pkgs.gnused}/bin/sed -E 's/(^|-)([a-z])/\1\u\2/g; s/-/ /g'
        fi
      }

      # Check if themes directory exists
      if [[ ! -d "$THEMES_DIR" ]]; then
        ${pkgs.libnotify}/bin/notify-send "No themes found" "Run generate-themes first" -t 3000
        exit 1
      fi

      # Get theme list
      THEME_LIST=$(get_theme_list)
      if [[ -z "$THEME_LIST" ]]; then
        ${pkgs.libnotify}/bin/notify-send "No themes found" "Run generate-themes first" -t 3000
        exit 1
      fi

      # Get current theme for default selection
      CURRENT_THEME=$(get_current_theme)

      # Calculate the index of the current theme (0-based, Walker -a expects an index)
      CURRENT_INDEX=0
      if [[ -n "$CURRENT_THEME" ]]; then
        CURRENT_INDEX=$(echo "$THEME_LIST" | ${pkgs.coreutils}/bin/cat -n | \
          ${pkgs.gnugrep}/bin/grep -F "$CURRENT_THEME" | \
          ${pkgs.gawk}/bin/awk '{print $1-1}' || echo 0)
      fi

      # Show theme picker with Walker (suppress GTK warnings, -a expects index not name)
      SELECTED_THEME=$(echo "$THEME_LIST" | \
        ${pkgs.walker}/bin/walker --dmenu -p "Theme" -a "$CURRENT_INDEX" 2>/dev/null)

      # If selection was made (not cancelled), apply theme
      if [[ -n "$SELECTED_THEME" && "$SELECTED_THEME" != "CNCLD" ]]; then
        # Convert display name back to directory name (lowercase with dashes)
        THEME_NAME=$(echo "$SELECTED_THEME" | \
          ${pkgs.gnused}/bin/sed -E 's/ /-/g' | \
          ${pkgs.coreutils}/bin/tr '[:upper:]' '[:lower:]')

        # Apply theme using theme-set script
        if [[ -x "${config.home.homeDirectory}/.local/bin/theme-set" ]]; then
          ${config.home.homeDirectory}/.local/bin/theme-set "$THEME_NAME"
        else
          ${pkgs.libnotify}/bin/notify-send "Theme switcher not found" "theme-set script is missing" -t 3000
        fi
      fi
    '';
    executable = true;
  };

  # Screen recording (using wf-recorder for NVIDIA GPU compatibility)
  home.file.".local/bin/screen-record" = {
    text = ''
      #!/usr/bin/env bash
      # Screen recording using wf-recorder (better NVIDIA GPU support)

      OUTPUT_DIR="$HOME/Videos"
      SCOPE="''${1:-region}"  # region or output
      AUDIO="''${2:-}"        # "audio" or empty

      # Create Videos directory if it doesn't exist
      mkdir -p "$OUTPUT_DIR"

      start_screenrecording() {
        local filename="$OUTPUT_DIR/screenrecording-$(${pkgs.coreutils}/bin/date +'%Y-%m-%d_%H-%M-%S').mp4"
        local audio_flag=""

        if [[ "$AUDIO" == "audio" ]]; then
          audio_flag="--audio"
        fi

        # Use wf-recorder with libx264 software encoding
        # Note: wl-screenrec doesn't work with NVIDIA GPUs due to VAAPI issues
        ${pkgs.wf-recorder}/bin/wf-recorder $audio_flag -f "$filename" "$@" &

        # Update waybar indicator
        ${pkgs.procps}/bin/pkill -RTMIN+8 waybar 2>/dev/null || true
      }

      stop_screenrecording() {
        ${pkgs.procps}/bin/pkill -x wf-recorder

        ${pkgs.libnotify}/bin/notify-send "Screen recording saved to $OUTPUT_DIR" -t 3000 2>/dev/null || true

        sleep 0.2  # Ensure process is dead before checking
        # Update waybar indicator
        ${pkgs.procps}/bin/pkill -RTMIN+8 waybar 2>/dev/null || true
      }

      screenrecording_active() {
        ${pkgs.procps}/bin/pgrep -x wf-recorder >/dev/null
      }

      # Toggle recording
      if screenrecording_active; then
        stop_screenrecording
      elif [[ "$SCOPE" == "output" ]]; then
        # Full screen recording (no slurp needed)
        start_screenrecording
      else
        # Region selection with slurp
        region=$(${pkgs.slurp}/bin/slurp) || exit 1
        start_screenrecording -g "$region"
      fi
    '';
    executable = true;
  };

  # Direct screenshot (macOS-style: no annotation, save + clipboard)
  home.file.".local/bin/screenshot-direct" = {
    text = ''
      #!/usr/bin/env bash
      # Screenshot directly to file and clipboard (macOS-style, no annotation)

      OUTPUT_DIR="$HOME/Pictures"
      MODE="''${1:-region}"

      # Create Pictures directory if it doesn't exist
      mkdir -p "$OUTPUT_DIR"

      # Kill any running slurp instances (prevents conflicts)
      ${pkgs.procps}/bin/pkill slurp 2>/dev/null || true

      # Generate filename
      FILENAME="$OUTPUT_DIR/screenshot-$(${pkgs.coreutils}/bin/date +'%Y-%m-%d_%H-%M-%S').png"

      # Capture screenshot directly with hyprshot
      # For output mode, use active monitor to avoid cursor selector
      if [[ "$MODE" == "output" ]]; then
        ${pkgs.hyprshot}/bin/hyprshot -m active -m output -o "$OUTPUT_DIR" -f "$(${pkgs.coreutils}/bin/basename "$FILENAME")"
      else
        ${pkgs.hyprshot}/bin/hyprshot -m "$MODE" -o "$OUTPUT_DIR" -f "$(${pkgs.coreutils}/bin/basename "$FILENAME")"
      fi

      # Show notification if screenshot was saved successfully
      if [[ -f "$FILENAME" ]]; then
        # Copy to clipboard
        ${pkgs.wl-clipboard}/bin/wl-copy < "$FILENAME"

        # Extract just the filename for cleaner notification
        BASENAME=$(${pkgs.coreutils}/bin/basename "$FILENAME")
        ${pkgs.libnotify}/bin/notify-send \
          "Screenshot copied to clipboard" \
          "Saved to $OUTPUT_DIR/$BASENAME" \
          -t 3000 \
          -i "$FILENAME" \
          -u normal \
          2>/dev/null || true
      fi
    '';
    executable = true;
  };

  # Screenshot with annotation (Omarchy-style: hyprshot + satty)
  home.file.".local/bin/screenshot-annotate" = {
    text = ''
      #!/usr/bin/env bash
      # Screenshot with annotation using hyprshot and satty (Omarchy-style)

      OUTPUT_DIR="$HOME/Pictures"
      MODE="''${1:-region}"

      # Create Pictures directory if it doesn't exist
      mkdir -p "$OUTPUT_DIR"

      # Kill any running slurp instances (prevents conflicts)
      ${pkgs.procps}/bin/pkill slurp 2>/dev/null || true

      # Generate filename
      FILENAME="$OUTPUT_DIR/screenshot-$(${pkgs.coreutils}/bin/date +'%Y-%m-%d_%H-%M-%S').png"

      # Capture screenshot with hyprshot and pipe to satty for annotation
      # For output mode, use active monitor to avoid cursor selector
      if [[ "$MODE" == "output" ]]; then
        ${pkgs.hyprshot}/bin/hyprshot -m active -m output --raw | \
          ${pkgs.satty}/bin/satty --filename - \
            --output-filename "$FILENAME" \
            --early-exit \
            --action-on-enter save-to-clipboard \
            --save-after-copy \
            --copy-command '${pkgs.wl-clipboard}/bin/wl-copy'
        SATTY_EXIT=$?
      else
        ${pkgs.hyprshot}/bin/hyprshot -m "$MODE" --raw | \
          ${pkgs.satty}/bin/satty --filename - \
            --output-filename "$FILENAME" \
            --early-exit \
            --action-on-enter save-to-clipboard \
            --save-after-copy \
            --copy-command '${pkgs.wl-clipboard}/bin/wl-copy'
        SATTY_EXIT=$?
      fi

      # Show notification if screenshot was saved successfully (Omarchy-style)
      # Only notify if satty completed successfully and file exists
      if [[ $SATTY_EXIT -eq 0 ]] && [[ -f "$FILENAME" ]]; then
        # Extract just the filename for cleaner notification
        BASENAME=$(${pkgs.coreutils}/bin/basename "$FILENAME")
        ${pkgs.libnotify}/bin/notify-send \
          "Screenshot copied to clipboard" \
          "Saved to $OUTPUT_DIR/$BASENAME" \
          -t 3000 \
          -i "$FILENAME" \
          -u normal \
          2>/dev/null || true
      fi
    '';
    executable = true;
  };

  # Background rotation script (Omarchy-style)
  home.file.".local/bin/rotate-background" = {
    text = ''
      #!/usr/bin/env bash
      # Cycle through theme wallpapers using swww (Omarchy-style)

      WALLPAPERS_DIR="${config.home.homeDirectory}/.config/hyprland/current-theme-wallpapers"
      CURRENT_BG_FILE="${config.home.homeDirectory}/.config/hyprland/current-background"
      STATE_FILE="${config.home.homeDirectory}/.config/hyprland/background-index"

      # Check if wallpapers directory exists and has files
      if [[ ! -d "$WALLPAPERS_DIR" ]] || [[ -z "$(${pkgs.coreutils}/bin/ls -A "$WALLPAPERS_DIR")" ]]; then
        # No wallpapers available, use solid color
        ${pkgs.libnotify}/bin/notify-send "No backgrounds for this theme" "Using solid color" -t 2000 2>/dev/null || true
        ${pkgs.procps}/bin/pkill -x swww-daemon
        ${pkgs.swww}/bin/swww-daemon &
        sleep 0.5
        ${pkgs.swww}/bin/swww img --transition-type=none -o '*' --resize=crop -t 0 <(${pkgs.imagemagick}/bin/convert -size 1920x1080 xc:'#000000' png:-)
        exit 0
      fi

      # Get list of wallpapers (sorted)
      mapfile -t WALLPAPERS < <(${pkgs.findutils}/bin/find "$WALLPAPERS_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | ${pkgs.coreutils}/bin/sort)
      TOTAL=''${#WALLPAPERS[@]}

      if [[ $TOTAL -eq 0 ]]; then
        # No image files found, use solid color
        ${pkgs.libnotify}/bin/notify-send "No backgrounds for this theme" "Using solid color" -t 2000 2>/dev/null || true
        ${pkgs.procps}/bin/pkill -x swww-daemon
        ${pkgs.swww}/bin/swww-daemon &
        sleep 0.5
        ${pkgs.swww}/bin/swww img --transition-type=none -o '*' --resize=crop -t 0 <(${pkgs.imagemagick}/bin/convert -size 1920x1080 xc:'#000000' png:-)
        exit 0
      fi

      # Read current index from state file
      if [[ -f "$STATE_FILE" ]]; then
        CURRENT_INDEX=$(${pkgs.coreutils}/bin/cat "$STATE_FILE")
      else
        CURRENT_INDEX=0
      fi

      # Calculate next index (wrap around)
      NEXT_INDEX=$(( (CURRENT_INDEX + 1) % TOTAL ))
      NEXT_WALLPAPER="''${WALLPAPERS[$NEXT_INDEX]}"

      # Save new index
      echo "$NEXT_INDEX" > "$STATE_FILE"

      # Update current background symlink
      ${pkgs.coreutils}/bin/ln -sf "$NEXT_WALLPAPER" "$CURRENT_BG_FILE"

      # Apply wallpaper with swww
      ${pkgs.swww}/bin/swww img --transition-type=wipe --transition-angle=30 --transition-duration=1 "$NEXT_WALLPAPER"

      # Get wallpaper filename for notification
      WALLPAPER_NAME=$(${pkgs.coreutils}/bin/basename "$NEXT_WALLPAPER")
      ${pkgs.libnotify}/bin/notify-send "Background changed" "''${WALLPAPER_NAME}" -t 2000 2>/dev/null || true
    '';
    executable = true;
  };

  # GTK theme configuration (from selected theme)
  gtk = {
    enable = true;

    theme = {
      name = themeConfig.gtk.themeName;
      package = gtkThemePackage;
    };

    iconTheme = {
      name = themeConfig.gtk.iconName;
      package = iconThemePackage;
    };

    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
      gtk-font-name = "${fontFamily} ${toString fontSizeGtk}";
    };

    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
      gtk-font-name = "${fontFamily} ${toString fontSizeGtk}";
    };
  };

  # Cursor theme configuration
  home.pointerCursor = {
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 24;
    gtk.enable = true;
  };

  # Create wallpaper symlinks for current theme (Omarchy-style)
  # This allows the rotate-background script to find wallpapers
  home.activation.setupWallpaperSymlinks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    WALLPAPERS_SOURCE="${./wallpapers}/${selectedTheme}"
    WALLPAPERS_TARGET="${config.home.homeDirectory}/.config/hyprland/current-theme-wallpapers"

    # Create hyprland config directory if it doesn't exist
    mkdir -p "${config.home.homeDirectory}/.config/hyprland"

    # Remove old symlink if it exists
    rm -f "$WALLPAPERS_TARGET"

    # Create symlink to current theme wallpapers if they exist
    if [[ -d "$WALLPAPERS_SOURCE" ]]; then
      ln -sf "$WALLPAPERS_SOURCE" "$WALLPAPERS_TARGET"
      echo "Created wallpaper symlink: $WALLPAPERS_TARGET -> $WALLPAPERS_SOURCE"
    else
      echo "No wallpapers directory for theme ${selectedTheme}"
    fi
  '';

  # wlogout power menu configuration
  xdg.configFile."wlogout/layout".text = ''
    {
      "label" : "lock",
      "action" : "swaylock",
      "text" : "Lock",
      "keybind" : "l"
    }
    {
      "label" : "logout",
      "action" : "hyprctl dispatch exit",
      "text" : "Logout",
      "keybind" : "e"
    }
    {
      "label" : "shutdown",
      "action" : "systemctl poweroff",
      "text" : "Shutdown",
      "keybind" : "s"
    }
    {
      "label" : "reboot",
      "action" : "systemctl reboot",
      "text" : "Reboot",
      "keybind" : "r"
    }
  '';

  xdg.configFile."wlogout/style.css".text = ''
    /* Theme-integrated wlogout */
    * {
      background-image: none;
      font-family: ${fontFamily}, sans-serif;
      font-size: ${toString fontSizePowerMenu}px;
    }

    window {
      background-color: ${themeConfig.wlogout.backgroundColor};
    }

    button {
      color: ${themeConfig.wlogout.textColor};
      background-color: ${themeConfig.wlogout.buttonBackground};
      border-style: solid;
      border-width: 2px;
      border-color: ${themeConfig.wlogout.buttonBackground};
      background-repeat: no-repeat;
      background-position: center;
      background-size: 30%;
      border-radius: 12px;
      margin: 20px;
      padding: 20px;
      min-width: 180px;
      min-height: 180px;
      transition: all 0.3s ease;
    }

    button:focus, button:active, button:hover {
      background-color: ${themeConfig.wlogout.buttonHoverBackground};
      border-color: ${themeConfig.wlogout.buttonHoverBackground};
      color: ${themeConfig.wlogout.textHoverColor};
      outline-style: none;
      box-shadow: 0 4px 20px ${themeConfig.wlogout.buttonHoverBackground}4d;
      transform: scale(1.05);
    }

    #lock {
      background-image: image(url("/run/current-system/sw/share/wlogout/icons/lock.png"));
    }

    #logout {
      background-image: image(url("/run/current-system/sw/share/wlogout/icons/logout.png"));
    }

    #shutdown {
      background-image: image(url("/run/current-system/sw/share/wlogout/icons/shutdown.png"));
    }

    #reboot {
      background-image: image(url("/run/current-system/sw/share/wlogout/icons/reboot.png"));
    }
  '';

  # SwayOSD styling with runtime theme support (Omarchy-style)
  xdg.configFile."swayosd/style.css".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/omarchy/current/theme/swayosd.css";

  # hyprlock screen locker with runtime theme support (Omarchy-style)
  xdg.configFile."hypr/hyprlock.conf".text = ''
    # Source runtime theme colors (symlink updates without rebuild)
    source = ${config.home.homeDirectory}/.config/omarchy/current/theme/hyprlock.conf

    general {
      grace = 0
      hide_cursor = true
      no_fade_in = false
      no_fade_out = false
    }

    background {
      monitor =
      color = $color
      path = screenshot
      blur_passes = 3
      blur_size = 3
    }

    animations {
      enabled = false
    }

    input-field {
      monitor =
      size = 600, 100
      position = 0, 0
      halign = center
      valign = center

      inner_color = $inner_color
      outer_color = $outer_color
      outline_thickness = 4

      font_family = ${fontFamily}
      font_color = $font_color

      placeholder_text =   Enter Password 󰈷
      check_color = $check_color
      fail_text = <i>$PAMFAIL ($ATTEMPTS)</i>

      rounding = 0
      shadow_passes = 0
      fade_on_empty = false
    }

    auth {
      fingerprint:enabled = true
    }
  '';

  # VSCode theme configuration
  programs.vscode = {
    enable = true;
    profiles.default = {
      userSettings = {
        "workbench.colorTheme" = themeConfig.vscode.theme;
        "workbench.iconTheme" = "material-icon-theme";
        "terminal.integrated.fontFamily" = "'${fontFamily}'";
        "terminal.integrated.fontSize" = fontSize + 1;
        "editor.fontFamily" = "'${fontFamily}', 'monospace'";
        "editor.fontSize" = fontSize + 2;
        "editor.fontLigatures" = true;
        "editor.formatOnSave" = true;
        "editor.minimap.enabled" = true;
        "workbench.startupEditor" = "none";
      };
      extensions = with pkgs.vscode-extensions; [
        enkia.tokyo-night
        pkief.material-icon-theme
      ];
    };
  };

  # Alacritty terminal configuration
  programs.alacritty.enable = true;

  # Alacritty config with runtime theme import (Omarchy-style)
  xdg.configFile."alacritty/alacritty.toml".text = ''
    # Import runtime theme colors (symlink updates without rebuild)
    general.import = [ "${config.home.homeDirectory}/.config/omarchy/current/theme/alacritty.toml" ]

    [env]
    TERM = "xterm-256color"

    [window.padding]
    x = 10
    y = 10

    [window]
    decorations = "full"
    opacity = 0.95

    [font.normal]
    family = "${fontFamily}"
    style = "Regular"

    [font.bold]
    family = "${fontFamily}"
    style = "Bold"

    [font.italic]
    family = "${fontFamily}"
    style = "Italic"

    [font.bold_italic]
    family = "${fontFamily}"
    style = "Bold Italic"

    [font]
    size = ${toString (fontSize * 1.0)}

    [cursor]
    style = "Block"
    unfocused_hollow = true

    [selection]
    save_to_clipboard = true

    # SUPER+C for copy (Omarchy-style)
    [[keyboard.bindings]]
    key = "C"
    mods = "Super"
    action = "Copy"

    # SUPER+V for paste (Omarchy-style)
    [[keyboard.bindings]]
    key = "V"
    mods = "Super"
    action = "Paste"
  '';

  # Waybar configuration (Omarchy-style)
  programs.waybar = {
    enable = true;
    systemd.enable = true; # Manage waybar via systemd service for proper toggling

    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 34;
        spacing = 0;

        modules-left = [
          "hyprland/workspaces"
          "hyprland/window"
        ];
        modules-center = [
          "clock"
          "custom/recording"
        ];
        modules-right = [
          "tray"
          "bluetooth"
          "network"
          "pulseaudio"
          "cpu"
          "memory"
          "temperature"
          "battery"
        ];

        "hyprland/workspaces" = {
          on-click = "activate";
          format = "{icon}";
          format-icons = {
            "1" = "1";
            "2" = "2";
            "3" = "3";
            "4" = "4";
            "5" = "5";
            "6" = "6";
            "7" = "7";
            "8" = "8";
            "9" = "9";
            active = "󱓻";
            default = "";
          };
          persistent-workspaces = {
            "1" = [ ];
            "2" = [ ];
            "3" = [ ];
            "4" = [ ];
            "5" = [ ];
          };
        };

        clock = {
          format = "{:%A %H:%M}";
          format-alt = "{:%d %B W%V %Y}";
          tooltip = false;
        };

        "hyprland/window" = {
          max-length = 50;
          separate-outputs = true;
        };

        cpu = {
          interval = 5;
          format = "󰍛 {usage}%";
          on-click = "\${TERMINAL} -e btop";
        };

        memory = {
          format = " {}%";
          interval = 5;
        };

        temperature = {
          critical-threshold = 80;
          format = "{icon} {temperatureC}°C";
          format-icons = [
            ""
            ""
            ""
          ];
          interval = 5;
        };

        network = {
          format-icons = [
            "󰤯"
            "󰤟"
            "󰤢"
            "󰤥"
            "󰤨"
          ];
          format = "{icon}";
          format-wifi = "{icon}";
          format-ethernet = "󰀂";
          format-disconnected = "󰤮";
          tooltip-format-wifi = "{essid} ({frequency} GHz)\n⇣{bandwidthDownBytes}  ⇡{bandwidthUpBytes}";
          tooltip-format-ethernet = "⇣{bandwidthDownBytes}  ⇡{bandwidthUpBytes}";
          tooltip-format-disconnected = "Disconnected";
          interval = 3;
        };

        battery = {
          format = "{capacity}% {icon}";
          format-discharging = "{icon}";
          format-charging = "{icon}";
          format-plugged = "";
          format-icons = {
            charging = [
              "󰢜"
              "󰂆"
              "󰂇"
              "󰂈"
              "󰢝"
              "󰂉"
              "󰢞"
              "󰂊"
              "󰂋"
              "󰂅"
            ];
            default = [
              "󰁺"
              "󰁻"
              "󰁼"
              "󰁽"
              "󰁾"
              "󰁿"
              "󰂀"
              "󰂁"
              "󰂂"
              "󰁹"
            ];
          };
          format-full = "󰂅";
          tooltip-format-discharging = "{power:.1f}W↓ {capacity}%";
          tooltip-format-charging = "{power:.1f}W↑ {capacity}%";
          interval = 5;
          states = {
            warning = 20;
            critical = 10;
          };
        };

        "custom/recording" = {
          exec = "$HOME/.local/bin/waybar-recording-indicator";
          return-type = "json";
          interval = 2;
          signal = 8; # RTMIN+8 for real-time updates from screen-record script
          format = "{}";
        };

        bluetooth = {
          format = "";
          format-disabled = "󰂲";
          format-connected = "";
          tooltip-format = "Devices connected: {num_connections}";
          on-click = "blueberry";
        };

        pulseaudio = {
          format = "{icon}";
          on-click = "\${TERMINAL} --class=Wiremix -e wiremix";
          on-click-right = "pamixer -t";
          tooltip-format = "Playing at {volume}%";
          scroll-step = 5;
          format-muted = "";
          format-icons = {
            default = [
              ""
              ""
              ""
            ];
          };
        };

        tray = {
          icon-size = 12;
          spacing = 12;
        };
      };
    };

    style = ''
      /* Import runtime theme colors (Omarchy-style) */
      @import "${config.home.homeDirectory}/.config/omarchy/current/theme/waybar.css";

      * {
        border: none;
        border-radius: 0;
        font-family: "${fontFamily}";
        font-size: ${toString fontSizeStatusBar}px;
        min-height: 0;
      }

      window#waybar {
        background: @background;
        color: @foreground;
      }

      tooltip {
        background: @background;
        border: 1px solid @foreground;
        border-radius: 0;
        opacity: 0.95;
      }

      tooltip label {
        color: @foreground;
      }

      #workspaces button {
        padding: 0 8px;
        color: @foreground;
        background: transparent;
        border-bottom: 2px solid transparent;
        opacity: 0.5;
      }

      #workspaces button.active {
        color: @foreground;
        border-bottom: 2px solid @foreground;
        opacity: 1.0;
      }

      #workspaces button:hover {
        background: @foreground;
        color: @background;
        opacity: 0.1;
      }

      #window {
        padding: 0 15px;
        color: @foreground;
        font-weight: normal;
      }

      #clock,
      #cpu,
      #memory,
      #temperature,
      #network,
      #battery,
      #bluetooth,
      #pulseaudio,
      #tray {
        padding: 0 10px;
        color: @foreground;
      }

      #temperature.critical {
        color: #f38ba8;
      }

      #battery.warning {
        color: #f9e2af;
      }

      #battery.critical {
        color: #f38ba8;
      }

      #custom-recording {
        padding: 0 10px;
        color: #f38ba8;
      }

      #custom-recording.active {
        animation: blink 1s ease-in-out infinite;
      }

      @keyframes blink {
        0% {
          opacity: 1;
        }
        50% {
          opacity: 0.5;
        }
        100% {
          opacity: 1;
        }
      }
    '';
  };

  # Mako notification daemon with runtime theme support
  services.mako.enable = true;

  # Mako core configuration (Omarchy-style)
  xdg.configFile."mako/core.ini".text = ''
    # Base Mako settings (included by theme configs)
    font=${fontFamily} 11
    padding=15
    border-size=2
    border-radius=0
    max-icon-size=48
    default-timeout=5000
    ignore-timeout=0
    anchor=top-right
    margin=10
    group-by=app-name
    max-visible=5
    actions=1
    format=<b>%s</b>\n%b
  '';

  # Mako config symlink to runtime theme (Omarchy-style)
  xdg.configFile."mako/config".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/omarchy/current/theme/mako.ini";

  # tmux theme integration (override shell module's hardcoded colors)
  programs.tmux.extraConfig = lib.mkForce ''
    # Set default shell
    set-option -g default-shell "${pkgs.zsh}/bin/zsh"
    set-option -g default-command "${pkgs.zsh}/bin/zsh"

    # Enable true colors
    set-option -ga terminal-overrides ",*256col*:Tc"
    set-option -ga terminal-overrides ",alacritty:Tc"

    # Mouse support
    set -g mouse on

    # Status bar (theme-integrated)
    set -g status-position top
    set -g status-style 'bg=${themeConfig.tmux.statusBackground} fg=${themeConfig.tmux.statusForeground}'
    set -g status-left '#[fg=${themeConfig.tmux.windowStatusCurrent},bold]#S #[fg=${themeConfig.tmux.statusForeground}]• '
    set -g status-right '#[fg=${themeConfig.tmux.statusForeground}]#(whoami)@#h • %Y-%m-%d %H:%M'
    set -g status-left-length 50
    set -g status-right-length 50

    # Window status (theme-integrated)
    setw -g window-status-current-style 'fg=${themeConfig.tmux.statusBackground} bg=${themeConfig.tmux.windowStatusCurrent} bold'
    setw -g window-status-current-format ' #I:#W#F '
    setw -g window-status-style 'fg=${themeConfig.tmux.statusForeground}'
    setw -g window-status-format ' #I:#W#F '

    # Pane borders (theme-integrated)
    set -g pane-border-style 'fg=${themeConfig.tmux.paneInactiveBorder}'
    set -g pane-active-border-style 'fg=${themeConfig.tmux.paneActiveBorder}'

    # Message style (theme-integrated)
    set -g message-style 'fg=${themeConfig.tmux.messageForeground} bg=${themeConfig.tmux.messageBackground} bold'

    # Copy mode (theme-integrated)
    setw -g mode-style 'fg=${themeConfig.tmux.statusBackground} bg=${themeConfig.tmux.windowStatusCurrent} bold'

    # Window/pane management
    bind | split-window -h -c "#{pane_current_path}"
    bind - split-window -v -c "#{pane_current_path}"
    bind c new-window -c "#{pane_current_path}"

    # Resize panes with vim keys
    bind -r H resize-pane -L 5
    bind -r J resize-pane -D 5
    bind -r K resize-pane -U 5
    bind -r L resize-pane -R 5

    # Quick window selection
    bind -r C-h select-window -t :-
    bind -r C-l select-window -t :+

    # Reload config
    bind r source-file ~/.config/tmux/tmux.conf \; display-message "Config reloaded!"

    # Copy mode vi bindings
    bind-key -T copy-mode-vi v send-keys -X begin-selection
    bind-key -T copy-mode-vi C-v send-keys -X rectangle-toggle
    bind-key -T copy-mode-vi Escape send-keys -X cancel

    # Platform-specific clipboard integration
    ${
      if pkgs.stdenv.isDarwin then
        ''
          bind-key -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "pbcopy"
          bind-key -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "pbcopy"
          bind-key -T copy-mode-vi Enter send-keys -X copy-pipe-and-cancel "pbcopy"
        ''
      else
        ''
          bind-key -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "xclip -selection clipboard"
          bind-key -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "xclip -selection clipboard"
          bind-key -T copy-mode-vi Enter send-keys -X copy-pipe-and-cancel "xclip -selection clipboard"
        ''
    }

    # Activity monitoring
    setw -g monitor-activity on
    set -g visual-activity off

    # Auto-rename windows
    setw -g automatic-rename on
    set -g set-titles on
    set -g set-titles-string '#h ❐ #S ● #I #W'

    # Plugin configurations
    set -g @resurrect-capture-pane-contents 'on'
    set -g @continuum-restore 'on'
    set -g @continuum-boot 'on'
    set -g @prefix_highlight_show_copy_mode 'on'
    set -g @prefix_highlight_copy_mode_attr 'fg=black,bg=yellow,bold'
  '';

  # btop system monitor (theme-integrated)
  xdg.configFile."btop/themes/current.theme".text =
    let
      # Helper function to generate theme property lines
      themeProp = name: value: ''theme[${name}]="${value}"'';

      # Generate all theme properties
      props = [
        (themeProp "main_bg" themeConfig.btop.main_bg)
        (themeProp "main_fg" themeConfig.btop.main_fg)
        (themeProp "title" themeConfig.btop.title)
        (themeProp "hi_fg" themeConfig.btop.hi_fg)
        (themeProp "selected_bg" themeConfig.btop.selected_bg)
        (themeProp "selected_fg" themeConfig.btop.selected_fg)
        (themeProp "inactive_fg" themeConfig.btop.inactive_fg)
      ]
      ++ lib.optional (themeConfig.btop ? graph_text) (themeProp "graph_text" themeConfig.btop.graph_text)
      ++ lib.optional (themeConfig.btop ? meter_bg) (themeProp "meter_bg" themeConfig.btop.meter_bg)
      ++ [
        (themeProp "proc_misc" themeConfig.btop.proc_misc)
        (themeProp "cpu_box" themeConfig.btop.cpu_box)
        (themeProp "mem_box" themeConfig.btop.mem_box)
        (themeProp "net_box" themeConfig.btop.net_box)
        (themeProp "proc_box" themeConfig.btop.proc_box)
        (themeProp "div_line" themeConfig.btop.div_line)
        (themeProp "temp_start" themeConfig.btop.temp_start)
        (themeProp "temp_mid" themeConfig.btop.temp_mid)
        (themeProp "temp_end" themeConfig.btop.temp_end)
        (themeProp "cpu_start" themeConfig.btop.cpu_start)
        (themeProp "cpu_mid" themeConfig.btop.cpu_mid)
        (themeProp "cpu_end" themeConfig.btop.cpu_end)
        (themeProp "free_start" themeConfig.btop.free_start)
        (themeProp "free_mid" themeConfig.btop.free_mid)
        (themeProp "free_end" themeConfig.btop.free_end)
        (themeProp "cached_start" themeConfig.btop.cached_start)
        (themeProp "cached_mid" themeConfig.btop.cached_mid)
        (themeProp "cached_end" themeConfig.btop.cached_end)
        (themeProp "available_start" themeConfig.btop.available_start)
        (themeProp "available_mid" themeConfig.btop.available_mid)
        (themeProp "available_end" themeConfig.btop.available_end)
        (themeProp "used_start" themeConfig.btop.used_start)
        (themeProp "used_mid" themeConfig.btop.used_mid)
        (themeProp "used_end" themeConfig.btop.used_end)
        (themeProp "download_start" themeConfig.btop.download_start)
        (themeProp "download_mid" themeConfig.btop.download_mid)
        (themeProp "download_end" themeConfig.btop.download_end)
        (themeProp "upload_start" themeConfig.btop.upload_start)
        (themeProp "upload_mid" themeConfig.btop.upload_mid)
        (themeProp "upload_end" themeConfig.btop.upload_end)
      ]
      ++ lib.optionals (themeConfig.btop ? process_start) [
        (themeProp "process_start" themeConfig.btop.process_start)
        (themeProp "process_mid" themeConfig.btop.process_mid)
        (themeProp "process_end" themeConfig.btop.process_end)
      ];
    in
    ''
      # Theme: ${themeConfig.displayName}
      # Generated by NixOS Home Manager

      ${lib.concatStringsSep "\n" props}
    '';

  xdg.configFile."btop/btop.conf".text = ''
    # btop config - theme-integrated

    # Use dynamically generated theme
    color_theme = "current"

    # Omarchy-style settings
    theme_background = True
    truecolor = True
    force_tty = False
    rounded_corners = False
    graph_symbol = "braille"

    # Update interval
    update_ms = 2000

    # Process settings
    proc_sorting = "cpu lazy"
    proc_reversed = False
    proc_tree = False
    proc_colors = True
    proc_gradient = True
    proc_per_core = False
    proc_mem_bytes = True
    proc_cpu_graphs = True
    proc_left = False

    # CPU settings
    cpu_graph_upper = "Auto"
    cpu_graph_lower = "Auto"
    show_gpu_info = "Auto"
    cpu_invert_lower = True
    cpu_single_graph = False
    cpu_bottom = False
    show_uptime = True
    check_temp = True
    cpu_sensor = "Auto"
    show_coretemp = True
    show_cpu_freq = True

    # Temperature scale
    temp_scale = "celsius"

    # Clock format
    clock_format = "%X"

    # Memory settings
    mem_graphs = True
    mem_below_net = False
    show_swap = True
    swap_disk = True
    show_disks = True
    only_physical = True
    use_fstab = True
    show_io_stat = True
    io_mode = False

    # Network settings
    net_download = 100
    net_upload = 100
    net_auto = True
    net_sync = True

    # Battery
    show_battery = True
    selected_battery = "Auto"

    # Logging
    log_level = "WARNING"
  '';

  # eza (modern ls) theme integration
  xdg.configFile."eza/theme.yml".text =
    let
      # Helper function to generate YAML color entry
      colorEntry = name: color: "  ${name}: {foreground: \"${color}\"}";

      # Generate YAML sections
      filekindsList = lib.mapAttrsToList colorEntry themeConfig.eza.filekinds;
      permsList = lib.mapAttrsToList colorEntry themeConfig.eza.perms;
      sizeList = lib.mapAttrsToList colorEntry themeConfig.eza.size;
      usersList = lib.mapAttrsToList colorEntry themeConfig.eza.users;
      linksList = lib.mapAttrsToList colorEntry themeConfig.eza.links;
      gitList = lib.mapAttrsToList colorEntry themeConfig.eza.git;
      gitRepoList = lib.mapAttrsToList colorEntry themeConfig.eza.git_repo;
      securityContextList = lib.mapAttrsToList colorEntry themeConfig.eza.security_context;
      fileTypeList = lib.mapAttrsToList colorEntry themeConfig.eza.file_type;
    in
    ''
      # Theme: ${themeConfig.displayName}
      # Generated by NixOS Home Manager

      colourful: true

      filekinds:
      ${lib.concatStringsSep "\n" filekindsList}

      perms:
      ${lib.concatStringsSep "\n" permsList}

      size:
      ${lib.concatStringsSep "\n" sizeList}

      users:
      ${lib.concatStringsSep "\n" usersList}

      links:
      ${lib.concatStringsSep "\n" linksList}

      git:
      ${lib.concatStringsSep "\n" gitList}

      git_repo:
      ${lib.concatStringsSep "\n" gitRepoList}

      security_context:
      ${lib.concatStringsSep "\n" securityContextList}

      file_type:
      ${lib.concatStringsSep "\n" fileTypeList}

      punctuation: {foreground: "${themeConfig.eza.punctuation}"}
      date: {foreground: "${themeConfig.eza.date}"}
      inode: {foreground: "${themeConfig.eza.inode}"}
      blocks: {foreground: "${themeConfig.eza.blocks}"}
      header: {foreground: "${themeConfig.eza.header}"}
      octal: {foreground: "${themeConfig.eza.octal}"}
      flags: {foreground: "${themeConfig.eza.flags}"}

      symlink_path: {foreground: "${themeConfig.eza.symlink_path}"}
      control_char: {foreground: "${themeConfig.eza.control_char}"}
      broken_symlink: {foreground: "${themeConfig.eza.broken_symlink}"}
      broken_path_overlay: {foreground: "${themeConfig.eza.broken_path_overlay}"}
    '';

  # Fastfetch system info (theme-integrated)
  xdg.configFile."fastfetch/config.jsonc".text = builtins.toJSON {
    "$schema" = "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json";
    logo = {
      type = "small";
      padding = {
        top = 1;
        right = 2;
        left = 1;
      };
    };
    modules = [
      "break"
      {
        type = "title";
        keyColor = themeConfig.fastfetch.keyColor;
      }
      {
        type = "separator";
      }
      {
        type = "os";
        key = "OS";
        keyColor = themeConfig.fastfetch.keyColor;
      }
      {
        type = "host";
        key = "Host";
        keyColor = themeConfig.fastfetch.keyColor;
      }
      {
        type = "kernel";
        key = "Kernel";
        keyColor = themeConfig.fastfetch.keyColor;
      }
      {
        type = "uptime";
        key = "Uptime";
        keyColor = themeConfig.fastfetch.keyColor;
      }
      {
        type = "packages";
        key = "Packages";
        keyColor = themeConfig.fastfetch.keyColor;
      }
      {
        type = "shell";
        key = "Shell";
        keyColor = themeConfig.fastfetch.keyColor;
      }
      {
        type = "de";
        key = "DE";
        keyColor = themeConfig.fastfetch.keyColor;
      }
      {
        type = "wm";
        key = "WM";
        keyColor = themeConfig.fastfetch.keyColor;
      }
      {
        type = "terminal";
        key = "Terminal";
        keyColor = themeConfig.fastfetch.keyColor;
      }
      {
        type = "cpu";
        key = "CPU";
        keyColor = themeConfig.fastfetch.keyColor;
      }
      {
        type = "gpu";
        key = "GPU";
        keyColor = themeConfig.fastfetch.keyColor;
      }
      {
        type = "memory";
        key = "Memory";
        keyColor = themeConfig.fastfetch.keyColor;
      }
      {
        type = "disk";
        key = "Disk";
        keyColor = themeConfig.fastfetch.keyColor;
      }
      "break"
      {
        type = "colors";
        paddingLeft = 2;
        symbol = "circle";
      }
    ];
  };
}
