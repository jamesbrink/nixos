# Catppuccin Latte theme (light variant)
{
  name = "catppuccin-latte";
  displayName = "Catppuccin Latte";

  # GTK/Icon theme package names (resolved by main module)
  gtk = {
    themeName = "Catppuccin-Latte-Standard-Blue-Light";
    themePackage = "catppuccin-gtk";
    iconName = "Papirus";
    iconPackage = "papirus-icon-theme";
  };

  # Hyprland colors
  hyprland = {
    activeBorder = "rgb(1e66f5)";
    inactiveBorder = "rgba(dce0e8aa)";
  };

  # Alacritty color scheme
  alacritty = {
    primary = {
      background = "#eff1f5";
      foreground = "#4c4f69";
    };
    normal = {
      black = "#bcc0cc";
      red = "#d20f39";
      green = "#40a02b";
      yellow = "#df8e1d";
      blue = "#1e66f5";
      magenta = "#ea76cb";
      cyan = "#179299";
      white = "#5c5f77";
    };
    bright = {
      black = "#acb0be";
      red = "#d20f39";
      green = "#40a02b";
      yellow = "#df8e1d";
      blue = "#1e66f5";
      magenta = "#ea76cb";
      cyan = "#179299";
      white = "#6c6f85";
    };
    indexed_colors = [
      {
        index = 16;
        color = "#fe640b";
      }
      {
        index = 17;
        color = "#dc8a78";
      }
    ];
  };

  # VSCode theme name
  vscode = {
    theme = "Catppuccin Latte";
  };

  # Walker launcher colors
  walker = {
    selectedText = "#1e66f5";
    text = "#4c4f69";
    base = "#eff1f5";
    border = "#dce0e8";
    foreground = "#4c4f69";
    background = "#eff1f5";
  };

  # Waybar colors
  waybar = {
    foreground = "#4c4f69";
    background = "#eff1f5";
  };

  # Wallpapers (none specified for now)
  wallpapers = [ ];
}
