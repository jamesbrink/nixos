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

  # Wallpapers (none specified for now)
  wallpapers = [ ];
}
