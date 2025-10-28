{
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ../../modules/ssh-keys.nix
    ../../modules/nfs-mounts.nix
    ../../modules/local-hosts.nix
  ];

  # Hyprland desktop environment
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # Default Hyprland configuration
  environment.etc."hypr/hyprland.conf".text = ''
    # Monitor configuration
    monitor=,preferred,auto,1

    # Execute apps at launch
    exec-once = waybar
    exec-once = mako

    # Set terminal
    $terminal = kitty
    $mainMod = SUPER

    # Key bindings
    bind = $mainMod, RETURN, exec, $terminal
    bind = $mainMod, Q, killactive,
    bind = $mainMod, M, exit,
    bind = $mainMod, E, exec, thunar
    bind = $mainMod, F, togglefloating,
    bind = $mainMod, D, exec, rofi -show drun
    bind = $mainMod, J, togglesplit, # Toggle window split direction

    # Screenshot bindings (macOS-style) - saves to ~/Pictures and copies to clipboard
    bind = SUPER CTRL SHIFT, 3, exec, grim - | tee ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png | wl-copy
    bind = SUPER CTRL SHIFT, 4, exec, grim -g "$(slurp)" - | tee ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png | wl-copy
    bind = SUPER CTRL SHIFT, 5, exec, grim -g "$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')" - | tee ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png | wl-copy

    # Move focus
    bind = $mainMod, left, movefocus, l
    bind = $mainMod, right, movefocus, r
    bind = $mainMod, up, movefocus, u
    bind = $mainMod, down, movefocus, d

    # Switch workspaces
    bind = $mainMod, 1, workspace, 1
    bind = $mainMod, 2, workspace, 2
    bind = $mainMod, 3, workspace, 3
    bind = $mainMod, 4, workspace, 4
    bind = $mainMod, 5, workspace, 5
    bind = $mainMod, 6, workspace, 6
    bind = $mainMod, 7, workspace, 7
    bind = $mainMod, 8, workspace, 8
    bind = $mainMod, 9, workspace, 9
    bind = $mainMod, 0, workspace, 10

    # Move window to workspace
    bind = $mainMod SHIFT, 1, movetoworkspace, 1
    bind = $mainMod SHIFT, 2, movetoworkspace, 2
    bind = $mainMod SHIFT, 3, movetoworkspace, 3
    bind = $mainMod SHIFT, 4, movetoworkspace, 4
    bind = $mainMod SHIFT, 5, movetoworkspace, 5
    bind = $mainMod SHIFT, 6, movetoworkspace, 6
    bind = $mainMod SHIFT, 7, movetoworkspace, 7
    bind = $mainMod SHIFT, 8, movetoworkspace, 8
    bind = $mainMod SHIFT, 9, movetoworkspace, 9
    bind = $mainMod SHIFT, 0, movetoworkspace, 10

    # Mouse bindings
    bindm = $mainMod, mouse:272, movewindow
    bindm = $mainMod, mouse:273, resizewindow

    # General settings
    general {
        gaps_in = 5
        gaps_out = 10
        border_size = 2
        col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
        col.inactive_border = rgba(595959aa)
        layout = dwindle
    }

    # Decoration
    decoration {
        rounding = 8
        blur {
            enabled = true
            size = 3
            passes = 1
        }
        drop_shadow = true
        shadow_range = 4
    }

    # Input configuration
    input {
        kb_layout = us
        follow_mouse = 1
        touchpad {
            natural_scroll = true
        }
    }

    # Animations
    animations {
        enabled = true
        bezier = myBezier, 0.05, 0.9, 0.1, 1.05
        animation = windows, 1, 7, myBezier
        animation = windowsOut, 1, 7, default, popin 80%
        animation = fade, 1, 7, default
        animation = workspaces, 1, 6, default
    }

    # Layout
    dwindle {
        pseudotile = true
        preserve_split = true
    }
  '';

  # Enable zsh as default shell
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
  };

  # Set zsh as default shell
  users.defaultUserShell = pkgs.zsh;

  # Essential services for Wayland/Hyprland
  services = {
    # Display manager - SDDM works well with Hyprland
    displayManager.sddm = {
      enable = true;
      wayland.enable = true;
      theme = "sddm-astronaut-theme";
      package = pkgs.kdePackages.sddm.override {
        extraPackages = with pkgs.kdePackages; [
          qtmultimedia
          qt5compat
        ];
      };
    };

    # GNOME Keyring for application secrets (Signal, etc.)
    gnome.gnome-keyring.enable = true;

    # Pipewire for audio
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };

    # Enable dbus
    dbus.enable = true;

    # Printing support
    printing.enable = true;

    # Tailscale VPN
    tailscale.enable = true;
  };

  # XDG portal for screen sharing and file pickers
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
    config.common.default = "*";
  };

  # Security and session management
  security = {
    polkit.enable = true;
    rtkit.enable = true;
    pam.services.sddm.enableGnomeKeyring = true;
  };

  # Essential system packages for Hyprland
  environment.systemPackages = with pkgs; [
    # Keyring and secrets management
    gnome-keyring
    libsecret # For applications using libsecret API
    seahorse # GUI for managing keyrings

    # Hyprland utilities
    hyprpaper # Wallpaper daemon
    hyprlock # Screen locker
    hypridle # Idle management
    hyprpicker # Color picker
    hyprshot # Screenshot tool

    # Wayland utilities
    wl-clipboard # Clipboard manager
    wlr-randr # Display configuration
    wayland-utils # Wayland info tools
    xwayland # X11 compatibility
    cliphist # Clipboard history manager

    # Session management and power
    wlogout # Power menu (logout/shutdown/reboot)
    swaylock-effects # Enhanced screen locker with effects

    # Wallpaper management
    swww # Animated wallpaper daemon (alternative to hyprpaper)

    # Application launcher and bar
    unstablePkgs.walker # Wayland-native application launcher 0.13.26 (Omarchy-style)
    waybar # Status bar
    mako # Notification daemon

    # Terminal
    alacritty # Terminal emulator
    kitty # Alternative terminal

    # File manager
    xfce.thunar # Lightweight file manager
    xfce.thunar-volman # Volume management
    xfce.thunar-archive-plugin # Archive support
    gvfs # Virtual filesystem support (USB, MTP, etc.)
    udisks2 # Disk management
    udiskie # Auto-mount removable media

    # Network management
    networkmanagerapplet # Network manager GUI

    # Audio control
    pavucontrol # PulseAudio volume control
    pamixer # CLI audio mixer
    swayosd # OSD for volume/brightness/caps lock
    sound-theme-freedesktop # System sound effects for volume feedback
    pulseaudio # Provides paplay command for playing sounds

    # Brightness control
    brightnessctl # Screen brightness
    light # Alternative brightness control

    # Media control
    playerctl # Media player control (for keybindings)

    # Screenshots and screen recording
    grim # Screenshot tool
    slurp # Region selector
    swappy # Screenshot editor
    satty # Screenshot annotation tool (Omarchy-style)
    wf-recorder # Screen recorder
    jq # JSON processor for window info
    libnotify # Desktop notifications (notify-send command)
    imagemagick # Image manipulation (for fallback solid color backgrounds)

    # Session management
    polkit_gnome # Polkit authentication agent

    # Applications
    chromium # Web browser
    firefox # Alternative browser
    vscode # Code editor
    gimp # Image editor
    blender # 3D modeling
    inkscape-with-extensions # Vector graphics
    vlc # Media player
    slack # Team communication
    bitwarden # Password manager

    # Fonts
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono

    # System monitoring
    btop # System monitor
    htop # Process viewer

    # Theme and appearance - Qt support
    qt5.qtwayland # Qt Wayland support
    qt6.qtwayland # Qt6 Wayland support
    libsForQt5.qt5ct # Qt5 configuration
    libsForQt5.qtstyleplugin-kvantum # Qt theming

    # GTK themes
    gnome-themes-extra # GNOME default themes
    tokyonight-gtk-theme # Tokyo Night theme
    catppuccin-gtk # Catppuccin pastel themes
    gruvbox-gtk-theme # Gruvbox retro theme
    arc-theme # Flat transparent theme
    nordic # Nord-based GTK theme
    orchis-theme # Material Design theme
    graphite-gtk-theme # Modern dark theme

    # SDDM themes
    sddm-astronaut # Modern Qt6 SDDM theme

    # Icon themes
    papirus-icon-theme # Papirus icons (default)
    numix-icon-theme # Numix icons
    tela-icon-theme # Tela icons
    candy-icons # Candy icons

    # Cursor themes
    bibata-cursors # Bibata cursor theme
    nordzy-cursor-theme # Nord cursor theme
    catppuccin-cursors # Catppuccin cursors
  ];

  # Environment variables for Wayland
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1"; # Enable Wayland for Electron apps
    MOZ_ENABLE_WAYLAND = "1"; # Enable Wayland for Firefox
    QT_QPA_PLATFORM = "wayland";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    QT_QPA_PLATFORMTHEME = "qt5ct"; # Use qt5ct for Qt theming
    SDL_VIDEODRIVER = "wayland";
    XDG_SESSION_TYPE = "wayland";
    _JAVA_AWT_WM_NONREPARENTING = "1";
    # GTK theme environment - Tokyo Night
    GTK_THEME = "Tokyonight-Dark";
    XCURSOR_THEME = "Bibata-Modern-Classic";
    XCURSOR_SIZE = "24";
  };

  # Default GTK settings - Tokyo Night theme
  environment.etc."xdg/gtk-3.0/settings.ini".text = ''
    [Settings]
    gtk-theme-name=Tokyonight-Dark
    gtk-icon-theme-name=Papirus-Dark
    gtk-font-name=Sans 10
    gtk-cursor-theme-name=Bibata-Modern-Classic
    gtk-cursor-theme-size=24
    gtk-toolbar-style=GTK_TOOLBAR_BOTH_HORIZ
    gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
    gtk-button-images=1
    gtk-menu-images=1
    gtk-enable-event-sounds=1
    gtk-enable-input-feedback-sounds=0
    gtk-xft-antialias=1
    gtk-xft-hinting=1
    gtk-xft-hintstyle=hintslight
    gtk-xft-rgba=rgb
    gtk-application-prefer-dark-theme=1
  '';

  environment.etc."xdg/gtk-4.0/settings.ini".text = ''
    [Settings]
    gtk-theme-name=Tokyonight-Dark
    gtk-icon-theme-name=Papirus-Dark
    gtk-font-name=Sans 10
    gtk-cursor-theme-name=Bibata-Modern-Classic
    gtk-cursor-theme-size=24
    gtk-xft-antialias=1
    gtk-xft-hinting=1
    gtk-xft-hintstyle=hintslight
    gtk-xft-rgba=rgb
    gtk-application-prefer-dark-theme=1
  '';

  # Enable OpenGL
  hardware.graphics.enable = true;

  # Fonts configuration
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-emoji
      liberation_ttf
      fira-code
      fira-code-symbols
      nerd-fonts.fira-code
      nerd-fonts.jetbrains-mono
    ];

    fontconfig = {
      defaultFonts = {
        serif = [ "Noto Serif" ];
        sansSerif = [ "Noto Sans" ];
        monospace = [ "FiraCode Nerd Font" ];
        emoji = [ "Noto Color Emoji" ];
      };
    };
  };

  # Enable sound with pipewire
  services.pulseaudio.enable = false;

  # Bluetooth support
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
        Experimental = true;
      };
    };
  };
  services.blueman.enable = true;

  # Auto-mount removable media
  services.udisks2.enable = true;
  services.gvfs.enable = true;

  # Enable thumbnails in file managers
  services.tumbler.enable = true;

  # Waybar now configured in Home Manager (modules/home-manager/hyprland/default.nix)
}
