{ pkgs, inputs, ... }:

{
  # GNOME desktop environment with X11, XRDP, and RustDesk support
  # Optimized for remote access with Windows RDP and RustDesk compatibility

  imports = [
    ../../modules/ssh-keys.nix
    ../../modules/nfs-mounts.nix
    ../../modules/local-hosts.nix
    ../../modules/rustdesk-client.nix
  ];

  environment.systemPackages = with pkgs; [
    alacritty
    chromium
    firefox
    vscode
    gimp
    slack
    gnome-remote-desktop
    gnome-session
    bitwarden-desktop
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
      wayland = false; # Disable Wayland to ensure X11 session (required for RustDesk)
    };

    desktopManager.gnome.enable = true;

    printing.enable = true;
  };
}
