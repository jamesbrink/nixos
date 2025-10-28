# Tokyo Night theme
{
  name = "tokyo-night";
  displayName = "Tokyo Night";

  # GTK/Icon theme package names (resolved by main module)
  gtk = {
    themeName = "Tokyonight-Dark";
    themePackage = "tokyonight-gtk-theme";
    iconName = "Papirus-Dark";
    iconPackage = "papirus-icon-theme";
  };

  # Hyprland colors
  hyprland = {
    activeBorder = "rgba(33ccffee) rgba(00ff99ee) 45deg";
    inactiveBorder = "rgba(595959aa)";
  };

  # Alacritty color scheme
  alacritty = {
    primary = {
      background = "#1a1b26";
      foreground = "#a9b1d6";
    };
    normal = {
      black = "#32344a";
      red = "#f7768e";
      green = "#9ece6a";
      yellow = "#e0af68";
      blue = "#7aa2f7";
      magenta = "#ad8ee6";
      cyan = "#449dab";
      white = "#787c99";
    };
    bright = {
      black = "#444b6a";
      red = "#ff7a93";
      green = "#b9f27c";
      yellow = "#ff9e64";
      blue = "#7da6ff";
      magenta = "#bb9af7";
      cyan = "#0db9d7";
      white = "#acb0d0";
    };
    indexed_colors = [
      {
        index = 16;
        color = "#ff9e64";
      }
      {
        index = 17;
        color = "#db4b4b";
      }
    ];
  };

  # VSCode theme name
  vscode = {
    theme = "Tokyo Night";
  };

  # Walker launcher colors
  walker = {
    selectedText = "#7dcfff";
    text = "#cfc9c2";
    base = "#1a1b26";
    border = "#33ccff";
    foreground = "#cfc9c2";
    background = "#1a1b26";
  };

  # Waybar colors
  waybar = {
    foreground = "#cdd6f4";
    background = "#1a1b26";
  };

  # Wallpapers
  wallpapers = [
    "1-scenery-pink-lakeside-sunset-lake-landscape-scenic-panorama-7680x3215-144.png"
    "2-Pawel-Czerwinski-Abstract-Purple-Blue.jpg"
    "3-Milad-Fakurian-Abstract-Purple-Blue.jpg"
  ];
}
