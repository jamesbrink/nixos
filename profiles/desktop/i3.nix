{
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ../../modules/ssh-keys.nix
    ../../modules/nfs-mounts.nix
    ../../modules/aws-root-config.nix
    ../../modules/rustdesk-client.nix
    ../../users/root.nix
  ];

  # Enable zsh as default shell
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
  };

  # Set zsh as default shell
  users.defaultUserShell = pkgs.zsh;

  environment.systemPackages = with pkgs; [
    # Core desktop applications
    alacritty # Primary terminal (matching Hyprland)
    chromium
    bitwarden
    vscode

    # Media applications
    gimp
    inkscape-with-extensions
    vlc

    # i3 utilities and tools
    dmenu # Fallback application launcher
    rofi # Primary application launcher (matching Hyprland workflow)
    rofi-power-menu # Power menu for rofi
    i3status # Status bar
    i3lock # Screen locker
    i3blocks # Alternative status bar
    dunst # Notification daemon
    picom # Compositor for transparency and effects
    feh # Image viewer and wallpaper setter
    scrot # Screenshot tool (matching Hyprland screenshot bindings)
    arandr # GUI for xrandr (monitor configuration)
    pavucontrol # PulseAudio volume control
    pasystray # PulseAudio system tray
    networkmanagerapplet # Network manager system tray
    playerctl # Media player control (for media keys)
    brightnessctl # Brightness control (for laptop/monitor)

    # File manager
    xfce.thunar
    xfce.thunar-volman
    xfce.thunar-archive-plugin
    xfce.xfce4-terminal # Backup terminal
    xfce.xfce4-taskmanager # Task manager

    # System monitoring
    btop # System monitor (matching Hyprland)

    # Remote desktop (RustDesk installed via rustdesk-client module)
    rustdesk-flutter

    # Fonts (matching Hyprland)
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
  ];

  # PolicyKit rules to allow LightDM to access accounts-daemon
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.DisplayManager.AccountsService.ReadAny" ||
          action.id == "org.freedesktop.DisplayManager.AccountsService.WriteAny") {
        return polkit.Result.YES;
      }
    });
  '';

  services = {
    # Accounts daemon required for LightDM user management
    accounts-daemon.enable = true;

    # XRDP for Windows Remote Desktop Protocol access
    xrdp = {
      enable = true;
      defaultWindowManager = "${pkgs.i3}/bin/i3";
      openFirewall = true;
    };

    # Compositor for transparency and effects
    picom = {
      enable = true;
      fade = true;
      fadeDelta = 4;
      fadeSteps = [
        0.03
        0.03
      ];

      shadow = true;
      shadowOpacity = 0.75;
      shadowOffsets = [
        (-15)
        (-15)
      ];

      activeOpacity = 1.0;
      inactiveOpacity = 0.95;

      backend = "glx";
      vSync = true;

      settings = {
        # Rounded corners
        corner-radius = 8;
        rounded-corners-exclude = [
          "window_type = 'dock'"
          "window_type = 'desktop'"
          "class_g = 'Polybar'"
        ];

        # Blur
        blur = {
          method = "dual_kawase";
          strength = 5;
          background = false;
          background-frame = false;
          background-fixed = false;
        };

        blur-background-exclude = [
          "window_type = 'dock'"
          "window_type = 'desktop'"
          "class_g = 'slop'"
          "_GTK_FRAME_EXTENTS@:c"
        ];

        # Shadows
        shadow-radius = 15;
        shadow-exclude = [
          "window_type = 'dock'"
          "window_type = 'desktop'"
          "class_g = 'Polybar'"
          "_GTK_FRAME_EXTENTS@:c"
        ];

        # Fading
        fading = true;
        fade-in-step = 0.03;
        fade-out-step = 0.03;
        fade-delta = 4;

        # Transparency / Opacity
        active-opacity = 1.0;
        inactive-opacity = 0.95;
        frame-opacity = 1.0;
        inactive-opacity-override = false;

        # Focus
        mark-wmwin-focused = true;
        mark-ovredir-focused = true;
        detect-client-opacity = true;
        use-ewmh-active-win = true;

        # Other
        detect-transient = true;
        detect-client-leader = true;
        glx-no-stencil = true;
        glx-no-rebind-pixmap = true;
        use-damage = true;

        # Window type settings
        wintypes = {
          tooltip = {
            fade = true;
            shadow = false;
            opacity = 0.95;
            focus = true;
          };
          dock = {
            shadow = false;
          };
          dnd = {
            shadow = false;
          };
          popup_menu = {
            opacity = 0.95;
          };
          dropdown_menu = {
            opacity = 0.95;
          };
        };
      };
    };

    # X11 server configuration
    xserver = {
      enable = true;

      xkb = {
        layout = "us";
        variant = "";
      };

      # LightDM display manager (works well with i3, XRDP, and RustDesk)
      displayManager = {
        lightdm.enable = true;
        defaultSession = "none+i3";
      };

      # i3 window manager
      windowManager.i3 = {
        enable = true;
        configFile = ../../modules/home-manager/i3/config;
        extraPackages = with pkgs; [
          dmenu
          i3status
          i3lock
          i3blocks
        ];
      };
    };

    printing.enable = true;
  };
}
