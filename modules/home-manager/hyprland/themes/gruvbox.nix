# Gruvbox Material Dark theme
{
  name = "gruvbox";
  displayName = "Gruvbox Material";

  # GTK/Icon theme package names
  gtk = {
    themeName = "Gruvbox-Dark";
    themePackage = "gruvbox-gtk-theme";
    iconName = "Papirus-Dark";
    iconPackage = "papirus-icon-theme";
  };

  # Hyprland colors
  hyprland = {
    activeBorder = "rgb(a89984)";
    inactiveBorder = "rgba(595959aa)";
  };

  # Alacritty color scheme
  alacritty = {
    primary = {
      background = "#282828";
      foreground = "#d4be98";
    };
    normal = {
      black = "#3c3836";
      red = "#ea6962";
      green = "#a9b665";
      yellow = "#d8a657";
      blue = "#7daea3";
      magenta = "#d3869b";
      cyan = "#89b482";
      white = "#d4be98";
    };
    bright = {
      black = "#3c3836";
      red = "#ea6962";
      green = "#a9b665";
      yellow = "#d8a657";
      blue = "#7daea3";
      magenta = "#d3869b";
      cyan = "#89b482";
      white = "#d4be98";
    };
    indexed_colors = [
      {
        index = 16;
        color = "#e78a4e";
      }
      {
        index = 17;
        color = "#d65d0e";
      }
    ];
  };

  # VSCode theme name
  vscode = {
    theme = "Gruvbox Material Dark";
  };

  # Walker launcher colors
  walker = {
    selectedText = "#fabd2f";
    text = "#ebdbb2";
    base = "#282828";
    border = "#ebdbb2";
    foreground = "#ebdbb2";
    background = "#282828";
  };

  # Waybar colors
  waybar = {
    foreground = "#ebdbb2";
    background = "#282828";
  };

  # wlogout power menu colors
  wlogout = {
    backgroundColor = "#282828";
    buttonBackground = "#3c3836";
    buttonHoverBackground = "#d8a657";
    textColor = "#d4be98";
    textHoverColor = "#282828";
  };

  # tmux status bar colors
  tmux = {
    statusBackground = "#282828";
    statusForeground = "#d4be98";
    windowStatusCurrent = "#d8a657";
    paneActiveBorder = "#a89984";
    paneInactiveBorder = "#504945";
    messageBackground = "#d8a657";
    messageForeground = "#282828";
  };

  # Mako notification colors
  mako = {
    textColor = "#d4be98";
    borderColor = "#a89984";
    backgroundColor = "#282828";
    progressColor = "#ebdbb2";
  };

  # SwayOSD colors
  swayosd = {
    backgroundColor = "#282828";
    borderColor = "#a89984";
    textColor = "#ebdbb2";
  };

  # Hyprlock colors
  hyprlock = {
    general = "#282828";
    input = "#282828";
    innerColor = "#282828cc";
    outerColor = "#d4be98";
    fontColor = "#d4be98";
    checkColor = "#d6995c";
    failColor = "#ea6962";
  };

  # btop system monitor colors
  btop = {
    main_bg = "#282828";
    main_fg = "#a89984";
    title = "#ebdbb2";
    hi_fg = "#d79921";
    selected_bg = "#282828";
    selected_fg = "#fabd2f";
    inactive_fg = "#282828";
    graph_text = "#585858";
    proc_misc = "#98971a";
    cpu_box = "#a89984";
    mem_box = "#a89984";
    net_box = "#a89984";
    proc_box = "#a89984";
    div_line = "#a89984";
    temp_start = "#458588";
    temp_mid = "#d3869b";
    temp_end = "#fb4394";
    cpu_start = "#b8bb26";
    cpu_mid = "#d79921";
    cpu_end = "#fb4934";
    free_start = "#4e5900";
    free_mid = "#98971a";
    free_end = "#b8bb26";
    cached_start = "#458588";
    cached_mid = "#7daea3";
    cached_end = "#83a598";
    available_start = "#d79921";
    available_mid = "#e78a4e";
    available_end = "#fabd2f";
    used_start = "#cc241d";
    used_mid = "#ea6962";
    used_end = "#fb4934";
    download_start = "#3d4070";
    download_mid = "#6c71c4";
    download_end = "#a3a8f7";
    upload_start = "#701c45";
    upload_mid = "#b16286";
    upload_end = "#d3869b";
  };

  # eza file listing colors
  eza = {
    filekinds = {
      normal = "#ebdbb2";
      directory = "#83a598";
      symlink = "#8ec07c";
      pipe = "#928374";
      block_device = "#fb4934";
      char_device = "#fb4934";
      socket = "#665c54";
      special = "#d3869b";
      executable = "#b8bb26";
      mount_point = "#fe8019";
    };
    perms = {
      user_read = "#ebdbb2";
      user_write = "#fabd2f";
      user_execute_file = "#b8bb26";
      user_execute_other = "#b8bb26";
      group_read = "#ebdbb2";
      group_write = "#fabd2f";
      group_execute = "#b8bb26";
      other_read = "#bdae93";
      other_write = "#fabd2f";
      other_execute = "#b8bb26";
      special_user_file = "#d3869b";
      special_other = "#928374";
      attribute = "#bdae93";
    };
    size = {
      major = "#bdae93";
      minor = "#8ec07c";
      number_byte = "#ebdbb2";
      number_kilo = "#ebdbb2";
      number_mega = "#83a598";
      number_giga = "#d3869b";
      number_huge = "#d3869b";
      unit_byte = "#bdae93";
      unit_kilo = "#83a598";
      unit_mega = "#d3869b";
      unit_giga = "#d3869b";
      unit_huge = "#fe8019";
    };
    users = {
      user_you = "#ebdbb2";
      user_root = "#fb4934";
      user_other = "#d3869b";
      group_yours = "#ebdbb2";
      group_other = "#928374";
      group_root = "#fb4934";
    };
    links = {
      normal = "#8ec07c";
      multi_link_file = "#fe8019";
    };
    git = {
      new = "#b8bb26";
      modified = "#fabd2f";
      deleted = "#fb4934";
      renamed = "#8ec07c";
      typechange = "#d3869b";
      ignored = "#928374";
      conflicted = "#cc241d";
    };
    git_repo = {
      branch_main = "#ebdbb2";
      branch_other = "#d3869b";
      git_clean = "#b8bb26";
      git_dirty = "#fb4934";
    };
    security_context = {
      colon = "#928374";
      user = "#ebdbb2";
      role = "#d3869b";
      typ = "#665c54";
      range = "#d3869b";
    };
    file_type = {
      image = "#fabd2f";
      video = "#fb4934";
      music = "#b8bb26";
      lossless = "#8ec07c";
      crypto = "#928374";
      document = "#ebdbb2";
      compressed = "#d3869b";
      temp = "#cc241d";
      compiled = "#83a598";
      build = "#928374";
      source = "#83a598";
    };
    punctuation = "#928374";
    date = "#fabd2f";
    inode = "#bdae93";
    blocks = "#a89984";
    header = "#ebdbb2";
    octal = "#8ec07c";
    flags = "#d3869b";
    symlink_path = "#8ec07c";
    control_char = "#83a598";
    broken_symlink = "#fb4934";
    broken_path_overlay = "#928374";
  };

  # Browser theme color (RGB format for Chrome/Brave managed policy)
  browser = {
    themeColor = "40,40,40"; # RGB values from primary background #282828
  };

  # Fastfetch system info colors
  fastfetch = {
    keyColor = "yellow"; # Matches the retro warm accent theme
  };

  # Wallpapers
  wallpapers = [
    "1-grubox.jpg"
  ];
}
