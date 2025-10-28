# Gruvbox Material Dark theme
{
  name = "gruvbox";
  displayName = "Gruvbox Material";

  # GTK/Icon theme package names
  gtk = {
    themeName = "Gruvbox-Dark";
    themePackage = "gruvbox-gtk-theme";
    iconName = "Papirus-Dark";
    iconPackage = "papirus-icon-theme";
  };

  # Hyprland colors
  hyprland = {
    activeBorder = "rgb(a89984)";
    inactiveBorder = "rgba(595959aa)";
  };

  # Alacritty color scheme
  alacritty = {
    primary = {
      background = "#282828";
      foreground = "#d4be98";
    };
    normal = {
      black = "#3c3836";
      red = "#ea6962";
      green = "#a9b665";
      yellow = "#d8a657";
      blue = "#7daea3";
      magenta = "#d3869b";
      cyan = "#89b482";
      white = "#d4be98";
    };
    bright = {
      black = "#3c3836";
      red = "#ea6962";
      green = "#a9b665";
      yellow = "#d8a657";
      blue = "#7daea3";
      magenta = "#d3869b";
      cyan = "#89b482";
      white = "#d4be98";
    };
    indexed_colors = [
      {
        index = 16;
        color = "#e78a4e";
      }
      {
        index = 17;
        color = "#d65d0e";
      }
    ];
  };

  # VSCode theme name
  vscode = {
    theme = "Gruvbox Material Dark";
  };

  # Walker launcher colors
  walker = {
    selectedText = "#fabd2f";
    text = "#ebdbb2";
    base = "#282828";
    border = "#ebdbb2";
    foreground = "#ebdbb2";
    background = "#282828";
  };

  # Waybar colors
  waybar = {
    foreground = "#ebdbb2";
    background = "#282828";
  };

  # wlogout power menu colors
  wlogout = {
    backgroundColor = "#282828";
    buttonBackground = "#3c3836";
    buttonHoverBackground = "#d8a657";
    textColor = "#d4be98";
    textHoverColor = "#282828";
  };

  # tmux status bar colors
  tmux = {
    statusBackground = "#282828";
    statusForeground = "#d4be98";
    windowStatusCurrent = "#d8a657";
    paneActiveBorder = "#a89984";
    paneInactiveBorder = "#504945";
    messageBackground = "#d8a657";
    messageForeground = "#282828";
  };

  # Mako notification colors
  mako = {
    textColor = "#d4be98";
    borderColor = "#a89984";
    backgroundColor = "#282828";
    progressColor = "#ebdbb2";
  };

  # SwayOSD colors
  swayosd = {
    backgroundColor = "#282828";
    borderColor = "#a89984";
    textColor = "#ebdbb2";
  };

  # Hyprlock colors
  hyprlock = {
    general = "#282828";
    input = "#282828";
    innerColor = "#282828cc";
    outerColor = "#d4be98";
    fontColor = "#d4be98";
    checkColor = "#d6995c";
    failColor = "#ea6962";
  };

  # Wallpapers
  wallpapers = [
    "1-grubox.jpg"
  ];
}
