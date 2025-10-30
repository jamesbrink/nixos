# Nord theme
{
  name = "nord";
  displayName = "Nord";

  # GTK/Icon theme package names
  gtk = {
    themeName = "Nordic";
    themePackage = "nordic";
    iconName = "Papirus-Dark";
    iconPackage = "papirus-icon-theme";
  };

  # Hyprland colors
  hyprland = {
    activeBorder = "rgb(88c0d0)";
    inactiveBorder = "rgba(595959aa)";
  };

  # Alacritty color scheme
  alacritty = {
    primary = {
      background = "#2e3440";
      foreground = "#d8dee9";
    };
    normal = {
      black = "#3b4252";
      red = "#bf616a";
      green = "#a3be8c";
      yellow = "#ebcb8b";
      blue = "#81a1c1";
      magenta = "#b48ead";
      cyan = "#88c0d0";
      white = "#e5e9f0";
    };
    bright = {
      black = "#4c566a";
      red = "#bf616a";
      green = "#a3be8c";
      yellow = "#ebcb8b";
      blue = "#81a1c1";
      magenta = "#b48ead";
      cyan = "#8fbcbb";
      white = "#eceff4";
    };
    indexed_colors = [
      {
        index = 16;
        color = "#d08770";
      }
      {
        index = 17;
        color = "#5e81ac";
      }
    ];
  };

  # Kitty terminal colors
  kitty = {
    foreground = "#D8DEE9";
    background = "#2E3440";
    selection_foreground = "#000000";
    selection_background = "#FFFACD";
    url_color = "#0087BD";
    cursor = "#81A1C1";
    active_tab_foreground = "#000000";
    active_tab_background = "#000000";
    inactive_tab_foreground = "#000000";
    inactive_tab_background = "#000000";
    color0 = "#3B4252";
    color1 = "#BF616A";
    color2 = "#A3BE8C";
    color3 = "#EBCB8B";
    color4 = "#81A1C1";
    color5 = "#B48EAD";
    color6 = "#88C0D0";
    color7 = "#E5E9F0";
    color8 = "#4C566A";
    color9 = "#BF616A";
    color10 = "#A3BE8C";
    color11 = "#EBCB8B";
    color12 = "#81A1C1";
    color13 = "#B48EAD";
    color14 = "#8FBCBB";
    color15 = "#ECEFF4";
  };

  # Ghostty terminal theme
  ghostty = {
    theme = "Nord";
  };

  # VSCode theme name
  vscode = {
    theme = "Nord";
  };

  # Walker launcher colors
  walker = {
    selectedText = "#88C0D0";
    text = "#D8DEE9";
    base = "#2E3440";
    border = "#D8DEE9";
    foreground = "#D8DEE9";
    background = "#2E3440";
  };

  # Waybar colors
  waybar = {
    foreground = "#D8DEE9";
    background = "#2E3440";
  };

  # wlogout power menu colors
  wlogout = {
    backgroundColor = "#2e3440";
    buttonBackground = "#3b4252";
    buttonHoverBackground = "#88c0d0";
    textColor = "#d8dee9";
    textHoverColor = "#2e3440";
  };

  # tmux status bar colors
  tmux = {
    statusBackground = "#2e3440";
    statusForeground = "#d8dee9";
    windowStatusCurrent = "#88c0d0";
    paneActiveBorder = "#88c0d0";
    paneInactiveBorder = "#4c566a";
    messageBackground = "#88c0d0";
    messageForeground = "#2e3440";
  };

  # Mako notification colors
  mako = {
    textColor = "#d8dee9";
    borderColor = "#D8DEE9";
    backgroundColor = "#2e3440";
    progressColor = "#D8DEE9";
  };

  # SwayOSD colors
  swayosd = {
    backgroundColor = "#2E3440";
    borderColor = "#D8DEE9";
    textColor = "#D8DEE9";
  };

  # Hyprlock colors
  hyprlock = {
    general = "#2e3440";
    input = "#2e3440";
    innerColor = "#2e3440cc";
    outerColor = "#d8dee9";
    fontColor = "#d8dee9";
    checkColor = "#88c0d0";
    failColor = "#bf616a";
  };

  # btop system monitor colors
  btop = {
    main_bg = "#2E3440";
    main_fg = "#D8DEE9";
    title = "#8FBCBB";
    hi_fg = "#5E81AC";
    selected_bg = "#4C566A";
    selected_fg = "#ECEFF4";
    inactive_fg = "#4C566A";
    proc_misc = "#5E81AC";
    cpu_box = "#4C566A";
    mem_box = "#4C566A";
    net_box = "#4C566A";
    proc_box = "#4C566A";
    div_line = "#4C566A";
    temp_start = "#81A1C1";
    temp_mid = "#88C0D0";
    temp_end = "#ECEFF4";
    cpu_start = "#81A1C1";
    cpu_mid = "#88C0D0";
    cpu_end = "#ECEFF4";
    free_start = "#81A1C1";
    free_mid = "#88C0D0";
    free_end = "#ECEFF4";
    cached_start = "#81A1C1";
    cached_mid = "#88C0D0";
    cached_end = "#ECEFF4";
    available_start = "#81A1C1";
    available_mid = "#88C0D0";
    available_end = "#ECEFF4";
    used_start = "#81A1C1";
    used_mid = "#88C0D0";
    used_end = "#ECEFF4";
    download_start = "#81A1C1";
    download_mid = "#88C0D0";
    download_end = "#ECEFF4";
    upload_start = "#81A1C1";
    upload_mid = "#88C0D0";
    upload_end = "#ECEFF4";
  };

  # eza file listing colors
  eza = {
    filekinds = {
      normal = "#d8dee9";
      directory = "#81a1c1";
      symlink = "#88c0d0";
      pipe = "#4c566a";
      block_device = "#d08770";
      char_device = "#d08770";
      socket = "#3b4252";
      special = "#b48ead";
      executable = "#a3be8c";
      mount_point = "#8fbcbb";
    };
    perms = {
      user_read = "#d8dee9";
      user_write = "#ebcb8b";
      user_execute_file = "#a3be8c";
      user_execute_other = "#a3be8c";
      group_read = "#d8dee9";
      group_write = "#ebcb8b";
      group_execute = "#a3be8c";
      other_read = "#e5e9f0";
      other_write = "#ebcb8b";
      other_execute = "#a3be8c";
      special_user_file = "#b48ead";
      special_other = "#4c566a";
      attribute = "#d8dee9";
    };
    size = {
      major = "#d8dee9";
      minor = "#88c0d0";
      number_byte = "#d8dee9";
      number_kilo = "#d8dee9";
      number_mega = "#81a1c1";
      number_giga = "#b48ead";
      number_huge = "#b48ead";
      unit_byte = "#d8dee9";
      unit_kilo = "#81a1c1";
      unit_mega = "#b48ead";
      unit_giga = "#b48ead";
      unit_huge = "#8fbcbb";
    };
    users = {
      user_you = "#d8dee9";
      user_root = "#bf616a";
      user_other = "#b48ead";
      group_yours = "#d8dee9";
      group_other = "#4c566a";
      group_root = "#bf616a";
    };
    links = {
      normal = "#88c0d0";
      multi_link_file = "#8fbcbb";
    };
    git = {
      new = "#a3be8c";
      modified = "#ebcb8b";
      deleted = "#bf616a";
      renamed = "#88c0d0";
      typechange = "#b48ead";
      ignored = "#4c566a";
      conflicted = "#bf616a";
    };
    git_repo = {
      branch_main = "#d8dee9";
      branch_other = "#b48ead";
      git_clean = "#a3be8c";
      git_dirty = "#bf616a";
    };
    security_context = {
      colon = "#4c566a";
      user = "#d8dee9";
      role = "#b48ead";
      typ = "#3b4252";
      range = "#b48ead";
    };
    file_type = {
      image = "#ebcb8b";
      video = "#bf616a";
      music = "#a3be8c";
      lossless = "#88c0d0";
      crypto = "#4c566a";
      document = "#d8dee9";
      compressed = "#b48ead";
      temp = "#d08770";
      compiled = "#81a1c1";
      build = "#4c566a";
      source = "#81a1c1";
    };
    punctuation = "#4c566a";
    date = "#ebcb8b";
    inode = "#d8dee9";
    blocks = "#4c566a";
    header = "#d8dee9";
    octal = "#88c0d0";
    flags = "#b48ead";
    symlink_path = "#88c0d0";
    control_char = "#81a1c1";
    broken_symlink = "#bf616a";
    broken_path_overlay = "#4c566a";
  };

  # Browser theme color (RGB format for Chrome/Brave managed policy)
  browser = {
    themeColor = "46,52,64"; # RGB values from primary background #2e3440
  };

  # Fastfetch system info colors
  fastfetch = {
    keyColor = "blue"; # Matches the arctic blue accent theme
  };

  # Wallpapers
  wallpapers = [
    "1-nord.png"
    "2-nord.png"
  ];
}
