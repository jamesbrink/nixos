# Everforest theme
{
  name = "everforest";
  displayName = "Everforest";

  # GTK/Icon theme package names (resolved by main module)
  gtk = {
    themeName = "Everforest-Dark";
    themePackage = "everforest-gtk-theme";
    iconName = "Papirus-Dark";
    iconPackage = "papirus-icon-theme";
  };

  # Hyprland colors
  hyprland = {
    activeBorder = "rgb(d3c6aa)";
    inactiveBorder = "rgba(475258aa)";
  };

  # Alacritty color scheme
  alacritty = {
    primary = {
      background = "#2d353b";
      foreground = "#d3c6aa";
    };
    normal = {
      black = "#475258";
      red = "#e67e80";
      green = "#a7c080";
      yellow = "#dbbc7f";
      blue = "#7fbbb3";
      magenta = "#d699b6";
      cyan = "#83c092";
      white = "#d3c6aa";
    };
    bright = {
      black = "#475258";
      red = "#e67e80";
      green = "#a7c080";
      yellow = "#dbbc7f";
      blue = "#7fbbb3";
      magenta = "#d699b6";
      cyan = "#83c092";
      white = "#d3c6aa";
    };
    indexed_colors = [ ];
  };

  # VSCode theme name
  vscode = {
    theme = "Everforest Dark";
  };

  # Walker launcher colors
  walker = {
    selectedText = "#dbbc7f";
    text = "#d3c6aa";
    base = "#2d353b";
    border = "#d3c6aa";
    foreground = "#d3c6aa";
    background = "#2d353b";
  };

  # Waybar colors
  waybar = {
    foreground = "#d3c6aa";
    background = "#2d353b";
  };

  # wlogout power menu colors
  wlogout = {
    backgroundColor = "#2d353b";
    buttonBackground = "#343f44";
    buttonHoverBackground = "#a7c080";
    textColor = "#d3c6aa";
    textHoverColor = "#2d353b";
  };

  # tmux status bar colors
  tmux = {
    statusBackground = "#2d353b";
    statusForeground = "#d3c6aa";
    windowStatusCurrent = "#a7c080";
    paneActiveBorder = "#a7c080";
    paneInactiveBorder = "#475258";
    messageBackground = "#a7c080";
    messageForeground = "#2d353b";
  };

  # Mako notification colors
  mako = {
    textColor = "#d3c6aa";
    borderColor = "#d3c6aa";
    backgroundColor = "#2d353b";
    progressColor = "#d3c6aa";
  };

  # SwayOSD colors
  swayosd = {
    backgroundColor = "#2d353b";
    borderColor = "#d3c6aa";
    textColor = "#d3c6aa";
  };

  # Hyprlock colors
  hyprlock = {
    general = "#2d353b";
    input = "#2d353b";
    innerColor = "#2d353bcc";
    outerColor = "#d3c6aa";
    fontColor = "#d3c6aa";
    checkColor = "#83c092";
    failColor = "#e67e80";
  };

  # Wallpapers (none specified for now)
  wallpapers = [ ];
}
