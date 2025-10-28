# Osaka Jade theme
{
  name = "osaka-jade";
  displayName = "Osaka Jade";

  # GTK/Icon theme package names (resolved by main module)
  gtk = {
    themeName = "Adwaita-dark";
    themePackage = "adwaita-icon-theme"; # Built-in, no separate package needed
    iconName = "Papirus-Dark";
    iconPackage = "papirus-icon-theme";
  };

  # Hyprland colors
  hyprland = {
    activeBorder = "rgb(71CEAD)";
    inactiveBorder = "rgba(214237aa)";
  };

  # Alacritty color scheme
  alacritty = {
    primary = {
      background = "#111c18";
      foreground = "#C1C497";
    };
    normal = {
      black = "#23372B";
      red = "#FF5345";
      green = "#549e6a";
      yellow = "#459451";
      blue = "#509475";
      magenta = "#D2689C";
      cyan = "#2DD5B7";
      white = "#F6F5DD";
    };
    bright = {
      black = "#53685B";
      red = "#db9f9c";
      green = "#143614";
      yellow = "#E5C736";
      blue = "#ACD4CF";
      magenta = "#75bbb3";
      cyan = "#8CD3CB";
      white = "#9eebb3";
    };
    indexed_colors = [ ];
  };

  # VSCode theme name
  vscode = {
    theme = "Ocean Green: Dark";
  };

  # Walker launcher colors
  walker = {
    selectedText = "#e1b55e";
    text = "#ebfff2";
    base = "#11221C";
    border = "#214237";
    foreground = "#11221C";
    background = "#11221C";
  };

  # Wallpapers (none specified for now)
  wallpapers = [ ];
}
