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

  wallpapers = [ ];
}
