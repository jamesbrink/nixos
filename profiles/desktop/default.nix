# Desktop-specific packages
{ pkgs, ... }:

{
  # 1. Desktop Environment Packages
  environment.systemPackages = with pkgs; [
    # Terminal Emulators
    alacritty

    # Web Browsers
    chromium

    # Development Tools
    vscode

    # Creative Tools
    gimp
    blender

    # Communication
    slack

    # Desktop Environment
    gnome-remote-desktop
    gnome-session

    # Fonts
    fira-code-nerdfont
    nerdfonts
  ];

  # 2. Desktop Services Configuration
  services = {
    # Remote Desktop
    xrdp = {
      enable = true;
      defaultWindowManager = "${pkgs.gnome-session}/bin/gnome-session";
    };

    # X Server Configuration
    xserver = {
      enable = true;

      # Keyboard Layout
      xkb = {
        layout = "us";
        variant = "";
      };

      # Display Manager
      displayManager = {
        gdm.enable = true;
      };

      # Desktop Environment
      desktopManager.gnome.enable = true;
    };

    # Printing Support
    printing.enable = true;
  };
}
