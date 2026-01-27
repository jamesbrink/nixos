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

  # Alacritty color scheme (Everforest Dark Hard - matches Ghostty)
  alacritty = {
    primary = {
      background = "#1e2326";
      foreground = "#d3c6aa";
    };
    normal = {
      black = "#7a8478";
      red = "#e67e80";
      green = "#a7c080";
      yellow = "#dbbc7f";
      blue = "#7fbbb3";
      magenta = "#d699b6";
      cyan = "#83c092";
      white = "#f2efdf";
    };
    bright = {
      black = "#a6b0a0";
      red = "#f85552";
      green = "#8da101";
      yellow = "#dfa000";
      blue = "#3a94c5";
      magenta = "#df69ba";
      cyan = "#35a77c";
      white = "#fffbef";
    };
    indexed_colors = [ ];
  };

  # Kitty terminal colors
  kitty = {
    foreground = "#d3c6aa";
    background = "#272e33";
    selection_foreground = "#9da9a0";
    selection_background = "#464e53";
    cursor = "#d3c6aa";
    cursor_text_color = "#2e383c";
    url_color = "#7fbbb3";
    active_border_color = "#a7c080";
    inactive_border_color = "#4f5b58";
    active_tab_background = "#272e33";
    active_tab_foreground = "#d3c6aa";
    inactive_tab_background = "#374145";
    inactive_tab_foreground = "#9da9a0";
    color0 = "#343f44";
    color1 = "#e67e80";
    color2 = "#a7c080";
    color3 = "#dbbc7f";
    color4 = "#7fbbb3";
    color5 = "#d699b6";
    color6 = "#83c092";
    color7 = "#859289";
    color8 = "#868d80";
    color9 = "#e67e80";
    color10 = "#a7c080";
    color11 = "#dbbc7f";
    color12 = "#7fbbb3";
    color13 = "#d699b6";
    color14 = "#83c092";
    color15 = "#9da9a0";
  };

  # Ghostty terminal theme
  ghostty = {
    theme = "Everforest Dark - Hard";
  };

  # VSCode theme name
  vscode = {
    theme = "Everforest Dark";
  };

  # Walker launcher colors
  walker = {
    selectedText = "#dbbc7f";
    text = "#d3c6aa";
    base = "#1e2326";
    border = "#d3c6aa";
    foreground = "#d3c6aa";
    background = "#1e2326";
  };

  # Waybar colors
  waybar = {
    foreground = "#d3c6aa";
    background = "#1e2326";
  };

  # wlogout power menu colors
  wlogout = {
    backgroundColor = "#1e2326";
    buttonBackground = "#343f44";
    buttonHoverBackground = "#a7c080";
    textColor = "#d3c6aa";
    textHoverColor = "#1e2326";
  };

  # tmux status bar colors
  tmux = {
    statusBackground = "#1e2326";
    statusForeground = "#d3c6aa";
    windowStatusCurrent = "#a7c080";
    paneActiveBorder = "#a7c080";
    paneInactiveBorder = "#475258";
    messageBackground = "#a7c080";
    messageForeground = "#1e2326";
  };

  # Mako notification colors
  mako = {
    textColor = "#d3c6aa";
    borderColor = "#d3c6aa";
    backgroundColor = "#1e2326";
    progressColor = "#d3c6aa";
  };

  # SwayOSD colors
  swayosd = {
    backgroundColor = "#1e2326";
    borderColor = "#d3c6aa";
    textColor = "#d3c6aa";
  };

  # Hyprlock colors
  hyprlock = {
    general = "#1e2326";
    input = "#1e2326";
    innerColor = "#1e2326cc";
    outerColor = "#d3c6aa";
    fontColor = "#d3c6aa";
    checkColor = "#83c092";
    failColor = "#e67e80";
  };

  # btop system monitor colors
  btop = {
    main_bg = "#1e2326";
    main_fg = "#d3c6aa";
    title = "#d3c6aa";
    hi_fg = "#e67e80";
    selected_bg = "#3d484d";
    selected_fg = "#dbbc7f";
    inactive_fg = "#1e2326";
    graph_text = "#d3c6aa";
    proc_misc = "#a7c080";
    cpu_box = "#3d484d";
    mem_box = "#3d484d";
    net_box = "#3d484d";
    proc_box = "#3d484d";
    div_line = "#3d484d";
    temp_start = "#a7c080";
    temp_mid = "#dbbc7f";
    temp_end = "#f85552";
    cpu_start = "#a7c080";
    cpu_mid = "#dbbc7f";
    cpu_end = "#f85552";
    free_start = "#f85552";
    free_mid = "#dbbc7f";
    free_end = "#a7c080";
    cached_start = "#7fbbb3";
    cached_mid = "#83c092";
    cached_end = "#a7c080";
    available_start = "#f85552";
    available_mid = "#dbbc7f";
    available_end = "#a7c080";
    used_start = "#a7c080";
    used_mid = "#dbbc7f";
    used_end = "#f85552";
    download_start = "#a7c080";
    download_mid = "#83c092";
    download_end = "#7fbbb3";
    upload_start = "#dbbc7f";
    upload_mid = "#e69875";
    upload_end = "#e67e80";
    process_start = "#a7c080";
    process_mid = "#e67e80";
    process_end = "#f85552";
  };

  # eza file listing colors
  eza = {
    filekinds = {
      normal = "#d3c6aa";
      directory = "#7fbbb3";
      symlink = "#83c092";
      pipe = "#475258";
      block_device = "#e69875";
      char_device = "#e69875";
      socket = "#343f44";
      special = "#d699b6";
      executable = "#a7c080";
      mount_point = "#83c092";
    };
    perms = {
      user_read = "#d3c6aa";
      user_write = "#dbbc7f";
      user_execute_file = "#a7c080";
      user_execute_other = "#a7c080";
      group_read = "#d3c6aa";
      group_write = "#dbbc7f";
      group_execute = "#a7c080";
      other_read = "#d3c6aa";
      other_write = "#dbbc7f";
      other_execute = "#a7c080";
      special_user_file = "#d699b6";
      special_other = "#475258";
      attribute = "#d3c6aa";
    };
    size = {
      major = "#d3c6aa";
      minor = "#83c092";
      number_byte = "#d3c6aa";
      number_kilo = "#d3c6aa";
      number_mega = "#7fbbb3";
      number_giga = "#d699b6";
      number_huge = "#d699b6";
      unit_byte = "#d3c6aa";
      unit_kilo = "#7fbbb3";
      unit_mega = "#d699b6";
      unit_giga = "#d699b6";
      unit_huge = "#83c092";
    };
    users = {
      user_you = "#d3c6aa";
      user_root = "#e67e80";
      user_other = "#d699b6";
      group_yours = "#d3c6aa";
      group_other = "#475258";
      group_root = "#e67e80";
    };
    links = {
      normal = "#83c092";
      multi_link_file = "#7fbbb3";
    };
    git = {
      new = "#a7c080";
      modified = "#dbbc7f";
      deleted = "#e67e80";
      renamed = "#83c092";
      typechange = "#d699b6";
      ignored = "#475258";
      conflicted = "#f85552";
    };
    git_repo = {
      branch_main = "#d3c6aa";
      branch_other = "#d699b6";
      git_clean = "#a7c080";
      git_dirty = "#e67e80";
    };
    security_context = {
      colon = "#475258";
      user = "#d3c6aa";
      role = "#d699b6";
      typ = "#343f44";
      range = "#d699b6";
    };
    file_type = {
      image = "#dbbc7f";
      video = "#e67e80";
      music = "#a7c080";
      lossless = "#83c092";
      crypto = "#475258";
      document = "#d3c6aa";
      compressed = "#d699b6";
      temp = "#e69875";
      compiled = "#7fbbb3";
      build = "#475258";
      source = "#7fbbb3";
    };
    punctuation = "#475258";
    date = "#dbbc7f";
    inode = "#d3c6aa";
    blocks = "#475258";
    header = "#d3c6aa";
    octal = "#83c092";
    flags = "#d699b6";
    symlink_path = "#83c092";
    control_char = "#7fbbb3";
    broken_symlink = "#e67e80";
    broken_path_overlay = "#475258";
  };

  # Browser theme color (RGB format for Chrome/Brave managed policy)
  browser = {
    themeColor = "30,35,38"; # RGB values from primary background #1e2326
  };

  # Fastfetch system info colors
  fastfetch = {
    keyColor = "green"; # Matches the forest theme accent
  };

  # Wallpapers
  wallpapers = [
    "1-everforest.jpg"
  ];
}
