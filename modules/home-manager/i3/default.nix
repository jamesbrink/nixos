# i3 window manager home-manager configuration
# Provides Alacritty terminal and other desktop utilities for i3 users
{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ../alacritty # Alacritty terminal with Tokyo Night theme
    ./polybar.nix # Modern status bar with icons
    ./rofi.nix # Application launcher with Tokyo Night theme
    ./dunst.nix # Notification daemon with Tokyo Night theme
  ];

  home.packages = with pkgs; [
    # Icon theme for rofi and polybar
    papirus-icon-theme

    # Screenshot and clipboard utilities
    maim # Alternative screenshot tool
    xclip # X11 clipboard tool

    # Wallpaper tools
    nitrogen # GUI wallpaper setter (alternative to feh)
  ];

  # Set default terminal for applications
  home.sessionVariables = {
    TERMINAL = "alacritty";
  };

  # GTK theme settings for consistent appearance
  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    font = {
      name = "Sans";
      size = 10;
    };
  };

  # Disable dconf to avoid service dependency issues on i3
  dconf.enable = false;

  # Qt theme settings for consistency
  qt = {
    enable = true;
    platformTheme.name = "gtk";
  };
}
