# Kanagawa theme
{
  name = "kanagawa";
  displayName = "Kanagawa";

  # GTK/Icon theme package names (resolved by main module)
  gtk = {
    themeName = "Kanagawa-BL";
    themePackage = "kanagawa-gtk-theme";
    iconName = "Papirus-Dark";
    iconPackage = "papirus-icon-theme";
  };

  # Hyprland colors
  hyprland = {
    activeBorder = "rgb(dcd7ba)";
    inactiveBorder = "rgba(727169aa)";
  };

  # Alacritty color scheme
  alacritty = {
    primary = {
      background = "#1f1f28";
      foreground = "#dcd7ba";
    };
    normal = {
      black = "#090618";
      red = "#c34043";
      green = "#76946a";
      yellow = "#c0a36e";
      blue = "#7e9cd8";
      magenta = "#957fb8";
      cyan = "#6a9589";
      white = "#c8c093";
    };
    bright = {
      black = "#727169";
      red = "#e82424";
      green = "#98bb6c";
      yellow = "#e6c384";
      blue = "#7fb4ca";
      magenta = "#938aa9";
      cyan = "#7aa89f";
      white = "#dcd7ba";
    };
    indexed_colors = [
      {
        index = 16;
        color = "#ffa066";
      }
      {
        index = 17;
        color = "#ff5d62";
      }
    ];
  };

  # Kitty terminal colors
  kitty = {
    foreground = "#dcd7ba";
    background = "#1f1f28";
    selection_foreground = "#c8c093";
    selection_background = "#2d4f67";
    cursor = "#c8c093";
    url_color = "#72a7bc";
    active_tab_foreground = "#c8c093";
    active_tab_background = "#1f1f28";
    inactive_tab_foreground = "#727169";
    inactive_tab_background = "#1f1f28";
    color0 = "#16161d";
    color1 = "#c34043";
    color2 = "#76946a";
    color3 = "#c0a36e";
    color4 = "#7e9cd8";
    color5 = "#957fb8";
    color6 = "#6a9589";
    color7 = "#c8c093";
    color8 = "#727169";
    color9 = "#e82424";
    color10 = "#98bb6c";
    color11 = "#e6c384";
    color12 = "#7fb4ca";
    color13 = "#938aa9";
    color14 = "#7aa89f";
    color15 = "#dcd7ba";
    color16 = "#ffa066";
    color17 = "#ff5d62";
  };

  # Ghostty terminal theme
  ghostty = {
    theme = "Kanagawa Wave";
  };

  # Neovim colorscheme
  nvim = {
    colorscheme = "kanagawa";
  };

  # VSCode theme name
  vscode = {
    theme = "Kanagawa";
    extension = "qufiwefefwoyn.kanagawa";
  };

  # Walker launcher colors
  walker = {
    selectedText = "#dca561";
    text = "#dcd7ba";
    base = "#1f1f28";
    border = "#dcd7ba";
    foreground = "#dcd7ba";
    background = "#1f1f28";
  };

  # Waybar colors
  waybar = {
    foreground = "#dcd7ba";
    background = "#1f1f28";
  };

  # wlogout power menu colors
  wlogout = {
    backgroundColor = "#1f1f28";
    buttonBackground = "#2a2a37";
    buttonHoverBackground = "#7e9cd8";
    textColor = "#dcd7ba";
    textHoverColor = "#1f1f28";
  };

  # tmux status bar colors
  tmux = {
    statusBackground = "#1f1f28";
    statusForeground = "#dcd7ba";
    windowStatusCurrent = "#7e9cd8";
    paneActiveBorder = "#7e9cd8";
    paneInactiveBorder = "#727169";
    messageBackground = "#7e9cd8";
    messageForeground = "#1f1f28";
  };

  # Mako notification colors
  mako = {
    textColor = "#dcd7ba";
    borderColor = "#dcd7ba";
    backgroundColor = "#1f1f28";
    progressColor = "#dcd7ba";
  };

  # SwayOSD colors
  swayosd = {
    backgroundColor = "#1f1f28";
    borderColor = "#dcd7ba";
    textColor = "#dcd7ba";
  };

  # Hyprlock colors
  hyprlock = {
    general = "#1f1f28";
    input = "#1f1f28";
    innerColor = "#1f1f28cc";
    outerColor = "#dcd7ba";
    fontColor = "#dcd7ba";
    checkColor = "#7e9cd8";
    failColor = "#e82424";
  };

  # btop system monitor colors
  btop = {
    main_bg = "#1f1f28";
    main_fg = "#dcd7ba";
    title = "#dcd7ba";
    hi_fg = "#C34043";
    selected_bg = "#223249";
    selected_fg = "#dca561";
    inactive_fg = "#727169";
    proc_misc = "#7aa89f";
    cpu_box = "#727169";
    mem_box = "#727169";
    net_box = "#727169";
    proc_box = "#727169";
    div_line = "#727169";
    temp_start = "#98BB6C";
    temp_mid = "#DCA561";
    temp_end = "#E82424";
    cpu_start = "#98BB6C";
    cpu_mid = "#DCA561";
    cpu_end = "#E82424";
    free_start = "#E82424";
    free_mid = "#C34043";
    free_end = "#FF5D62";
    cached_start = "#C0A36E";
    cached_mid = "#DCA561";
    cached_end = "#FF9E3B";
    available_start = "#938AA9";
    available_mid = "#957FBB";
    available_end = "#9CABCA";
    used_start = "#658594";
    used_mid = "#7E9CDB";
    used_end = "#7FB4CA";
    download_start = "#7E9CDB";
    download_mid = "#938AA9";
    download_end = "#957FBB";
    upload_start = "#DCA561";
    upload_mid = "#E6C384";
    upload_end = "#E82424";
    process_start = "#98BB6C";
    process_mid = "#DCA561";
    process_end = "#C34043";
  };

  # eza file listing colors
  eza = {
    filekinds = {
      normal = "#dcd7ba";
      directory = "#7e9cd8";
      symlink = "#7aa89f";
      pipe = "#727169";
      block_device = "#ffa066";
      char_device = "#ffa066";
      socket = "#16161d";
      special = "#957fb8";
      executable = "#98bb6c";
      mount_point = "#7fb4ca";
    };
    perms = {
      user_read = "#dcd7ba";
      user_write = "#e6c384";
      user_execute_file = "#98bb6c";
      user_execute_other = "#98bb6c";
      group_read = "#dcd7ba";
      group_write = "#e6c384";
      group_execute = "#98bb6c";
      other_read = "#c8c093";
      other_write = "#e6c384";
      other_execute = "#98bb6c";
      special_user_file = "#957fb8";
      special_other = "#727169";
      attribute = "#dcd7ba";
    };
    size = {
      major = "#dcd7ba";
      minor = "#7aa89f";
      number_byte = "#dcd7ba";
      number_kilo = "#dcd7ba";
      number_mega = "#7e9cd8";
      number_giga = "#957fb8";
      number_huge = "#957fb8";
      unit_byte = "#dcd7ba";
      unit_kilo = "#7e9cd8";
      unit_mega = "#957fb8";
      unit_giga = "#957fb8";
      unit_huge = "#7fb4ca";
    };
    users = {
      user_you = "#dcd7ba";
      user_root = "#e82424";
      user_other = "#957fb8";
      group_yours = "#dcd7ba";
      group_other = "#727169";
      group_root = "#e82424";
    };
    links = {
      normal = "#7aa89f";
      multi_link_file = "#7fb4ca";
    };
    git = {
      new = "#98bb6c";
      modified = "#e6c384";
      deleted = "#e82424";
      renamed = "#7aa89f";
      typechange = "#957fb8";
      ignored = "#727169";
      conflicted = "#c34043";
    };
    git_repo = {
      branch_main = "#dcd7ba";
      branch_other = "#957fb8";
      git_clean = "#98bb6c";
      git_dirty = "#e82424";
    };
    security_context = {
      colon = "#727169";
      user = "#dcd7ba";
      role = "#957fb8";
      typ = "#16161d";
      range = "#957fb8";
    };
    file_type = {
      image = "#e6c384";
      video = "#e82424";
      music = "#98bb6c";
      lossless = "#7aa89f";
      crypto = "#727169";
      document = "#dcd7ba";
      compressed = "#957fb8";
      temp = "#ff5d62";
      compiled = "#7fb4ca";
      build = "#727169";
      source = "#7e9cd8";
    };
    punctuation = "#727169";
    date = "#e6c384";
    inode = "#dcd7ba";
    blocks = "#727169";
    header = "#dcd7ba";
    octal = "#7aa89f";
    flags = "#957fb8";
    symlink_path = "#7aa89f";
    control_char = "#7fb4ca";
    broken_symlink = "#e82424";
    broken_path_overlay = "#727169";
  };

  # Browser theme color (RGB format for Chrome/Brave managed policy)
  browser = {
    themeColor = "31,31,40"; # RGB values from primary background #1f1f28
  };

  # Fastfetch system info colors
  fastfetch = {
    keyColor = "blue"; # Matches the wave theme accent
  };

  # Wallpapers
  wallpapers = [
    "1-kanagawa.jpg"
  ];
}
