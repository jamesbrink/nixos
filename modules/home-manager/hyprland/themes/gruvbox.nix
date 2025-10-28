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

  wallpapers = [ ];
}
