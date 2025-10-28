# Rose Pine Moon (dark) theme
{
  name = "rose-pine";
  displayName = "Rose Pine Moon";

  # GTK/Icon theme package names
  gtk = {
    themeName = "Orchis-Dark";
    themePackage = "orchis-theme";
    iconName = "Papirus-Dark";
    iconPackage = "papirus-icon-theme";
  };

  # Hyprland colors
  hyprland = {
    activeBorder = "rgb(c4a7e7)";
    inactiveBorder = "rgba(595959aa)";
  };

  # Alacritty color scheme (Rose Pine Moon - dark variant)
  alacritty = {
    primary = {
      background = "#232136";
      foreground = "#e0def4";
    };
    normal = {
      black = "#393552";
      red = "#eb6f92";
      green = "#3e8fb0";
      yellow = "#f6c177";
      blue = "#9ccfd8";
      magenta = "#c4a7e7";
      cyan = "#ea9a97";
      white = "#e0def4";
    };
    bright = {
      black = "#6e6a86";
      red = "#eb6f92";
      green = "#3e8fb0";
      yellow = "#f6c177";
      blue = "#9ccfd8";
      magenta = "#c4a7e7";
      cyan = "#ea9a97";
      white = "#e0def4";
    };
    indexed_colors = [
      {
        index = 16;
        color = "#f6c177";
      }
      {
        index = 17;
        color = "#ea9a97";
      }
    ];
  };

  # VSCode theme name
  vscode = {
    theme = "Rosé Pine Moon";
  };

  # Walker launcher colors (Rose Pine Moon - dark variant)
  walker = {
    selectedText = "#c4a7e7"; # Iris (magenta)
    text = "#e0def4"; # Text
    base = "#232136"; # Base
    border = "#c4a7e7"; # Iris border
    foreground = "#e0def4"; # Text
    background = "#232136"; # Base
  };

  # Waybar colors
  waybar = {
    foreground = "#e0def4";
    background = "#232136";
  };

  # wlogout power menu colors
  wlogout = {
    backgroundColor = "#232136";
    buttonBackground = "#2a273f";
    buttonHoverBackground = "#c4a7e7";
    textColor = "#e0def4";
    textHoverColor = "#232136";
  };

  # tmux status bar colors
  tmux = {
    statusBackground = "#232136";
    statusForeground = "#e0def4";
    windowStatusCurrent = "#c4a7e7";
    paneActiveBorder = "#c4a7e7";
    paneInactiveBorder = "#6e6a86";
    messageBackground = "#c4a7e7";
    messageForeground = "#232136";
  };

  # Mako notification colors
  mako = {
    textColor = "#575279";
    borderColor = "#575279";
    backgroundColor = "#faf4ed";
    progressColor = "#575279";
  };

  # SwayOSD colors
  swayosd = {
    backgroundColor = "#faf4ed";
    borderColor = "#575279";
    textColor = "#575279";
  };

  # Hyprlock colors
  hyprlock = {
    general = "#faf4ed";
    input = "#faf4ed";
    innerColor = "#faf4edcc";
    outerColor = "#39344f";
    fontColor = "#39344f";
    checkColor = "#88c0d0";
    failColor = "#eb6f92";
  };

  # Wallpapers
  wallpapers = [
    "1-rose-pine.jpg"
    "2-wave-light.png"
    "3-leafy-dawn-omarchy.png"
  ];
}
