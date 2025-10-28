# Catppuccin Macchiato theme
{
  name = "catppuccin";
  displayName = "Catppuccin Macchiato";

  # GTK/Icon theme package names
  gtk = {
    themeName = "Catppuccin-Macchiato-Standard-Blue-Dark";
    themePackage = "catppuccin-gtk";
    themeOverride = ''accents = [ "blue" ]; variant = "macchiato";'';
    iconName = "Papirus-Dark";
    iconPackage = "papirus-icon-theme";
  };

  # Hyprland colors
  hyprland = {
    activeBorder = "rgb(c6d0f5)";
    inactiveBorder = "rgba(595959aa)";
  };

  # Alacritty color scheme
  alacritty = {
    primary = {
      background = "#24273a";
      foreground = "#cad3f5";
    };
    normal = {
      black = "#494d64";
      red = "#ed8796";
      green = "#a6da95";
      yellow = "#eed49f";
      blue = "#8aadf4";
      magenta = "#f5bde6";
      cyan = "#8bd5ca";
      white = "#b8c0e0";
    };
    bright = {
      black = "#5b6078";
      red = "#ed8796";
      green = "#a6da95";
      yellow = "#eed49f";
      blue = "#8aadf4";
      magenta = "#f5bde6";
      cyan = "#8bd5ca";
      white = "#a5adcb";
    };
    indexed_colors = [
      {
        index = 16;
        color = "#f5a97f";
      }
      {
        index = 17;
        color = "#f4dbd6";
      }
    ];
  };

  # VSCode theme name
  vscode = {
    theme = "Catppuccin Macchiato";
  };

  # Walker launcher colors
  walker = {
    selectedText = "#8caaee";
    text = "#c6d0f5";
    base = "#24273a";
    border = "#c6d0f5";
    foreground = "#c6d0f5";
    background = "#24273a";
  };

  # Waybar colors
  waybar = {
    foreground = "#c6d0f5";
    background = "#24273a";
  };

  # wlogout power menu colors
  wlogout = {
    backgroundColor = "#24273a";
    buttonBackground = "#363a4f";
    buttonHoverBackground = "#8aadf4";
    textColor = "#cad3f5";
    textHoverColor = "#24273a";
  };

  # tmux status bar colors
  tmux = {
    statusBackground = "#24273a";
    statusForeground = "#cad3f5";
    windowStatusCurrent = "#8aadf4";
    paneActiveBorder = "#8aadf4";
    paneInactiveBorder = "#5b6078";
    messageBackground = "#8aadf4";
    messageForeground = "#24273a";
  };

  # Mako notification colors
  mako = {
    textColor = "#cad3f5";
    borderColor = "#c6d0f5";
    backgroundColor = "#24273a";
    progressColor = "#cad3f5";
  };

  # SwayOSD colors
  swayosd = {
    backgroundColor = "#24273a";
    borderColor = "#c6d0f5";
    textColor = "#cad3f5";
  };

  # Hyprlock colors
  hyprlock = {
    general = "#181824";
    input = "#181824";
    innerColor = "#181824cc";
    outerColor = "#cdd6f4";
    fontColor = "#cdd6f4";
    checkColor = "#449dab";
    failColor = "#ed8796";
  };

  # Wallpapers
  wallpapers = [
    "1-catppuccin.png"
    "2-cat-waves-mocha.png"
    "3-cat-blue-eye-mocha.png"
  ];
}
