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
  fontSize = 12;

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

      # Startup services
      "exec-once" = [
        "waybar" # Status bar
        "mako" # Notification daemon
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
        "$mod SHIFT, B, exec, firefox"
        "$mod SHIFT ALT, B, exec, firefox --private-window"
        "$mod SHIFT, M, exec, spotify"
        "$mod SHIFT, N, exec, alacritty -e nvim"
        "$mod SHIFT, T, exec, alacritty -e btop"
        "$mod SHIFT, D, exec, alacritty -e lazydocker"
        "$mod SHIFT, G, exec, signal-desktop"
        "$mod SHIFT, O, exec, obsidian"
        "$mod SHIFT, Y, exec, firefox --new-window https://youtube.com"

        # Menus
        "$mod, SPACE, exec, walker"
        "$mod CTRL, E, exec, walker --modules emoji"
        "$mod, ESCAPE, exec, wlogout"
        "$mod, K, exec, show-keybindings" # Key bindings menu (Omarchy-style)

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

        # Captures (screenshots)
        ", PRINT, exec, grim -g \"$(slurp)\" - | swappy -f -"
        "SHIFT, PRINT, exec, grim -g \"$(slurp)\" - | wl-copy"
        "$mod CTRL SHIFT, 3, exec, grim ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png"
        "$mod CTRL SHIFT, 4, exec, grim -g \"$(slurp)\" ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png"

        # Notifications (mako is installed in desktop profile)
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
    };
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
      font-size: 18px;
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

    /* Import theme-specific colors from external file (must be last!) */
    @import url("file://${config.home.homeDirectory}/.config/walker/themes/tokyo-night.css");
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
      gtk-font-name = "${fontFamily} 10";
    };

    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
      gtk-font-name = "${fontFamily} 10";
    };
  };

  # Cursor theme configuration
  home.pointerCursor = {
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 24;
    gtk.enable = true;
  };

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
    /* Tokyo Night themed wlogout */
    * {
      background-image: none;
      font-family: "JetBrainsMono Nerd Font", sans-serif;
      font-size: 16px;
    }

    window {
      background-color: rgba(26, 27, 38, 0.95);
    }

    button {
      color: #c0caf5;
      background-color: #1f2335;
      border-style: solid;
      border-width: 2px;
      border-color: #414868;
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
      background-color: #24283b;
      border-color: #7aa2f7;
      color: #7aa2f7;
      outline-style: none;
      box-shadow: 0 4px 20px rgba(122, 162, 247, 0.3);
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

    #lock:hover {
      border-color: #e0af68;
      color: #e0af68;
      box-shadow: 0 4px 20px rgba(224, 175, 104, 0.3);
    }

    #logout:hover {
      border-color: #f7768e;
      color: #f7768e;
      box-shadow: 0 4px 20px rgba(247, 118, 142, 0.3);
    }

    #shutdown:hover {
      border-color: #f7768e;
      color: #f7768e;
      box-shadow: 0 4px 20px rgba(247, 118, 142, 0.3);
    }

    #reboot:hover {
      border-color: #9ece6a;
      color: #9ece6a;
      box-shadow: 0 4px 20px rgba(158, 206, 106, 0.3);
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
  programs.alacritty = {
    enable = true;
    settings = lib.mkForce {
      env = {
        TERM = "xterm-256color";
      };

      window = {
        padding = {
          x = 10;
          y = 10;
        };
        decorations = "full";
        opacity = 0.95;
      };

      font = {
        normal = {
          family = fontFamily;
          style = "Regular";
        };
        bold = {
          family = fontFamily;
          style = "Bold";
        };
        italic = {
          family = fontFamily;
          style = "Italic";
        };
        bold_italic = {
          family = fontFamily;
          style = "Bold Italic";
        };
        size = fontSize * 1.0;
      };

      # Theme-based color scheme
      colors = {
        primary = themeConfig.alacritty.primary;
        normal = themeConfig.alacritty.normal;
        bright = themeConfig.alacritty.bright;
        indexed_colors = themeConfig.alacritty.indexed_colors;
      };

      cursor = {
        style = "Block";
        unfocused_hollow = true;
      };

      selection = {
        save_to_clipboard = true;
      };

      keyboard.bindings = [
        # SUPER+C for copy (same as Ctrl+Shift+C)
        {
          key = "C";
          mods = "Super";
          action = "Copy";
        }
        # SUPER+V for paste (same as Ctrl+Shift+V)
        {
          key = "V";
          mods = "Super";
          action = "Paste";
        }
      ];
    };
  };
}
