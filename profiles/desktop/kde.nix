{ pkgs, inputs, ... }:

{
  # KDE Plasma desktop environment
  # Uses Wayland by default (Plasma 6 has excellent Wayland support)

  imports = [
    ../../modules/ssh-keys.nix
    ../../modules/nfs-mounts.nix
    ../../modules/local-hosts.nix
  ];

  # Ensure session desktop files are linked to the system profile
  environment.pathsToLink = [
    "/share/xsessions"
    "/share/wayland-sessions"
  ];

  # Desktop applications and utilities
  environment.systemPackages = with pkgs; [
    # Core applications
    alacritty
    chromium
    firefox
    vscode
    gimp
    slack
    bitwarden-desktop
    # KDE utilities
    kdePackages.kate
    kdePackages.konsole
    kdePackages.dolphin
    kdePackages.ark
    kdePackages.spectacle
    kdePackages.gwenview
    kdePackages.okular
    kdePackages.kcalc
    # Remote desktop
    unstablePkgs.rustdesk
    # Fonts
    nerd-fonts.fira-code
    # Networking
    tailscale
  ];

  services = {
    # XRDP for Windows Remote Desktop Protocol support
    xrdp = {
      enable = true;
      defaultWindowManager = "startplasma-x11";
      openFirewall = true;
    };

    # X Server
    xserver = {
      enable = true;

      xkb = {
        layout = "us";
        variant = "";
      };
    };

    # Display manager - SDDM (KDE's default)
    displayManager.sddm = {
      enable = true;
      wayland.enable = true;
    };

    # KDE Plasma desktop
    desktopManager.plasma6.enable = true;

    printing.enable = true;
  };

  # Enable Wayland support for Plasma
  programs.dconf.enable = true;

  # XDG portal for Flatpak/sandboxed apps
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde ];
  };
}
