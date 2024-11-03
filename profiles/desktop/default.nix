# Desktop-specific packages
{ pkgs, ... }:

{
  imports = [
    ../../modules/system/default-packages.nix
  ];

  environment.systemPackages = with pkgs; [
    # GUI applications
    alacritty
    chromium
    gimp
    blender
    vscode
    slack
    
    # Desktop utilities
    gnome.gnome-remote-desktop
    gnome.gnome-session
    
    # Fonts
    fira-code-nerdfont
    nerdfonts
  ];
} 