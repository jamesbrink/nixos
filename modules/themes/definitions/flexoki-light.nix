# Flexoki Light theme
{
  name = "flexoki-light";
  displayName = "Flexoki Light";

  # GTK/Icon theme package names
  gtk = {
    themeName = "Adwaita"; # Light mode preference
    themePackage = "gnome-themes-extra";
    iconName = "Yaru-blue";
    iconPackage = "yaru-theme";
  };

  # Hyprland colors
  hyprland = {
    activeBorder = "rgba(205EA6ee)";
    inactiveBorder = "rgba(595959aa)";
  };

  # Alacritty color scheme
  alacritty = {
    primary = {
      background = "#FFFCF0";
      foreground = "#100F0F";
    };
    normal = {
      black = "#100F0F";
      red = "#D14D41";
      green = "#879A39";
      yellow = "#D0A215";
      blue = "#205EA6";
      magenta = "#CE5D97";
      cyan = "#3AA99F";
      white = "#FFFCF0";
    };
    bright = {
      black = "#100F0F";
      red = "#D14D41";
      green = "#879A39";
      yellow = "#D0A215";
      blue = "#205EA6";
      magenta = "#CE5D97";
      cyan = "#3AA99F";
      white = "#FFFCF0";
    };
    indexed_colors = [ ];
  };

  # Kitty terminal colors
  kitty = {
    foreground = "#100F0F";
    background = "#FFFCF0";
    selection_foreground = "#100F0F";
    selection_background = "#CECDC3";
    cursor = "#100F0F";
    cursor_text_color = "#FFFCF0";
    active_border_color = "#D14D41";
    inactive_border_color = "#CECDC3";
    active_tab_foreground = "#100F0F";
    active_tab_background = "#CECDC3";
    inactive_tab_foreground = "#6F6E69";
    inactive_tab_background = "#E6E4D9";
    color0 = "#100F0F";
    color1 = "#D14D41";
    color2 = "#879A39";
    color3 = "#D0A215";
    color4 = "#4385BE";
    color5 = "#CE5D97";
    color6 = "#3AA99F";
    color7 = "#FFFCF0";
    color8 = "#6F6E69";
    color9 = "#AF3029";
    color10 = "#66800B";
    color11 = "#AD8301";
    color12 = "#205EA6";
    color13 = "#A02F6F";
    color14 = "#24837B";
    color15 = "#F2F0E5";
  };

  # Ghostty terminal theme
  ghostty = {
    theme = "flexoki-light";
  };

  # Neovim colorscheme
  nvim = {
    colorscheme = "flexoki-light";
  };

  # VSCode theme name
  vscode = {
    theme = "Flexoki Light";
    extension = "kepano.flexoki";
  };

  # Cursor (extension not available in Cursor marketplace)
  cursor = {
    theme = "Flexoki Light";
    extension = "";
  };

  # Walker launcher colors
  walker = {
    selectedText = "#205EA6";
    text = "#100F0F";
    base = "#FFFCF0";
    border = "#205EA6";
    foreground = "#100F0F";
    background = "#FFFCF0";
  };

  # Waybar colors
  waybar = {
    foreground = "#100F0F";
    background = "#FFFCF0";
  };

  # wlogout power menu colors
  wlogout = {
    backgroundColor = "#FFFCF0";
    buttonBackground = "#F2F0E5";
    buttonHoverBackground = "#205EA6";
    textColor = "#100F0F";
    textHoverColor = "#FFFCF0";
  };

  # tmux status bar colors
  tmux = {
    statusBackground = "#FFFCF0";
    statusForeground = "#100F0F";
    windowStatusCurrent = "#205EA6";
    paneActiveBorder = "#205EA6";
    paneInactiveBorder = "#CECDC3";
    messageBackground = "#205EA6";
    messageForeground = "#FFFCF0";
  };

  # Mako notification colors
  mako = {
    textColor = "#100F0F";
    borderColor = "#205EA6";
    backgroundColor = "#FFFCF0";
    progressColor = "#100F0F";
  };

  # SwayOSD colors
  swayosd = {
    backgroundColor = "#FFFCF0";
    borderColor = "#205EA6";
    textColor = "#100F0F";
  };

  # Hyprlock colors
  hyprlock = {
    general = "#FFFCF0";
    input = "#FFFCF0";
    innerColor = "#F2F0E5cc";
    outerColor = "#CECDC3";
    fontColor = "#100F0F";
    checkColor = "#205EA6";
    failColor = "#D14D41";
  };

  # btop system monitor colors
  btop = {
    main_bg = "#FFFCF0";
    main_fg = "#100F0F";
    title = "#100F0F";
    hi_fg = "#205EA6";
    selected_bg = "#414868";
    selected_fg = "#100F0F";
    inactive_fg = "#6F6E69";
    graph_text = "#6F6E69";
    proc_misc = "#205EA6";
    cpu_box = "#6F6E69";
    mem_box = "#6F6E69";
    net_box = "#6F6E69";
    proc_box = "#6F6E69";
    div_line = "#6F6E69";
    temp_start = "#66800B";
    temp_mid = "#BC5215";
    temp_end = "#AF3029";
    cpu_start = "#66800B";
    cpu_mid = "#BC5215";
    cpu_end = "#AF3029";
    free_start = "#66800B";
    free_mid = "#BC5215";
    free_end = "#AF3029";
    cached_start = "#66800B";
    cached_mid = "#BC5215";
    cached_end = "#AF3029";
    available_start = "#66800B";
    available_mid = "#BC5215";
    available_end = "#AF3029";
    used_start = "#66800B";
    used_mid = "#BC5215";
    used_end = "#AF3029";
    download_start = "#66800B";
    download_mid = "#BC5215";
    download_end = "#AF3029";
    upload_start = "#66800B";
    upload_mid = "#BC5215";
    upload_end = "#AF3029";
  };

  # eza file listing colors
  eza = {
    filekinds = {
      normal = "#100F0F";
      directory = "#205EA6";
      symlink = "#3AA99F";
      pipe = "#6F6E69";
      block_device = "#D14D41";
      char_device = "#D14D41";
      socket = "#6F6E69";
      special = "#CE5D97";
      executable = "#879A39";
      mount_point = "#D0A215";
    };
    perms = {
      user_read = "#100F0F";
      user_write = "#D0A215";
      user_execute_file = "#879A39";
      user_execute_other = "#879A39";
      group_read = "#100F0F";
      group_write = "#D0A215";
      group_execute = "#879A39";
      other_read = "#6F6E69";
      other_write = "#D0A215";
      other_execute = "#879A39";
      special_user_file = "#CE5D97";
      special_other = "#6F6E69";
      attribute = "#6F6E69";
    };
    size = {
      major = "#6F6E69";
      minor = "#3AA99F";
      number_byte = "#100F0F";
      number_kilo = "#100F0F";
      number_mega = "#205EA6";
      number_giga = "#CE5D97";
      number_huge = "#CE5D97";
      unit_byte = "#6F6E69";
      unit_kilo = "#205EA6";
      unit_mega = "#CE5D97";
      unit_giga = "#CE5D97";
      unit_huge = "#D0A215";
    };
    users = {
      user_you = "#100F0F";
      user_root = "#D14D41";
      user_other = "#CE5D97";
      group_yours = "#100F0F";
      group_other = "#6F6E69";
      group_root = "#D14D41";
    };
    links = {
      normal = "#3AA99F";
      multi_link_file = "#D0A215";
    };
    git = {
      new = "#879A39";
      modified = "#D0A215";
      deleted = "#D14D41";
      renamed = "#3AA99F";
      typechange = "#CE5D97";
      ignored = "#6F6E69";
      conflicted = "#AF3029";
    };
    git_repo = {
      branch_main = "#100F0F";
      branch_other = "#CE5D97";
      git_clean = "#879A39";
      git_dirty = "#D14D41";
    };
    security_context = {
      colon = "#6F6E69";
      user = "#100F0F";
      role = "#CE5D97";
      typ = "#6F6E69";
      range = "#CE5D97";
    };
    file_type = {
      image = "#D0A215";
      video = "#D14D41";
      music = "#879A39";
      lossless = "#3AA99F";
      crypto = "#6F6E69";
      document = "#100F0F";
      compressed = "#CE5D97";
      temp = "#AF3029";
      compiled = "#205EA6";
      build = "#6F6E69";
      source = "#205EA6";
    };
    punctuation = "#6F6E69";
    date = "#D0A215";
    inode = "#6F6E69";
    blocks = "#6F6E69";
    header = "#100F0F";
    octal = "#3AA99F";
    flags = "#CE5D97";
    symlink_path = "#3AA99F";
    control_char = "#205EA6";
    broken_symlink = "#D14D41";
    broken_path_overlay = "#6F6E69";
  };

  # Browser theme color (RGB format for Chrome/Brave managed policy)
  browser = {
    themeColor = "242,240,229"; # RGB values from chromium.theme
  };

  # Fastfetch system info colors
  fastfetch = {
    keyColor = "blue"; # Matches the blue accent theme
  };

  # Wallpapers
  wallpapers = [
    "1-flexoki-light-orb.png"
    "2-flexoki-light-omarchy.png"
  ];
}
