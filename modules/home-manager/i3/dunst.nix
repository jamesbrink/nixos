# Dunst notification daemon configuration - Tokyo Night theme
{
  config,
  pkgs,
  lib,
  ...
}:

{
  services.dunst = {
    enable = true;
    settings = {
      global = {
        monitor = 0;
        follow = "mouse";
        width = 350;
        height = 300;
        origin = "top-right";
        offset = "20x50";
        scale = 0;
        notification_limit = 5;

        progress_bar = true;
        progress_bar_height = 10;
        progress_bar_frame_width = 1;
        progress_bar_min_width = 150;
        progress_bar_max_width = 300;

        indicate_hidden = true;
        transparency = 10;
        separator_height = 2;
        padding = 12;
        horizontal_padding = 12;
        text_icon_padding = 0;
        frame_width = 2;
        frame_color = "#7aa2f7";
        gap_size = 6;
        separator_color = "frame";
        sort = true;

        font = "JetBrainsMono Nerd Font 10";
        line_height = 0;
        markup = "full";
        format = "<b>%s</b>\\n%b";
        alignment = "left";
        vertical_alignment = "center";
        show_age_threshold = 60;
        ellipsize = "middle";
        ignore_newline = false;
        stack_duplicates = true;
        hide_duplicate_count = false;
        show_indicators = true;

        icon_position = "left";
        min_icon_size = 32;
        max_icon_size = 48;
        icon_path = "/run/current-system/sw/share/icons/Papirus-Dark/48x48/status:/run/current-system/sw/share/icons/Papirus-Dark/48x48/devices:/run/current-system/sw/share/icons/Papirus-Dark/48x48/apps";

        sticky_history = true;
        history_length = 20;

        dmenu = "${pkgs.rofi}/bin/rofi -dmenu -p dunst";
        browser = "${pkgs.chromium}/bin/chromium";

        always_run_script = true;
        title = "Dunst";
        class = "Dunst";
        corner_radius = 8;
        ignore_dbusclose = false;

        force_xwayland = false;
        force_xinerama = false;

        mouse_left_click = "close_current";
        mouse_middle_click = "do_action, close_current";
        mouse_right_click = "close_all";
      };

      experimental = {
        per_monitor_dpi = false;
      };

      urgency_low = {
        background = "#1a1b26";
        foreground = "#c0caf5";
        frame_color = "#565f89";
        timeout = 5;
      };

      urgency_normal = {
        background = "#1a1b26";
        foreground = "#c0caf5";
        frame_color = "#7aa2f7";
        timeout = 10;
      };

      urgency_critical = {
        background = "#1a1b26";
        foreground = "#c0caf5";
        frame_color = "#f7768e";
        timeout = 0;
      };
    };
  };
}
