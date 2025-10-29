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

  # Walker launcher colors (Rose Pine Moon - dark variant)
  walker = {
    selectedText = "#c4a7e7"; # Iris (magenta)
    text = "#e0def4"; # Text
    base = "#232136"; # Base
    border = "#c4a7e7"; # Iris border
    foreground = "#e0def4"; # Text
    background = "#232136"; # Base
  };

  # Waybar colors
  waybar = {
    foreground = "#e0def4";
    background = "#232136";
  };

  # wlogout power menu colors
  wlogout = {
    backgroundColor = "#232136";
    buttonBackground = "#2a273f";
    buttonHoverBackground = "#c4a7e7";
    textColor = "#e0def4";
    textHoverColor = "#232136";
  };

  # tmux status bar colors
  tmux = {
    statusBackground = "#232136";
    statusForeground = "#e0def4";
    windowStatusCurrent = "#c4a7e7";
    paneActiveBorder = "#c4a7e7";
    paneInactiveBorder = "#6e6a86";
    messageBackground = "#c4a7e7";
    messageForeground = "#232136";
  };

  # Mako notification colors
  mako = {
    textColor = "#575279";
    borderColor = "#575279";
    backgroundColor = "#faf4ed";
    progressColor = "#575279";
  };

  # SwayOSD colors
  swayosd = {
    backgroundColor = "#faf4ed";
    borderColor = "#575279";
    textColor = "#575279";
  };

  # Hyprlock colors
  hyprlock = {
    general = "#faf4ed";
    input = "#faf4ed";
    innerColor = "#faf4edcc";
    outerColor = "#39344f";
    fontColor = "#39344f";
    checkColor = "#88c0d0";
    failColor = "#eb6f92";
  };

  # btop system monitor colors
  btop = {
    main_bg = "#faf4ed";
    main_fg = "#575279";
    title = "#908caa";
    hi_fg = "#e0def4";
    selected_bg = "#524f67";
    selected_fg = "#f6c177";
    inactive_fg = "#403d52";
    graph_text = "#9ccfd8";
    meter_bg = "#9ccfd8";
    proc_misc = "#c4a7e7";
    cpu_box = "#ebbcba";
    mem_box = "#31748f";
    net_box = "#c4a7e7";
    proc_box = "#eb6f92";
    div_line = "#6e6a86";
    temp_start = "#ebbcba";
    temp_mid = "#f6c177";
    temp_end = "#eb6f92";
    cpu_start = "#f6c177";
    cpu_mid = "#ebbcba";
    cpu_end = "#eb6f92";
    free_start = "#eb6f92";
    free_mid = "#eb6f92";
    free_end = "#eb6f92";
    cached_start = "#c4a7e7";
    cached_mid = "#c4a7e7";
    cached_end = "#c4a7e7";
    available_start = "#31748f";
    available_mid = "#31748f";
    available_end = "#31748f";
    used_start = "#ebbcba";
    used_mid = "#ebbcba";
    used_end = "#ebbcba";
    download_start = "#31748f";
    download_mid = "#9ccfd8";
    download_end = "#9ccfd8";
    upload_start = "#ebbcba";
    upload_mid = "#eb6f92";
    upload_end = "#eb6f92";
    process_start = "#31748f";
    process_mid = "#9ccfd8";
    process_end = "#9ccfd8";
  };

  # eza file listing colors
  eza = {
    filekinds = {
      normal = "#e0def4";
      directory = "#9ccfd8";
      symlink = "#524f67";
      pipe = "#908caa";
      block_device = "#ebbcba";
      char_device = "#f6c177";
      socket = "#21202e";
      special = "#c4a7e7";
      executable = "#c4a7e7";
      mount_point = "#403d52";
    };
    perms = {
      user_read = "#908caa";
      user_write = "#403d52";
      user_execute_file = "#c4a7e7";
      user_execute_other = "#c4a7e7";
      group_read = "#908caa";
      group_write = "#403d52";
      group_execute = "#c4a7e7";
      other_read = "#908caa";
      other_write = "#403d52";
      other_execute = "#c4a7e7";
      special_user_file = "#c4a7e7";
      special_other = "#403d52";
      attribute = "#908caa";
    };
    size = {
      major = "#908caa";
      minor = "#9ccfd8";
      number_byte = "#908caa";
      number_kilo = "#524f67";
      number_mega = "#31748f";
      number_giga = "#c4a7e7";
      number_huge = "#c4a7e7";
      unit_byte = "#908caa";
      unit_kilo = "#31748f";
      unit_mega = "#c4a7e7";
      unit_giga = "#c4a7e7";
      unit_huge = "#9ccfd8";
    };
    users = {
      user_you = "#f6c177";
      user_root = "#eb6f92";
      user_other = "#c4a7e7";
      group_yours = "#524f67";
      group_other = "#6e6a86";
      group_root = "#eb6f92";
    };
    links = {
      normal = "#9ccfd8";
      multi_link_file = "#31748f";
    };
    git = {
      new = "#9ccfd8";
      modified = "#f6c177";
      deleted = "#eb6f92";
      renamed = "#31748f";
      typechange = "#c4a7e7";
      ignored = "#6e6a86";
      conflicted = "#ebbcba";
    };
    git_repo = {
      branch_main = "#908caa";
      branch_other = "#c4a7e7";
      git_clean = "#9ccfd8";
      git_dirty = "#eb6f92";
    };
    security_context = {
      colon = "#908caa";
      user = "#9ccfd8";
      role = "#c4a7e7";
      typ = "#6e6a86";
      range = "#c4a7e7";
    };
    file_type = {
      image = "#f6c177";
      video = "#eb6f92";
      music = "#9ccfd8";
      lossless = "#6e6a86";
      crypto = "#403d52";
      document = "#908caa";
      compressed = "#c4a7e7";
      temp = "#ebbcba";
      compiled = "#31748f";
      build = "#6e6a86";
      source = "#ebbcba";
    };
    punctuation = "#524f67";
    date = "#31748f";
    inode = "#908caa";
    blocks = "#6e6a86";
    header = "#908caa";
    octal = "#9ccfd8";
    flags = "#c4a7e7";
    symlink_path = "#9ccfd8";
    control_char = "#31748f";
    broken_symlink = "#eb6f92";
    broken_path_overlay = "#524f67";
  };

  # Wallpapers
  wallpapers = [
    "1-rose-pine.jpg"
    "2-wave-light.png"
    "3-leafy-dawn-omarchy.png"
  ];
}
