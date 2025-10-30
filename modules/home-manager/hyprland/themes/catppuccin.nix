# Catppuccin Macchiato theme
{
  name = "catppuccin";
  displayName = "Catppuccin Macchiato";

  # GTK/Icon theme package names
  gtk = {
    themeName = "Catppuccin-Macchiato-Standard-Blue-Dark";
    themePackage = "catppuccin-gtk";
    themeOverride = ''accents = [ "blue" ]; variant = "macchiato";'';
    iconName = "Papirus-Dark";
    iconPackage = "papirus-icon-theme";
  };

  # Hyprland colors
  hyprland = {
    activeBorder = "rgb(c6d0f5)";
    inactiveBorder = "rgba(595959aa)";
  };

  # Alacritty color scheme
  alacritty = {
    primary = {
      background = "#24273a";
      foreground = "#cad3f5";
    };
    normal = {
      black = "#494d64";
      red = "#ed8796";
      green = "#a6da95";
      yellow = "#eed49f";
      blue = "#8aadf4";
      magenta = "#f5bde6";
      cyan = "#8bd5ca";
      white = "#b8c0e0";
    };
    bright = {
      black = "#5b6078";
      red = "#ed8796";
      green = "#a6da95";
      yellow = "#eed49f";
      blue = "#8aadf4";
      magenta = "#f5bde6";
      cyan = "#8bd5ca";
      white = "#a5adcb";
    };
    indexed_colors = [
      {
        index = 16;
        color = "#f5a97f";
      }
      {
        index = 17;
        color = "#f4dbd6";
      }
    ];
  };

  # Kitty terminal colors
  kitty = {
    foreground = "#CDD6F4";
    background = "#1E1E2E";
    selection_foreground = "#1E1E2E";
    selection_background = "#F5E0DC";
    cursor = "#F5E0DC";
    cursor_text_color = "#1E1E2E";
    url_color = "#B4BEFE";
    active_border_color = "#CBA6F7";
    inactive_border_color = "#8E95B3";
    active_tab_foreground = "#11111B";
    active_tab_background = "#CBA6F7";
    inactive_tab_foreground = "#CDD6F4";
    inactive_tab_background = "#181825";
    color0 = "#43465A";
    color1 = "#F38BA8";
    color2 = "#A6E3A1";
    color3 = "#F9E2AF";
    color4 = "#87B0F9";
    color5 = "#F5C2E7";
    color6 = "#94E2D5";
    color7 = "#CDD6F4";
    color8 = "#43465A";
    color9 = "#F38BA8";
    color10 = "#A6E3A1";
    color11 = "#F9E2AF";
    color12 = "#87B0F9";
    color13 = "#F5C2E7";
    color14 = "#94E2D5";
    color15 = "#A1A8C9";
  };

  # Ghostty terminal theme
  ghostty = {
    theme = "Catppuccin Mocha";
  };

  # VSCode theme name
  vscode = {
    theme = "Catppuccin Macchiato";
  };

  # Walker launcher colors
  walker = {
    selectedText = "#8caaee";
    text = "#c6d0f5";
    base = "#24273a";
    border = "#c6d0f5";
    foreground = "#c6d0f5";
    background = "#24273a";
  };

  # Waybar colors
  waybar = {
    foreground = "#c6d0f5";
    background = "#24273a";
  };

  # wlogout power menu colors
  wlogout = {
    backgroundColor = "#24273a";
    buttonBackground = "#363a4f";
    buttonHoverBackground = "#8aadf4";
    textColor = "#cad3f5";
    textHoverColor = "#24273a";
  };

  # tmux status bar colors
  tmux = {
    statusBackground = "#24273a";
    statusForeground = "#cad3f5";
    windowStatusCurrent = "#8aadf4";
    paneActiveBorder = "#8aadf4";
    paneInactiveBorder = "#5b6078";
    messageBackground = "#8aadf4";
    messageForeground = "#24273a";
  };

  # Mako notification colors
  mako = {
    textColor = "#cad3f5";
    borderColor = "#c6d0f5";
    backgroundColor = "#24273a";
    progressColor = "#cad3f5";
  };

  # SwayOSD colors
  swayosd = {
    backgroundColor = "#24273a";
    borderColor = "#c6d0f5";
    textColor = "#cad3f5";
  };

  # Hyprlock colors
  hyprlock = {
    general = "#181824";
    input = "#181824";
    innerColor = "#181824cc";
    outerColor = "#cdd6f4";
    fontColor = "#cdd6f4";
    checkColor = "#449dab";
    failColor = "#ed8796";
  };

  # btop system monitor colors
  btop = {
    main_bg = "#24273a";
    main_fg = "#c6d0f5";
    title = "#c6d0f5";
    hi_fg = "#8caaee";
    selected_bg = "#51576d";
    selected_fg = "#8caaee";
    inactive_fg = "#838ba7";
    graph_text = "#f2d5cf";
    meter_bg = "#51576d";
    proc_misc = "#f2d5cf";
    cpu_box = "#ca9ee6";
    mem_box = "#a6d189";
    net_box = "#ea999c";
    proc_box = "#8caaee";
    div_line = "#737994";
    temp_start = "#a6d189";
    temp_mid = "#e5c890";
    temp_end = "#e78284";
    cpu_start = "#81c8be";
    cpu_mid = "#85c1dc";
    cpu_end = "#babbf1";
    free_start = "#ca9ee6";
    free_mid = "#babbf1";
    free_end = "#8caaee";
    cached_start = "#85c1dc";
    cached_mid = "#8caaee";
    cached_end = "#babbf1";
    available_start = "#ef9f76";
    available_mid = "#ea999c";
    available_end = "#e78284";
    used_start = "#a6d189";
    used_mid = "#81c8be";
    used_end = "#99d1db";
    download_start = "#ef9f76";
    download_mid = "#ea999c";
    download_end = "#e78284";
    upload_start = "#a6d189";
    upload_mid = "#81c8be";
    upload_end = "#99d1db";
    process_start = "#85c1dc";
    process_mid = "#babbf1";
    process_end = "#ca9ee6";
  };

  # eza file listing colors
  eza = {
    filekinds = {
      normal = "#BAC2DE";
      directory = "#89B4FA";
      symlink = "#89DCEB";
      pipe = "#7F849C";
      block_device = "#EBA0AC";
      char_device = "#EBA0AC";
      socket = "#585B70";
      special = "#CBA6F7";
      executable = "#A6E3A1";
      mount_point = "#74C7EC";
    };
    perms = {
      user_read = "#CDD6F4";
      user_write = "#F9E2AF";
      user_execute_file = "#A6E3A1";
      user_execute_other = "#A6E3A1";
      group_read = "#BAC2DE";
      group_write = "#F9E2AF";
      group_execute = "#A6E3A1";
      other_read = "#A6ADC8";
      other_write = "#F9E2AF";
      other_execute = "#A6E3A1";
      special_user_file = "#CBA6F7";
      special_other = "#585B70";
      attribute = "#A6ADC8";
    };
    size = {
      major = "#A6ADC8";
      minor = "#89DCEB";
      number_byte = "#CDD6F4";
      number_kilo = "#BAC2DE";
      number_mega = "#89B4FA";
      number_giga = "#CBA6F7";
      number_huge = "#CBA6F7";
      unit_byte = "#A6ADC8";
      unit_kilo = "#89B4FA";
      unit_mega = "#CBA6F7";
      unit_giga = "#CBA6F7";
      unit_huge = "#74C7EC";
    };
    users = {
      user_you = "#CDD6F4";
      user_root = "#F38BA8";
      user_other = "#CBA6F7";
      group_yours = "#BAC2DE";
      group_other = "#7F849C";
      group_root = "#F38BA8";
    };
    links = {
      normal = "#89DCEB";
      multi_link_file = "#74C7EC";
    };
    git = {
      new = "#A6E3A1";
      modified = "#F9E2AF";
      deleted = "#F38BA8";
      renamed = "#94E2D5";
      typechange = "#F5C2E7";
      ignored = "#7F849C";
      conflicted = "#EBA0AC";
    };
    git_repo = {
      branch_main = "#CDD6F4";
      branch_other = "#CBA6F7";
      git_clean = "#A6E3A1";
      git_dirty = "#F38BA8";
    };
    security_context = {
      colon = "#7F849C";
      user = "#BAC2DE";
      role = "#CBA6F7";
      typ = "#585B70";
      range = "#CBA6F7";
    };
    file_type = {
      image = "#F9E2AF";
      video = "#F38BA8";
      music = "#A6E3A1";
      lossless = "#94E2D5";
      crypto = "#585B70";
      document = "#CDD6F4";
      compressed = "#F5C2E7";
      temp = "#EBA0AC";
      compiled = "#74C7EC";
      build = "#585B70";
      source = "#89B4FA";
    };
    punctuation = "#7F849C";
    date = "#F9E2AF";
    inode = "#A6ADC8";
    blocks = "#9399B2";
    header = "#CDD6F4";
    octal = "#94E2D5";
    flags = "#CBA6F7";
    symlink_path = "#89DCEB";
    control_char = "#74C7EC";
    broken_symlink = "#F38BA8";
    broken_path_overlay = "#585B70";
  };

  # Browser theme color (RGB format for Chrome/Brave managed policy)
  browser = {
    themeColor = "36,39,58"; # RGB values from primary background #24273a
  };

  # Fastfetch system info colors
  fastfetch = {
    keyColor = "magenta"; # Matches the purple/mauve accent theme
  };

  # Wallpapers
  wallpapers = [
    "1-catppuccin.png"
    "2-cat-waves-mocha.png"
    "3-cat-blue-eye-mocha.png"
  ];
}
