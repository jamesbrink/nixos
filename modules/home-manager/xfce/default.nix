# XFCE home-manager configuration - Tokyo Night theme
{
  config,
  pkgs,
  lib,
  ...
}:

{
  # GTK theme settings for XFCE
  gtk = {
    enable = true;
    theme = {
      name = "Tokyonight-Dark";
      package = pkgs.tokyonight-gtk-theme;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    cursorTheme = {
      name = "Bibata-Modern-Classic";
      package = pkgs.bibata-cursors;
    };
    font = {
      name = "Sans";
      size = 10;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
  };

  # Qt theme to match GTK
  qt = {
    enable = true;
    platformTheme.name = "gtk";
  };

  # XFCE configuration via activation scripts
  # Note: home-manager doesn't have native xfconf support, so we use activation scripts
  home.activation.configureXfce = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # Run xfconf-query commands to configure XFCE
    run_xfconf() {
      if command -v ${pkgs.xfce.xfconf}/bin/xfconf-query >/dev/null 2>&1; then
        ${pkgs.xfce.xfconf}/bin/xfconf-query "$@" 2>/dev/null || true
      fi
    }

    # GTK/Theme settings
    run_xfconf -c xsettings -p /Net/ThemeName -s "Tokyonight-Dark"
    run_xfconf -c xsettings -p /Net/IconThemeName -s "Papirus-Dark"
    run_xfconf -c xsettings -p /Gtk/CursorThemeName -s "Bibata-Modern-Classic"
    run_xfconf -c xsettings -p /Gtk/CursorThemeSize -s 24
    run_xfconf -c xsettings -p /Gtk/FontName -s "Sans 10"
    run_xfconf -c xsettings -p /Net/EnableEventSounds -s false
    run_xfconf -c xsettings -p /Net/EnableInputFeedbackSounds -s false

    # Window Manager (xfwm4) settings
    run_xfconf -c xfwm4 -p /general/theme -s "Tokyonight-Dark"
    run_xfconf -c xfwm4 -p /general/title_font -s "Sans Bold 10"
    run_xfconf -c xfwm4 -p /general/show_dock_shadow -t bool -s true
    run_xfconf -c xfwm4 -p /general/show_frame_shadow -t bool -s true
    run_xfconf -c xfwm4 -p /general/show_popup_shadow -t bool -s true

    # Desktop background settings
    run_xfconf -c xfce4-desktop -p /backdrop/screen0/monitorVirtual1/workspace0/color-style -t int -s 0
    run_xfconf -c xfce4-desktop -p /backdrop/screen0/monitorVirtual1/workspace0/image-style -t int -s 5

    # Panel settings
    run_xfconf -c xfce4-panel -p /panels/dark-mode -t bool -s true

    # Keyboard shortcuts for Alacritty
    run_xfconf -c xfce4-keyboard-shortcuts -p "/commands/custom/<Super>Return" -s "alacritty"
    run_xfconf -c xfce4-keyboard-shortcuts -p "/commands/custom/<Primary><Alt>t" -s "alacritty"

    # Session settings
    run_xfconf -c xfce4-session -p /startup/ssh-agent/enabled -t bool -s true
    run_xfconf -c xfce4-session -p /compat/LaunchGNOME -t bool -s false
  '';

  # Session variables
  home.sessionVariables = {
    GTK_THEME = "Tokyonight-Dark";
    XCURSOR_THEME = "Bibata-Modern-Classic";
    XCURSOR_SIZE = "24";
  };

  # Picom autostart for compositor effects
  home.file.".config/autostart/picom.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Picom
    Comment=X11 compositor
    Exec=picom
    Terminal=false
    StartupNotify=false
    Hidden=false
  '';

  # XFCE autostart to apply theme
  home.file.".config/autostart/xfce-theme.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Apply XFCE Theme
    Exec=${pkgs.xfce.xfconf}/bin/xfconf-query -c xsettings -p /Net/ThemeName -s Tokyonight-Dark
    Terminal=false
    StartupNotify=false
    Hidden=false
  '';
}
