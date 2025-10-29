# Matte Black theme
{
  name = "matte-black";
  displayName = "Matte Black";

  # GTK/Icon theme package names (resolved by main module)
  gtk = {
    themeName = "Adwaita-dark";
    themePackage = "adwaita-icon-theme"; # Built-in, no separate package needed
    iconName = "Papirus-Dark";
    iconPackage = "papirus-icon-theme";
  };

  # Hyprland colors
  hyprland = {
    activeBorder = "rgb(8A8A8D)";
    inactiveBorder = "rgba(333333aa)";
  };

  # Alacritty color scheme
  alacritty = {
    primary = {
      background = "#121212";
      foreground = "#bebebe";
    };
    normal = {
      black = "#333333";
      red = "#D35F5F";
      green = "#FFC107";
      yellow = "#b91c1c";
      blue = "#e68e0d";
      magenta = "#D35F5F";
      cyan = "#bebebe";
      white = "#bebebe";
    };
    bright = {
      black = "#8a8a8d";
      red = "#B91C1C";
      green = "#FFC107";
      yellow = "#b90a0a";
      blue = "#f59e0b";
      magenta = "#B91C1C";
      cyan = "#eaeaea";
      white = "#ffffff";
    };
    indexed_colors = [ ];
  };

  # VSCode theme name
  vscode = {
    theme = "Matte Black";
  };

  # Walker launcher colors
  walker = {
    selectedText = "#B91C1C";
    text = "#EAEAEA";
    base = "#121212";
    border = "#EAEAEA88";
    foreground = "#EAEAEA";
    background = "#121212";
  };

  # Waybar colors
  waybar = {
    foreground = "#EAEAEA";
    background = "#121212";
  };

  # wlogout power menu colors
  wlogout = {
    backgroundColor = "#121212";
    buttonBackground = "#1f1f1f";
    buttonHoverBackground = "#D35F5F";
    textColor = "#bebebe";
    textHoverColor = "#121212";
  };

  # tmux status bar colors
  tmux = {
    statusBackground = "#121212";
    statusForeground = "#bebebe";
    windowStatusCurrent = "#FFC107";
    paneActiveBorder = "#8a8a8d";
    paneInactiveBorder = "#333333";
    messageBackground = "#FFC107";
    messageForeground = "#121212";
  };

  # Mako notification colors
  mako = {
    textColor = "#8a8a8d";
    borderColor = "#8A8A8D";
    backgroundColor = "#1e1e1e";
    progressColor = "#8A8A8D";
  };

  # SwayOSD colors
  swayosd = {
    backgroundColor = "#121212";
    borderColor = "#8A8A8D";
    textColor = "#8A8A8D";
  };

  # Hyprlock colors
  hyprlock = {
    general = "#0c0c0c";
    input = "#0c0c0c";
    innerColor = "#8a8a8d4d";
    outerColor = "#eaeaea80";
    fontColor = "#eaeaea";
    checkColor = "#f59e0b";
    failColor = "#B91C1C";
  };

  # btop system monitor colors
  btop = {
    main_bg = "";
    main_fg = "#EAEAEA";
    title = "#8a8a8d";
    hi_fg = "#f59e0b";
    selected_bg = "#f59e0b";
    selected_fg = "#EAEAEA";
    inactive_fg = "#333333";
    proc_misc = "#8a8a8d";
    cpu_box = "#8a8a8d";
    mem_box = "#8a8a8d";
    net_box = "#8a8a8d";
    proc_box = "#8a8a8d";
    div_line = "#8a8a8d";
    temp_start = "#8a8a8d";
    temp_mid = "#f59e0b";
    temp_end = "#b91c1c";
    cpu_start = "#8a8a8d";
    cpu_mid = "#f59e0b";
    cpu_end = "#b91c1c";
    free_start = "#8a8a8d";
    free_mid = "#f59e0b";
    free_end = "#b91c1c";
    cached_start = "#8a8a8d";
    cached_mid = "#f59e0b";
    cached_end = "#b91c1c";
    available_start = "#8a8a8d";
    available_mid = "#f59e0b";
    available_end = "#b91c1c";
    used_start = "#8a8a8d";
    used_mid = "#f59e0b";
    used_end = "#b91c1c";
    download_start = "#8a8a8d";
    download_mid = "#f59e0b";
    download_end = "#b91c1c";
    upload_start = "#8a8a8d";
    upload_mid = "#f59e0b";
    upload_end = "#b91c1c";
  };

  # eza file listing colors
  eza = {
    filekinds = {
      normal = "#bebebe";
      directory = "#e68e0d";
      symlink = "#8a8a8d";
      pipe = "#555555";
      block_device = "#D35F5F";
      char_device = "#D35F5F";
      socket = "#1a1a1a";
      special = "#B91C1C";
      executable = "#FFC107";
      mount_point = "#f59e0b";
    };
    perms = {
      user_read = "#bebebe";
      user_write = "#FFC107";
      user_execute_file = "#FFC107";
      user_execute_other = "#FFC107";
      group_read = "#bebebe";
      group_write = "#FFC107";
      group_execute = "#FFC107";
      other_read = "#eaeaea";
      other_write = "#FFC107";
      other_execute = "#FFC107";
      special_user_file = "#B91C1C";
      special_other = "#555555";
      attribute = "#8a8a8d";
    };
    size = {
      major = "#bebebe";
      minor = "#8a8a8d";
      number_byte = "#bebebe";
      number_kilo = "#bebebe";
      number_mega = "#e68e0d";
      number_giga = "#B91C1C";
      number_huge = "#B91C1C";
      unit_byte = "#bebebe";
      unit_kilo = "#e68e0d";
      unit_mega = "#B91C1C";
      unit_giga = "#B91C1C";
      unit_huge = "#f59e0b";
    };
    users = {
      user_you = "#bebebe";
      user_root = "#b91c1c";
      user_other = "#B91C1C";
      group_yours = "#bebebe";
      group_other = "#555555";
      group_root = "#b91c1c";
    };
    links = {
      normal = "#8a8a8d";
      multi_link_file = "#f59e0b";
    };
    git = {
      new = "#FFC107";
      modified = "#f59e0b";
      deleted = "#b91c1c";
      renamed = "#8a8a8d";
      typechange = "#B91C1C";
      ignored = "#555555";
      conflicted = "#D35F5F";
    };
    git_repo = {
      branch_main = "#bebebe";
      branch_other = "#B91C1C";
      git_clean = "#FFC107";
      git_dirty = "#b91c1c";
    };
    security_context = {
      colon = "#555555";
      user = "#bebebe";
      role = "#B91C1C";
      typ = "#1a1a1a";
      range = "#B91C1C";
    };
    file_type = {
      image = "#FFC107";
      video = "#b91c1c";
      music = "#FFC107";
      lossless = "#8a8a8d";
      crypto = "#555555";
      document = "#bebebe";
      compressed = "#B91C1C";
      temp = "#D35F5F";
      compiled = "#e68e0d";
      build = "#555555";
      source = "#e68e0d";
    };
    punctuation = "#555555";
    date = "#FFC107";
    inode = "#8a8a8d";
    blocks = "#555555";
    header = "#bebebe";
    octal = "#8a8a8d";
    flags = "#B91C1C";
    symlink_path = "#8a8a8d";
    control_char = "#e68e0d";
    broken_symlink = "#b91c1c";
    broken_path_overlay = "#555555";
  };

  # Browser theme color (RGB format for Chrome/Brave managed policy)
  browser = {
    themeColor = "18,18,18"; # RGB values from primary background #121212
  };

  # Fastfetch system info colors
  fastfetch = {
    keyColor = "white"; # Matches the monochrome theme
  };

  # Wallpapers
  # To add wallpapers for this theme:
  # 1. Create directory: mkdir -p modules/home-manager/hyprland/wallpapers/matte-black
  # 2. Add image files (JPG or PNG) to the directory
  # 3. List them here: wallpapers = [ "1-my-wallpaper.jpg" "2-another.png" ];
  # 4. Use Super+Ctrl+Space to rotate through backgrounds
  wallpapers = [ ];
}
