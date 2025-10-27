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
    };

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
  };

  # Essential system packages for Hyprland
  environment.systemPackages = with pkgs; [
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

    # Application launcher and bar
    rofi-wayland # Application launcher
    waybar # Status bar
    dunst # Notification daemon

    # Terminal
    alacritty # Terminal emulator
    kitty # Alternative terminal

    # File manager
    xfce.thunar # Lightweight file manager
    xfce.thunar-volman # Volume management
    xfce.thunar-archive-plugin # Archive support

    # Network management
    networkmanagerapplet # Network manager GUI

    # Audio control
    pavucontrol # PulseAudio volume control
    pamixer # CLI audio mixer

    # Brightness control
    brightnessctl # Screen brightness
    light # Alternative brightness control

    # Screenshots and screen recording
    grim # Screenshot tool
    slurp # Region selector
    swappy # Screenshot editor
    wf-recorder # Screen recorder

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

    # Theme and appearance
    qt5.qtwayland # Qt Wayland support
    qt6.qtwayland # Qt6 Wayland support
    libsForQt5.qt5ct # Qt5 configuration
    libsForQt5.qtstyleplugin-kvantum # Qt theming
    gnome-themes-extra # GTK themes
    papirus-icon-theme # Icon theme
  ];

  # Environment variables for Wayland
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1"; # Enable Wayland for Electron apps
    MOZ_ENABLE_WAYLAND = "1"; # Enable Wayland for Firefox
    QT_QPA_PLATFORM = "wayland";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    SDL_VIDEODRIVER = "wayland";
    XDG_SESSION_TYPE = "wayland";
    _JAVA_AWT_WM_NONREPARENTING = "1";
  };

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
  hardware.pulseaudio.enable = false;

  # Bluetooth support (optional, remove if not needed)
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;
}
