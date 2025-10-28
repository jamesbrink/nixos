# Kanagawa theme
{
  name = "kanagawa";
  displayName = "Kanagawa";

  # GTK/Icon theme package names (resolved by main module)
  gtk = {
    themeName = "Kanagawa-BL";
    themePackage = "kanagawa-gtk-theme";
    iconName = "Papirus-Dark";
    iconPackage = "papirus-icon-theme";
  };

  # Hyprland colors
  hyprland = {
    activeBorder = "rgb(dcd7ba)";
    inactiveBorder = "rgba(727169aa)";
  };

  # Alacritty color scheme
  alacritty = {
    primary = {
      background = "#1f1f28";
      foreground = "#dcd7ba";
    };
    normal = {
      black = "#090618";
      red = "#c34043";
      green = "#76946a";
      yellow = "#c0a36e";
      blue = "#7e9cd8";
      magenta = "#957fb8";
      cyan = "#6a9589";
      white = "#c8c093";
    };
    bright = {
      black = "#727169";
      red = "#e82424";
      green = "#98bb6c";
      yellow = "#e6c384";
      blue = "#7fb4ca";
      magenta = "#938aa9";
      cyan = "#7aa89f";
      white = "#dcd7ba";
    };
    indexed_colors = [
      {
        index = 16;
        color = "#ffa066";
      }
      {
        index = 17;
        color = "#ff5d62";
      }
    ];
  };

  # VSCode theme name
  vscode = {
    theme = "Kanagawa";
  };

  # Walker launcher colors
  walker = {
    selectedText = "#dca561";
    text = "#dcd7ba";
    base = "#1f1f28";
    border = "#dcd7ba";
    foreground = "#dcd7ba";
    background = "#1f1f28";
  };

  # Waybar colors
  waybar = {
    foreground = "#dcd7ba";
    background = "#1f1f28";
  };

  # wlogout power menu colors
  wlogout = {
    backgroundColor = "#1f1f28";
    buttonBackground = "#2a2a37";
    buttonHoverBackground = "#7e9cd8";
    textColor = "#dcd7ba";
    textHoverColor = "#1f1f28";
  };

  # tmux status bar colors
  tmux = {
    statusBackground = "#1f1f28";
    statusForeground = "#dcd7ba";
    windowStatusCurrent = "#7e9cd8";
    paneActiveBorder = "#7e9cd8";
    paneInactiveBorder = "#727169";
    messageBackground = "#7e9cd8";
    messageForeground = "#1f1f28";
  };

  # Mako notification colors
  mako = {
    textColor = "#dcd7ba";
    borderColor = "#dcd7ba";
    backgroundColor = "#1f1f28";
    progressColor = "#dcd7ba";
  };

  # SwayOSD colors
  swayosd = {
    backgroundColor = "#1f1f28";
    borderColor = "#dcd7ba";
    textColor = "#dcd7ba";
  };

  # Hyprlock colors
  hyprlock = {
    general = "#1f1f28";
    input = "#1f1f28";
    innerColor = "#1f1f28cc";
    outerColor = "#dcd7ba";
    fontColor = "#dcd7ba";
    checkColor = "#7e9cd8";
    failColor = "#e82424";
  };

  # Wallpapers (none specified for now)
  wallpapers = [ ];
}
