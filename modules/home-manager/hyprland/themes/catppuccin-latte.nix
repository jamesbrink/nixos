# Catppuccin Latte theme (light variant)
{
  name = "catppuccin-latte";
  displayName = "Catppuccin Latte";

  # GTK/Icon theme package names (resolved by main module)
  gtk = {
    themeName = "Catppuccin-Latte-Standard-Blue-Light";
    themePackage = "catppuccin-gtk";
    themeOverride = ''accents = [ "blue" ]; variant = "latte";'';
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

  # wlogout power menu colors
  wlogout = {
    backgroundColor = "#eff1f5";
    buttonBackground = "#e6e9ef";
    buttonHoverBackground = "#1e66f5";
    textColor = "#4c4f69";
    textHoverColor = "#eff1f5";
  };

  # tmux status bar colors
  tmux = {
    statusBackground = "#eff1f5";
    statusForeground = "#4c4f69";
    windowStatusCurrent = "#1e66f5";
    paneActiveBorder = "#1e66f5";
    paneInactiveBorder = "#acb0be";
    messageBackground = "#1e66f5";
    messageForeground = "#eff1f5";
  };

  # Mako notification colors
  mako = {
    textColor = "#4c4f69";
    borderColor = "#1e66f5";
    backgroundColor = "#eff1f5";
    progressColor = "#4c4f69";
  };

  # SwayOSD colors
  swayosd = {
    backgroundColor = "#eff1f5";
    borderColor = "#1e66f5";
    textColor = "#4c4f69";
  };

  # Hyprlock colors
  hyprlock = {
    general = "#eff1f5";
    input = "#eff1f5";
    innerColor = "#eff1f5cc";
    outerColor = "#1e66f5";
    fontColor = "#4c4f69";
    checkColor = "#04a5e5";
    failColor = "#d20f39";
  };

  # Wallpapers
  # To add wallpapers for this theme:
  # 1. Create directory: mkdir -p modules/home-manager/hyprland/wallpapers/catppuccin-latte
  # 2. Add image files (JPG or PNG) to the directory
  # 3. List them here: wallpapers = [ "1-my-wallpaper.jpg" "2-another.png" ];
  # 4. Use Super+Ctrl+Space to rotate through backgrounds
  wallpapers = [ ];
}
