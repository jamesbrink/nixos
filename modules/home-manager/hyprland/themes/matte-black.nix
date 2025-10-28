# Matte Black theme
{
  name = "matte-black";
  displayName = "Matte Black";

  # GTK/Icon theme package names (resolved by main module)
  gtk = {
    themeName = "Adwaita-dark";
    themePackage = "adwaita-icon-theme"; # Built-in, no separate package needed
    iconName = "Papirus-Dark";
    iconPackage = "papirus-icon-theme";
  };

  # Hyprland colors
  hyprland = {
    activeBorder = "rgb(8A8A8D)";
    inactiveBorder = "rgba(333333aa)";
  };

  # Alacritty color scheme
  alacritty = {
    primary = {
      background = "#121212";
      foreground = "#bebebe";
    };
    normal = {
      black = "#333333";
      red = "#D35F5F";
      green = "#FFC107";
      yellow = "#b91c1c";
      blue = "#e68e0d";
      magenta = "#D35F5F";
      cyan = "#bebebe";
      white = "#bebebe";
    };
    bright = {
      black = "#8a8a8d";
      red = "#B91C1C";
      green = "#FFC107";
      yellow = "#b90a0a";
      blue = "#f59e0b";
      magenta = "#B91C1C";
      cyan = "#eaeaea";
      white = "#ffffff";
    };
    indexed_colors = [ ];
  };

  # VSCode theme name
  vscode = {
    theme = "Matte Black";
  };

  # Walker launcher colors
  walker = {
    selectedText = "#B91C1C";
    text = "#EAEAEA";
    base = "#121212";
    border = "#EAEAEA88";
    foreground = "#EAEAEA";
    background = "#121212";
  };

  # Wallpapers (none specified for now)
  wallpapers = [ ];
}
