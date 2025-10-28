# Ristretto theme (Monokai-inspired)
{
  name = "ristretto";
  displayName = "Ristretto";

  # GTK/Icon theme package names (resolved by main module)
  gtk = {
    themeName = "Adwaita-dark";
    themePackage = "adwaita-icon-theme"; # Built-in, no separate package needed
    iconName = "Papirus-Dark";
    iconPackage = "papirus-icon-theme";
  };

  # Hyprland colors
  hyprland = {
    activeBorder = "rgb(e6d9db)";
    inactiveBorder = "rgba(72696aaa)";
  };

  # Alacritty color scheme
  alacritty = {
    primary = {
      background = "#2c2525";
      foreground = "#e6d9db";
    };
    normal = {
      black = "#72696a";
      red = "#fd6883";
      green = "#adda78";
      yellow = "#f9cc6c";
      blue = "#f38d70";
      magenta = "#a8a9eb";
      cyan = "#85dacc";
      white = "#e6d9db";
    };
    bright = {
      black = "#948a8b";
      red = "#ff8297";
      green = "#c8e292";
      yellow = "#fcd675";
      blue = "#f8a788";
      magenta = "#bebffd";
      cyan = "#9bf1e1";
      white = "#f1e5e7";
    };
    indexed_colors = [ ];
  };

  # VSCode theme name
  vscode = {
    theme = "Monokai Pro (Filter Ristretto)";
  };

  # Walker launcher colors
  walker = {
    selectedText = "#fabd2f";
    text = "#e6d9db";
    base = "#2c2525";
    border = "#e6d9db";
    foreground = "#e6d9db";
    background = "#2c2525";
  };

  # Waybar colors
  waybar = {
    foreground = "#e6d9db";
    background = "#2c2525";
  };

  # Wallpapers (none specified for now)
  wallpapers = [ ];
}
