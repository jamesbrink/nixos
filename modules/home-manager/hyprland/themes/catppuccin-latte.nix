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

  # Kitty terminal colors
  kitty = {
    foreground = "#4C4F69";
    background = "#EFF1F5";
    selection_foreground = "#EFF1F5";
    selection_background = "#DC8A78";
    cursor = "#DC8A78";
    cursor_text_color = "#EFF1F5";
    url_color = "#7287FD";
    active_border_color = "#8839EF";
    inactive_border_color = "#7C7F93";
    active_tab_foreground = "#EFF1F5";
    active_tab_background = "#8839EF";
    inactive_tab_foreground = "#4C4F69";
    inactive_tab_background = "#9CA0B0";
    color0 = "#4C4F69";
    color1 = "#D20F39";
    color2 = "#40A02B";
    color3 = "#DF8E1D";
    color4 = "#1E66F5";
    color5 = "#EA76CB";
    color6 = "#179299";
    color7 = "#ACB0BE";
    color8 = "#6C6F85";
    color9 = "#D20F39";
    color10 = "#40A02B";
    color11 = "#DF8E1D";
    color12 = "#1E66F5";
    color13 = "#EA76CB";
    color14 = "#179299";
    color15 = "#ACB0BE";
  };

  # Ghostty terminal theme
  ghostty = {
    theme = "Catppuccin Latte";
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

  # btop system monitor colors
  btop = {
    main_bg = "#eff1f5";
    main_fg = "#4c4f69";
    title = "#4c4f69";
    hi_fg = "#1e66f5";
    selected_bg = "#bcc0cc";
    selected_fg = "#1e66f5";
    inactive_fg = "#8c8fa1";
    graph_text = "#dc8a78";
    meter_bg = "#bcc0cc";
    proc_misc = "#dc8a78";
    cpu_box = "#8839ef";
    mem_box = "#40a02b";
    net_box = "#e64553";
    proc_box = "#1e66f5";
    div_line = "#9ca0b0";
    temp_start = "#40a02b";
    temp_mid = "#df8e1d";
    temp_end = "#d20f39";
    cpu_start = "#179299";
    cpu_mid = "#209fb5";
    cpu_end = "#7287fd";
    free_start = "#8839ef";
    free_mid = "#7287fd";
    free_end = "#1e66f5";
    cached_start = "#209fb5";
    cached_mid = "#1e66f5";
    cached_end = "#7287fd";
    available_start = "#fe640b";
    available_mid = "#e64553";
    available_end = "#d20f39";
    used_start = "#40a02b";
    used_mid = "#179299";
    used_end = "#04a5e5";
    download_start = "#fe640b";
    download_mid = "#e64553";
    download_end = "#d20f39";
    upload_start = "#40a02b";
    upload_mid = "#179299";
    upload_end = "#04a5e5";
    process_start = "#209fb5";
    process_mid = "#7287fd";
    process_end = "#8839ef";
  };

  # eza file listing colors
  eza = {
    filekinds = {
      normal = "#4c4f69";
      directory = "#1e66f5";
      symlink = "#179299";
      pipe = "#6c6f85";
      block_device = "#fe640b";
      char_device = "#fe640b";
      socket = "#9ca0b0";
      special = "#ea76cb";
      executable = "#40a02b";
      mount_point = "#04a5e5";
    };
    perms = {
      user_read = "#4c4f69";
      user_write = "#df8e1d";
      user_execute_file = "#40a02b";
      user_execute_other = "#40a02b";
      group_read = "#5c5f77";
      group_write = "#df8e1d";
      group_execute = "#40a02b";
      other_read = "#6c6f85";
      other_write = "#df8e1d";
      other_execute = "#40a02b";
      special_user_file = "#ea76cb";
      special_other = "#9ca0b0";
      attribute = "#7c7f93";
    };
    size = {
      major = "#7c7f93";
      minor = "#179299";
      number_byte = "#4c4f69";
      number_kilo = "#5c5f77";
      number_mega = "#1e66f5";
      number_giga = "#ea76cb";
      number_huge = "#ea76cb";
      unit_byte = "#7c7f93";
      unit_kilo = "#1e66f5";
      unit_mega = "#ea76cb";
      unit_giga = "#ea76cb";
      unit_huge = "#04a5e5";
    };
    users = {
      user_you = "#4c4f69";
      user_root = "#d20f39";
      user_other = "#ea76cb";
      group_yours = "#5c5f77";
      group_other = "#8c8fa1";
      group_root = "#d20f39";
    };
    links = {
      normal = "#179299";
      multi_link_file = "#04a5e5";
    };
    git = {
      new = "#40a02b";
      modified = "#df8e1d";
      deleted = "#d20f39";
      renamed = "#209fb5";
      typechange = "#dd7878";
      ignored = "#8c8fa1";
      conflicted = "#e64553";
    };
    git_repo = {
      branch_main = "#4c4f69";
      branch_other = "#ea76cb";
      git_clean = "#40a02b";
      git_dirty = "#d20f39";
    };
    security_context = {
      colon = "#8c8fa1";
      user = "#5c5f77";
      role = "#ea76cb";
      typ = "#9ca0b0";
      range = "#ea76cb";
    };
    file_type = {
      image = "#df8e1d";
      video = "#d20f39";
      music = "#40a02b";
      lossless = "#209fb5";
      crypto = "#9ca0b0";
      document = "#4c4f69";
      compressed = "#dd7878";
      temp = "#e64553";
      compiled = "#04a5e5";
      build = "#9ca0b0";
      source = "#1e66f5";
    };
    punctuation = "#8c8fa1";
    date = "#df8e1d";
    inode = "#7c7f93";
    blocks = "#acb0be";
    header = "#4c4f69";
    octal = "#209fb5";
    flags = "#ea76cb";
    symlink_path = "#179299";
    control_char = "#04a5e5";
    broken_symlink = "#d20f39";
    broken_path_overlay = "#9ca0b0";
  };

  # Browser theme color (RGB format for Chrome/Brave managed policy)
  browser = {
    themeColor = "239,241,245"; # RGB values from primary background #eff1f5
  };

  # Fastfetch system info colors
  fastfetch = {
    keyColor = "blue"; # Matches the light theme blue accent
  };

  # Wallpapers (synced from external/omarchy; overrides may be placed in modules/home-manager/hyprland/wallpapers)
  wallpapers = [
    "1-catppuccin-latte.png"
  ];
}
