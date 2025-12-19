{ pkgs, inputs, ... }:

{
  # GNOME desktop environment with Wayland, XRDP, and gnome-remote-desktop
  # Uses Wayland by default (modern GNOME 49+ works best with Wayland)
  # Remote access: XRDP for RDP protocol, gnome-remote-desktop for native GNOME

  imports = [
    ../../modules/ssh-keys.nix
    ../../modules/nfs-mounts.nix
    ../../modules/local-hosts.nix
  ];

  # Remote desktop access options:
  # - XRDP: Windows RDP protocol support (enabled below)
  # - gnome-remote-desktop: Native GNOME Wayland remote desktop (package installed)
  # Note: RustDesk system service disabled for Wayland (requires user session access)

  # Ensure session desktop files are linked to the system profile
  # GDM looks for sessions in /run/current-system/sw/share/xsessions
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
    # GNOME utilities
    gnome-flashback
    gnome-session
    gnome-remote-desktop
    # Remote desktop (RustDesk available for manual use)
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
      defaultWindowManager = "${pkgs.gnome-session}/bin/gnome-session";
      openFirewall = true;
    };

    # X Server with GNOME
    xserver = {
      enable = true;

      xkb = {
        layout = "us";
        variant = "";
      };
    };

    # Display and desktop managers (moved out of xserver)
    displayManager.gdm = {
      enable = true;
      wayland = true; # Use Wayland - modern GNOME works best with it
    };

    desktopManager.gnome.enable = true;

    printing.enable = true;
  };
}
