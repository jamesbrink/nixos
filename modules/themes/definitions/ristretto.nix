# Ristretto theme (Monokai-inspired)
{
  name = "ristretto";
  displayName = "Ristretto";

  # GTK/Icon theme package names (resolved by main module)
  gtk = {
    themeName = "Adwaita-dark";
    themePackage = "adwaita-icon-theme"; # Built-in, no separate package needed
    iconName = "Papirus-Dark";
    iconPackage = "papirus-icon-theme";
  };

  # Hyprland colors
  hyprland = {
    activeBorder = "rgb(e6d9db)";
    inactiveBorder = "rgba(72696aaa)";
  };

  # Alacritty color scheme
  alacritty = {
    primary = {
      background = "#2c2525";
      foreground = "#e6d9db";
    };
    normal = {
      black = "#72696a";
      red = "#fd6883";
      green = "#adda78";
      yellow = "#f9cc6c";
      blue = "#f38d70";
      magenta = "#a8a9eb";
      cyan = "#85dacc";
      white = "#e6d9db";
    };
    bright = {
      black = "#948a8b";
      red = "#ff8297";
      green = "#c8e292";
      yellow = "#fcd675";
      blue = "#f8a788";
      magenta = "#bebffd";
      cyan = "#9bf1e1";
      white = "#f1e5e7";
    };
    indexed_colors = [ ];
  };

  # Kitty terminal colors
  kitty = {
    foreground = "#e6d9db";
    background = "#2c2525";
    selection_foreground = "#e6d9db";
    selection_background = "#403e41";
    cursor = "#c3b7b8";
    cursor_text_color = "#c3b7b8";
    url_color = "#e6d9db";
    active_border_color = "#e6d9db";
    inactive_border_color = "#595959";
    active_tab_foreground = "#2c2525";
    active_tab_background = "#f9cc6c";
    inactive_tab_foreground = "#e6d9db";
    inactive_tab_background = "#2c2525";
    color0 = "#72696a";
    color1 = "#fd6883";
    color2 = "#adda78";
    color3 = "#f9cc6c";
    color4 = "#f38d70";
    color5 = "#a8a9eb";
    color6 = "#85dacc";
    color7 = "#e6d9db";
    color8 = "#948a8b";
    color9 = "#ff8297";
    color10 = "#c8e292";
    color11 = "#fcd675";
    color12 = "#f8a788";
    color13 = "#bebffd";
    color14 = "#9bf1e1";
    color15 = "#f1e5e7";
  };

  # Ghostty terminal theme
  ghostty = {
    theme = "Monokai Pro Ristretto";
  };

  # Neovim colorscheme
  nvim = {
    colorscheme = "monokai-pro-ristretto";
  };

  # VSCode theme name
  vscode = {
    theme = "Monokai Pro (Filter Ristretto)";
    extension = "monokai.theme-monokai-pro-vscode";
  };

  # Walker launcher colors
  walker = {
    selectedText = "#fabd2f";
    text = "#e6d9db";
    base = "#2c2525";
    border = "#e6d9db";
    foreground = "#e6d9db";
    background = "#2c2525";
  };

  # Waybar colors
  waybar = {
    foreground = "#e6d9db";
    background = "#2c2525";
  };

  # wlogout power menu colors
  wlogout = {
    backgroundColor = "#2c2525";
    buttonBackground = "#3a3030";
    buttonHoverBackground = "#a8a9eb";
    textColor = "#e6d9db";
    textHoverColor = "#2c2525";
  };

  # tmux status bar colors
  tmux = {
    statusBackground = "#2c2525";
    statusForeground = "#e6d9db";
    windowStatusCurrent = "#a8a9eb";
    paneActiveBorder = "#a8a9eb";
    paneInactiveBorder = "#72696a";
    messageBackground = "#a8a9eb";
    messageForeground = "#2c2525";
  };

  # Mako notification colors
  mako = {
    textColor = "#e6d9db";
    borderColor = "#e6d9db";
    backgroundColor = "#2c2525";
    progressColor = "#c3b7b8";
  };

  # SwayOSD colors
  swayosd = {
    backgroundColor = "#2c2525";
    borderColor = "#c3b7b8";
    textColor = "#c3b7b8";
  };

  # Hyprlock colors
  hyprlock = {
    general = "#2c2525";
    input = "#2c2525";
    innerColor = "#2c2525cc";
    outerColor = "#e6d9db";
    fontColor = "#e6d9db";
    checkColor = "#fd6883";
    failColor = "#fd6883";
  };

  # btop system monitor colors
  btop = {
    main_bg = "#2c2421";
    main_fg = "#e6d9db";
    title = "#e6d9db";
    hi_fg = "#fd6883";
    selected_bg = "#3d2f2a";
    selected_fg = "#e6d9db";
    inactive_fg = "#72696a";
    proc_misc = "#adda78";
    cpu_box = "#5b4a45";
    mem_box = "#5b4a45";
    net_box = "#5b4a45";
    proc_box = "#5b4a45";
    div_line = "#72696a";
    temp_start = "#a8a9eb";
    temp_mid = "#f38d70";
    temp_end = "#fd6a85";
    cpu_start = "#adda78";
    cpu_mid = "#f9cc6c";
    cpu_end = "#fd6883";
    free_start = "#5b4a45";
    free_mid = "#adda78";
    free_end = "#c5e2a3";
    cached_start = "#5b4a45";
    cached_mid = "#85dacc";
    cached_end = "#b3e8dd";
    available_start = "#5b4a45";
    available_mid = "#f9cc6c";
    available_end = "#fce2a3";
    used_start = "#5b4a45";
    used_mid = "#fd6a85";
    used_end = "#feb5c7";
    download_start = "#3d2f2a";
    download_mid = "#a8a9eb";
    download_end = "#c5c6f0";
    upload_start = "#3d2f2a";
    upload_mid = "#fd6a85";
    upload_end = "#feb5c7";
  };

  # eza file listing colors
  eza = {
    filekinds = {
      normal = "#e6d9db";
      directory = "#f38d70";
      symlink = "#85dacc";
      pipe = "#72696a";
      block_device = "#fd6883";
      char_device = "#fd6883";
      socket = "#403838";
      special = "#a8a9eb";
      executable = "#adda78";
      mount_point = "#9bf1e1";
    };
    perms = {
      user_read = "#e6d9db";
      user_write = "#f9cc6c";
      user_execute_file = "#adda78";
      user_execute_other = "#adda78";
      group_read = "#e6d9db";
      group_write = "#f9cc6c";
      group_execute = "#adda78";
      other_read = "#f1e5e7";
      other_write = "#f9cc6c";
      other_execute = "#adda78";
      special_user_file = "#a8a9eb";
      special_other = "#72696a";
      attribute = "#e6d9db";
    };
    size = {
      major = "#e6d9db";
      minor = "#85dacc";
      number_byte = "#e6d9db";
      number_kilo = "#e6d9db";
      number_mega = "#f38d70";
      number_giga = "#a8a9eb";
      number_huge = "#a8a9eb";
      unit_byte = "#e6d9db";
      unit_kilo = "#f38d70";
      unit_mega = "#a8a9eb";
      unit_giga = "#a8a9eb";
      unit_huge = "#9bf1e1";
    };
    users = {
      user_you = "#e6d9db";
      user_root = "#fd6883";
      user_other = "#a8a9eb";
      group_yours = "#e6d9db";
      group_other = "#72696a";
      group_root = "#fd6883";
    };
    links = {
      normal = "#85dacc";
      multi_link_file = "#9bf1e1";
    };
    git = {
      new = "#adda78";
      modified = "#f9cc6c";
      deleted = "#fd6883";
      renamed = "#85dacc";
      typechange = "#a8a9eb";
      ignored = "#72696a";
      conflicted = "#ff8297";
    };
    git_repo = {
      branch_main = "#e6d9db";
      branch_other = "#a8a9eb";
      git_clean = "#adda78";
      git_dirty = "#fd6883";
    };
    security_context = {
      colon = "#72696a";
      user = "#e6d9db";
      role = "#a8a9eb";
      typ = "#403838";
      range = "#a8a9eb";
    };
    file_type = {
      image = "#f9cc6c";
      video = "#fd6883";
      music = "#adda78";
      lossless = "#85dacc";
      crypto = "#72696a";
      document = "#e6d9db";
      compressed = "#a8a9eb";
      temp = "#ff8297";
      compiled = "#f8a788";
      build = "#72696a";
      source = "#f38d70";
    };
    punctuation = "#72696a";
    date = "#f9cc6c";
    inode = "#e6d9db";
    blocks = "#72696a";
    header = "#e6d9db";
    octal = "#85dacc";
    flags = "#a8a9eb";
    symlink_path = "#85dacc";
    control_char = "#f38d70";
    broken_symlink = "#fd6883";
    broken_path_overlay = "#72696a";
  };

  # Browser theme color (RGB format for Chrome/Brave managed policy)
  browser = {
    themeColor = "44,37,37"; # RGB values from primary background #2c2525
  };

  # Fastfetch system info colors
  fastfetch = {
    keyColor = "magenta"; # Matches the monokai accent theme
  };

  # Wallpapers
  wallpapers = [
    "1-ristretto.jpg"
    "2-ristretto.jpg"
    "3-ristretto.jpg"
  ];
}
