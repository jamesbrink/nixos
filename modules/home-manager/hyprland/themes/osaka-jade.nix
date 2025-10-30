# Osaka Jade theme
{
  name = "osaka-jade";
  displayName = "Osaka Jade";

  # GTK/Icon theme package names (resolved by main module)
  gtk = {
    themeName = "Adwaita-dark";
    themePackage = "adwaita-icon-theme"; # Built-in, no separate package needed
    iconName = "Papirus-Dark";
    iconPackage = "papirus-icon-theme";
  };

  # Hyprland colors
  hyprland = {
    activeBorder = "rgb(71CEAD)";
    inactiveBorder = "rgba(214237aa)";
  };

  # Alacritty color scheme
  alacritty = {
    primary = {
      background = "#111c18";
      foreground = "#C1C497";
    };
    normal = {
      black = "#23372B";
      red = "#FF5345";
      green = "#549e6a";
      yellow = "#459451";
      blue = "#509475";
      magenta = "#D2689C";
      cyan = "#2DD5B7";
      white = "#F6F5DD";
    };
    bright = {
      black = "#53685B";
      red = "#db9f9c";
      green = "#143614";
      yellow = "#E5C736";
      blue = "#ACD4CF";
      magenta = "#75bbb3";
      cyan = "#8CD3CB";
      white = "#9eebb3";
    };
    indexed_colors = [ ];
  };

  # Kitty terminal colors
  kitty = {
    foreground = "#C1C497";
    background = "#111C18";
    selection_foreground = "#111C18";
    selection_background = "#C1C497";
    cursor = "#D7C995";
    cursor_text_color = "#000000";
    active_tab_foreground = "#111C18";
    active_tab_background = "#C1C497";
    inactive_tab_foreground = "#C1C497";
    inactive_tab_background = "#111C18";
    color0 = "#23372B";
    color1 = "#FF5345";
    color2 = "#549E6A";
    color3 = "#459451";
    color4 = "#509475";
    color5 = "#D2689C";
    color6 = "#2DD5B7";
    color7 = "#F6F5DD";
    color8 = "#53685B";
    color9 = "#DB9F9C";
    color10 = "#63b07a";
    color11 = "#E5C736";
    color12 = "#ACD4CF";
    color13 = "#75BBB3";
    color14 = "#8CD3CB";
    color15 = "#9EEBB3";
  };

  # Ghostty terminal theme (custom colors - no built-in theme)
  ghostty = {
    background = "#111c18";
    foreground = "#C1C497";
    cursor-color = "#D7C995";
    cursor-text = "#000000";
    palette = [
      "0=#23372B"
      "1=#FF5345"
      "2=#549e6a"
      "3=#459451"
      "4=#509475"
      "5=#D2689C"
      "6=#2DD5B7"
      "7=#F6F5DD"
      "8=#53685B"
      "9=#db9f9c"
      "10=#63b07a"
      "11=#E5C736"
      "12=#ACD4CF"
      "13=#75bbb3"
      "14=#8CD3CB"
      "15=#9eebb3"
    ];
  };

  # VSCode theme name
  vscode = {
    theme = "Ocean Green: Dark";
  };

  # Walker launcher colors
  walker = {
    selectedText = "#e1b55e";
    text = "#ebfff2";
    base = "#11221C";
    border = "#214237";
    foreground = "#11221C";
    background = "#11221C";
  };

  # Waybar colors
  waybar = {
    foreground = "#ebfff2";
    background = "#11221C";
  };

  # wlogout power menu colors
  wlogout = {
    backgroundColor = "#111c18";
    buttonBackground = "#23372B";
    buttonHoverBackground = "#71CEAD";
    textColor = "#C1C497";
    textHoverColor = "#111c18";
  };

  # tmux status bar colors
  tmux = {
    statusBackground = "#111c18";
    statusForeground = "#C1C497";
    windowStatusCurrent = "#71CEAD";
    paneActiveBorder = "#71CEAD";
    paneInactiveBorder = "#53685B";
    messageBackground = "#71CEAD";
    messageForeground = "#111c18";
  };

  # Mako notification colors
  mako = {
    textColor = "#C1C497";
    borderColor = "#214237";
    backgroundColor = "#11221C";
    progressColor = "#C0C396";
  };

  # SwayOSD colors
  swayosd = {
    backgroundColor = "#11221C";
    borderColor = "#589A5F";
    textColor = "#C0C396";
  };

  # Hyprlock colors
  hyprlock = {
    general = "#072820";
    input = "#072820";
    innerColor = "#072820";
    outerColor = "#a7ac84";
    fontColor = "#a7ac84";
    checkColor = "#83a298";
    failColor = "#FF5345";
  };

  # btop system monitor colors
  btop = {
    main_bg = "#111c18";
    main_fg = "#F7E8B2";
    title = "#D6D5BC";
    hi_fg = "#E67D64";
    selected_bg = "#364538";
    selected_fg = "#DEB266";
    inactive_fg = "#32473B";
    graph_text = "#E6D8BA";
    proc_misc = "#E6D8BA";
    cpu_box = "#81B8A8";
    mem_box = "#81B8A8";
    net_box = "#81B8A8";
    proc_box = "#81B8A8";
    div_line = "#81B8A8";
    temp_start = "#BFD99A";
    temp_mid = "#E1B55E";
    temp_end = "#DBB05C";
    cpu_start = "#5F8C86";
    cpu_mid = "#629C89";
    cpu_end = "#76AD98";
    free_start = "#5F8C86";
    free_mid = "#629C89";
    free_end = "#76AD98";
    cached_start = "#5F8C86";
    cached_mid = "#629C89";
    cached_end = "#76AD98";
    available_start = "#5F8C86";
    available_mid = "#629C89";
    available_end = "#76AD98";
    used_start = "#5F8C86";
    used_mid = "#629C89";
    used_end = "#76AD98";
    download_start = "#75BBB3";
    download_mid = "#61949A";
    download_end = "#215866";
    upload_start = "#215866";
    upload_mid = "#91C080";
    upload_end = "#549E6A";
    process_start = "#72CFA3";
    process_mid = "#D0D494";
    process_end = "#DB9F9C";
  };

  # eza file listing colors
  eza = {
    filekinds = {
      normal = "#C1C497";
      directory = "#509475";
      symlink = "#2DD5B7";
      pipe = "#53685B";
      block_device = "#FF5345";
      char_device = "#FF5345";
      socket = "#23372B";
      special = "#D2689C";
      executable = "#549e6a";
      mount_point = "#8CD3CB";
    };
    perms = {
      user_read = "#C1C497";
      user_write = "#E5C736";
      user_execute_file = "#549e6a";
      user_execute_other = "#549e6a";
      group_read = "#C1C497";
      group_write = "#E5C736";
      group_execute = "#549e6a";
      other_read = "#F6F5DD";
      other_write = "#E5C736";
      other_execute = "#549e6a";
      special_user_file = "#D2689C";
      special_other = "#53685B";
      attribute = "#C1C497";
    };
    size = {
      major = "#C1C497";
      minor = "#2DD5B7";
      number_byte = "#C1C497";
      number_kilo = "#C1C497";
      number_mega = "#509475";
      number_giga = "#D2689C";
      number_huge = "#D2689C";
      unit_byte = "#C1C497";
      unit_kilo = "#509475";
      unit_mega = "#D2689C";
      unit_giga = "#D2689C";
      unit_huge = "#8CD3CB";
    };
    users = {
      user_you = "#C1C497";
      user_root = "#FF5345";
      user_other = "#D2689C";
      group_yours = "#C1C497";
      group_other = "#53685B";
      group_root = "#FF5345";
    };
    links = {
      normal = "#2DD5B7";
      multi_link_file = "#8CD3CB";
    };
    git = {
      new = "#549e6a";
      modified = "#E5C736";
      deleted = "#FF5345";
      renamed = "#2DD5B7";
      typechange = "#D2689C";
      ignored = "#53685B";
      conflicted = "#db9f9c";
    };
    git_repo = {
      branch_main = "#C1C497";
      branch_other = "#D2689C";
      git_clean = "#549e6a";
      git_dirty = "#FF5345";
    };
    security_context = {
      colon = "#53685B";
      user = "#C1C497";
      role = "#D2689C";
      typ = "#23372B";
      range = "#D2689C";
    };
    file_type = {
      image = "#E5C736";
      video = "#FF5345";
      music = "#549e6a";
      lossless = "#2DD5B7";
      crypto = "#53685B";
      document = "#C1C497";
      compressed = "#D2689C";
      temp = "#db9f9c";
      compiled = "#ACD4CF";
      build = "#53685B";
      source = "#509475";
    };
    punctuation = "#53685B";
    date = "#E5C736";
    inode = "#C1C497";
    blocks = "#53685B";
    header = "#C1C497";
    octal = "#2DD5B7";
    flags = "#D2689C";
    symlink_path = "#2DD5B7";
    control_char = "#509475";
    broken_symlink = "#FF5345";
    broken_path_overlay = "#53685B";
  };

  # Browser theme color (RGB format for Chrome/Brave managed policy)
  browser = {
    themeColor = "17,28,24"; # RGB values from primary background #111c18
  };

  # Fastfetch system info colors
  fastfetch = {
    keyColor = "cyan"; # Matches the jade/green theme accent
  };

  # Wallpapers
  # To add wallpapers for this theme:
  # 1. Create directory: mkdir -p modules/home-manager/hyprland/wallpapers/osaka-jade
  # 2. Add image files (JPG or PNG) to the directory
  # 3. List them here: wallpapers = [ "1-my-wallpaper.jpg" "2-another.png" ];
  # 4. Use Super+Ctrl+Space to rotate through backgrounds
  wallpapers = [ ];
}
