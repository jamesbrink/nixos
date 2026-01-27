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

  # Kitty terminal colors
  kitty = {
    foreground = "#c0caf5";
    background = "#1a1b26";
    selection_foreground = "#c0caf5";
    selection_background = "#283457";
    cursor = "#c0caf5";
    cursor_text_color = "#1a1b26";
    url_color = "#73daca";
    active_border_color = "#7aa2f7";
    inactive_border_color = "#292e42";
    active_tab_foreground = "#16161e";
    active_tab_background = "#7aa2f7";
    inactive_tab_foreground = "#545c7e";
    inactive_tab_background = "#292e42";
    color0 = "#15161e";
    color1 = "#f7768e";
    color2 = "#9ece6a";
    color3 = "#e0af68";
    color4 = "#7aa2f7";
    color5 = "#bb9af7";
    color6 = "#7dcfff";
    color7 = "#a9b1d6";
    color8 = "#414868";
    color9 = "#f7768e";
    color10 = "#9ece6a";
    color11 = "#e0af68";
    color12 = "#7aa2f7";
    color13 = "#bb9af7";
    color14 = "#7dcfff";
    color15 = "#c0caf5";
    color16 = "#ff9e64";
    color17 = "#db4b4b";
  };

  # Ghostty terminal theme
  ghostty = {
    theme = "tokyonight_night";
  };

  # Neovim colorscheme
  nvim = {
    colorscheme = "tokyonight";
  };

  # VSCode theme name
  vscode = {
    theme = "Tokyo Night";
    extension = "enkia.tokyo-night";
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

  # wlogout power menu colors
  wlogout = {
    backgroundColor = "#1a1b26";
    buttonBackground = "#24283b";
    buttonHoverBackground = "#33ccff";
    textColor = "#a9b1d6";
    textHoverColor = "#1a1b26";
  };

  # tmux status bar colors
  tmux = {
    statusBackground = "#1a1b26";
    statusForeground = "#a9b1d6";
    windowStatusCurrent = "#7aa2f7";
    paneActiveBorder = "#33ccff";
    paneInactiveBorder = "#595959";
    messageBackground = "#7aa2f7";
    messageForeground = "#1a1b26";
  };

  # Mako notification colors
  mako = {
    textColor = "#a9b1d6";
    borderColor = "#33ccff";
    backgroundColor = "#1a1b26";
    progressColor = "#a9b1d6";
  };

  # SwayOSD colors
  swayosd = {
    backgroundColor = "#1a1b26";
    borderColor = "#33ccff";
    textColor = "#a9b1d6";
  };

  # Hyprlock colors
  hyprlock = {
    general = "#1a1b26";
    input = "#1a1b26";
    innerColor = "#1a1b26cc";
    outerColor = "#cdd6f4";
    fontColor = "#cdd6f4";
    checkColor = "#449dab";
    failColor = "#f7768e";
  };

  # btop system monitor colors
  btop = {
    main_bg = "#1a1b26";
    main_fg = "#cfc9c2";
    title = "#cfc9c2";
    hi_fg = "#7dcfff";
    selected_bg = "#414868";
    selected_fg = "#cfc9c2";
    inactive_fg = "#565f89";
    proc_misc = "#7dcfff";
    cpu_box = "#565f89";
    mem_box = "#565f89";
    net_box = "#565f89";
    proc_box = "#565f89";
    div_line = "#565f89";
    temp_start = "#9ece6a";
    temp_mid = "#e0af68";
    temp_end = "#f7768e";
    cpu_start = "#9ece6a";
    cpu_mid = "#e0af68";
    cpu_end = "#f7768e";
    free_start = "#9ece6a";
    free_mid = "#e0af68";
    free_end = "#f7768e";
    cached_start = "#9ece6a";
    cached_mid = "#e0af68";
    cached_end = "#f7768e";
    available_start = "#9ece6a";
    available_mid = "#e0af68";
    available_end = "#f7768e";
    used_start = "#9ece6a";
    used_mid = "#e0af68";
    used_end = "#f7768e";
    download_start = "#9ece6a";
    download_mid = "#e0af68";
    download_end = "#f7768e";
    upload_start = "#9ece6a";
    upload_mid = "#e0af68";
    upload_end = "#f7768e";
  };

  # eza file listing colors
  eza = {
    filekinds = {
      normal = "#c0caf5";
      directory = "#7aa2f7";
      symlink = "#2ac3de";
      pipe = "#414868";
      block_device = "#e0af68";
      char_device = "#e0af68";
      socket = "#414868";
      special = "#9d7cd8";
      executable = "#9ece6a";
      mount_point = "#b4f9f8";
    };
    perms = {
      user_read = "#2ac3de";
      user_write = "#bb9af7";
      user_execute_file = "#9ece6a";
      user_execute_other = "#9ece6a";
      group_read = "#2ac3de";
      group_write = "#ff9e64";
      group_execute = "#9ece6a";
      other_read = "#2ac3de";
      other_write = "#ff007c";
      other_execute = "#9ece6a";
      special_user_file = "#ff007c";
      special_other = "#db4b4b";
      attribute = "#737aa2";
    };
    size = {
      major = "#2ac3de";
      minor = "#9d7cd8";
      number_byte = "#a9b1d6";
      number_kilo = "#89ddff";
      number_mega = "#2ac3de";
      number_giga = "#ff9e64";
      number_huge = "#ff007c";
      unit_byte = "#a9b1d6";
      unit_kilo = "#89ddff";
      unit_mega = "#2ac3de";
      unit_giga = "#ff9e64";
      unit_huge = "#ff007c";
    };
    users = {
      user_you = "#3d59a1";
      user_root = "#bb9af7";
      user_other = "#2ac3de";
      group_yours = "#89ddff";
      group_root = "#bb9af7";
      group_other = "#c0caf5";
    };
    links = {
      normal = "#89ddff";
      multi_link_file = "#2ac3de";
    };
    git = {
      new = "#9ece6a";
      modified = "#bb9af7";
      deleted = "#db4b4b";
      renamed = "#2ac3de";
      typechange = "#2ac3de";
      ignored = "#545c7e";
      conflicted = "#ff9e64";
    };
    git_repo = {
      branch_main = "#737aa2";
      branch_other = "#b4f9f8";
      git_clean = "#292e42";
      git_dirty = "#bb9af7";
    };
    security_context = {
      colon = "#545c7e";
      user = "#737aa2";
      role = "#2ac3de";
      typ = "#3d59a1";
      range = "#9d7cd8";
    };
    file_type = {
      image = "#89ddff";
      video = "#b4f9f8";
      music = "#73daca";
      lossless = "#41a6b5";
      crypto = "#db4b4b";
      document = "#a9b1d6";
      compressed = "#ff9e64";
      temp = "#737aa2";
      compiled = "#737aa2";
      build = "#1abc9c";
      source = "#bb9af7";
    };
    punctuation = "#414868";
    date = "#e0af68";
    inode = "#737aa2";
    blocks = "#737aa2";
    header = "#a9b1d6";
    octal = "#ff9e64";
    flags = "#9d7cd8";
    symlink_path = "#89ddff";
    control_char = "#ff9e64";
    broken_symlink = "#ff007c";
    broken_path_overlay = "#ff007c";
  };

  # Browser theme color (RGB format for Chrome/Brave managed policy)
  browser = {
    themeColor = "26,27,38"; # RGB values from primary background #1a1b26
  };

  # Fastfetch system info colors
  fastfetch = {
    keyColor = "cyan"; # Matches the blue/cyan accent theme
  };

  # Wallpapers
  wallpapers = [
    "1-scenery-pink-lakeside-sunset-lake-landscape-scenic-panorama-7680x3215-144.png"
    "2-Pawel-Czerwinski-Abstract-Purple-Blue.jpg"
    "3-Milad-Fakurian-Abstract-Purple-Blue.jpg"
  ];
}
