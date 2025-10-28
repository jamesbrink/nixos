# Nord theme
{
  name = "nord";
  displayName = "Nord";

  # GTK/Icon theme package names
  gtk = {
    themeName = "Nordic";
    themePackage = "nordic";
    iconName = "Papirus-Dark";
    iconPackage = "papirus-icon-theme";
  };

  # Hyprland colors
  hyprland = {
    activeBorder = "rgb(88c0d0)";
    inactiveBorder = "rgba(595959aa)";
  };

  # Alacritty color scheme
  alacritty = {
    primary = {
      background = "#2e3440";
      foreground = "#d8dee9";
    };
    normal = {
      black = "#3b4252";
      red = "#bf616a";
      green = "#a3be8c";
      yellow = "#ebcb8b";
      blue = "#81a1c1";
      magenta = "#b48ead";
      cyan = "#88c0d0";
      white = "#e5e9f0";
    };
    bright = {
      black = "#4c566a";
      red = "#bf616a";
      green = "#a3be8c";
      yellow = "#ebcb8b";
      blue = "#81a1c1";
      magenta = "#b48ead";
      cyan = "#8fbcbb";
      white = "#eceff4";
    };
    indexed_colors = [
      {
        index = 16;
        color = "#d08770";
      }
      {
        index = 17;
        color = "#5e81ac";
      }
    ];
  };

  # VSCode theme name
  vscode = {
    theme = "Nord";
  };

  # Walker launcher colors
  walker = {
    selectedText = "#88C0D0";
    text = "#D8DEE9";
    base = "#2E3440";
    border = "#D8DEE9";
    foreground = "#D8DEE9";
    background = "#2E3440";
  };

  # Waybar colors
  waybar = {
    foreground = "#D8DEE9";
    background = "#2E3440";
  };

  # wlogout power menu colors
  wlogout = {
    backgroundColor = "#2e3440";
    buttonBackground = "#3b4252";
    buttonHoverBackground = "#88c0d0";
    textColor = "#d8dee9";
    textHoverColor = "#2e3440";
  };

  # tmux status bar colors
  tmux = {
    statusBackground = "#2e3440";
    statusForeground = "#d8dee9";
    windowStatusCurrent = "#88c0d0";
    paneActiveBorder = "#88c0d0";
    paneInactiveBorder = "#4c566a";
    messageBackground = "#88c0d0";
    messageForeground = "#2e3440";
  };

  # Mako notification colors
  mako = {
    textColor = "#d8dee9";
    borderColor = "#D8DEE9";
    backgroundColor = "#2e3440";
    progressColor = "#D8DEE9";
  };

  # SwayOSD colors
  swayosd = {
    backgroundColor = "#2E3440";
    borderColor = "#D8DEE9";
    textColor = "#D8DEE9";
  };

  # Hyprlock colors
  hyprlock = {
    general = "#2e3440";
    input = "#2e3440";
    innerColor = "#2e3440cc";
    outerColor = "#d8dee9";
    fontColor = "#d8dee9";
    checkColor = "#88c0d0";
    failColor = "#bf616a";
  };

  # Wallpapers
  wallpapers = [
    "1-nord.png"
    "2-nord.png"
  ];
}
