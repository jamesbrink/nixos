# Polybar configuration for i3 - Tokyo Night theme
{
  config,
  pkgs,
  lib,
  ...
}:

{
  services.polybar = {
    enable = true;
    package = pkgs.polybar.override {
      i3Support = true;
      pulseSupport = true;
    };

    script = "polybar main &";

    settings = {
      "colors" = {
        # Tokyo Night color scheme
        background = "#1a1b26";
        background-alt = "#24283b";
        foreground = "#c0caf5";
        foreground-alt = "#565f89";
        primary = "#7aa2f7";
        secondary = "#bb9af7";
        alert = "#f7768e";
        success = "#9ece6a";
        warning = "#e0af68";
        cyan = "#7dcfff";
      };

      "bar/main" = {
        monitor = "\${env:MONITOR:}";
        width = "100%";
        height = 32;
        radius = 0;
        fixed-center = true;

        background = "\${colors.background}";
        foreground = "\${colors.foreground}";

        line-size = 3;
        line-color = "\${colors.primary}";

        border-size = 0;
        border-color = "\${colors.background}";

        padding-left = 2;
        padding-right = 2;

        module-margin-left = 1;
        module-margin-right = 1;

        font-0 = "JetBrainsMono Nerd Font:size=10;2";
        font-1 = "JetBrainsMono Nerd Font:size=16;4";
        font-2 = "JetBrainsMono Nerd Font:size=12;3";

        modules-left = "i3";
        modules-center = "date";
        modules-right = "filesystem memory cpu pulseaudio network battery";

        tray-position = "right";
        tray-padding = 2;
        tray-background = "\${colors.background}";

        cursor-click = "pointer";
        cursor-scroll = "ns-resize";
      };

      "module/i3" = {
        type = "internal/i3";
        format = "<label-state> <label-mode>";
        index-sort = true;
        wrapping-scroll = false;

        # Only show workspaces on the same output as the bar
        pin-workspaces = true;

        label-mode-padding = 2;
        label-mode-foreground = "\${colors.background}";
        label-mode-background = "\${colors.primary}";

        # focused = Active workspace on focused monitor
        label-focused = "%index%";
        label-focused-background = "\${colors.background-alt}";
        label-focused-underline = "\${colors.primary}";
        label-focused-padding = 2;

        # unfocused = Inactive workspace on any monitor
        label-unfocused = "%index%";
        label-unfocused-padding = 2;
        label-unfocused-foreground = "\${colors.foreground-alt}";

        # visible = Active workspace on unfocused monitor
        label-visible = "%index%";
        label-visible-background = "\${self.label-focused-background}";
        label-visible-underline = "\${self.label-focused-underline}";
        label-visible-padding = "\${self.label-focused-padding}";

        # urgent = Workspace with urgency hint set
        label-urgent = "%index%";
        label-urgent-background = "\${colors.alert}";
        label-urgent-padding = 2;
      };

      "module/cpu" = {
        type = "internal/cpu";
        interval = 2;
        format-prefix = "󰍛 ";
        format-prefix-foreground = "\${colors.primary}";
        format-underline = "\${colors.primary}";
        label = "%percentage:2%%";
      };

      "module/memory" = {
        type = "internal/memory";
        interval = 2;
        format-prefix = "󰘚 ";
        format-prefix-foreground = "\${colors.secondary}";
        format-underline = "\${colors.secondary}";
        label = "%percentage_used%%";
      };

      "module/network" = {
        type = "internal/network";
        interface-type = "wired";
        interval = 3;

        format-connected = "<label-connected>";
        format-connected-underline = "\${colors.cyan}";
        label-connected = "󰈀 %local_ip%";
        label-connected-foreground = "\${colors.foreground}";

        format-disconnected = "<label-disconnected>";
        label-disconnected = "󰈂 ";
        label-disconnected-foreground = "\${colors.alert}";
      };

      "module/date" = {
        type = "internal/date";
        interval = 5;

        date = "%A, %B %d";
        date-alt = "%Y-%m-%d";

        time = "%I:%M %p";
        time-alt = "%H:%M:%S";

        format-prefix = "󰃰 ";
        format-prefix-foreground = "\${colors.success}";
        format-underline = "\${colors.success}";

        label = "%date% %time%";
      };

      "module/pulseaudio" = {
        type = "internal/pulseaudio";

        format-volume = "<ramp-volume> <label-volume>";
        format-volume-underline = "\${colors.warning}";
        label-volume = "%percentage%%";
        label-volume-foreground = "\${colors.foreground}";

        label-muted = "󰖁 muted";
        label-muted-foreground = "\${colors.foreground-alt}";

        ramp-volume-0 = "󰕿";
        ramp-volume-1 = "󰖀";
        ramp-volume-2 = "󰕾";
        ramp-volume-foreground = "\${colors.warning}";
      };

      "module/battery" = {
        type = "internal/battery";
        battery = "BAT0";
        adapter = "AC";
        full-at = 98;

        format-charging = "<animation-charging> <label-charging>";
        format-charging-underline = "\${colors.success}";

        format-discharging = "<ramp-capacity> <label-discharging>";
        format-discharging-underline = "\${colors.warning}";

        format-full-prefix = "󰁹 ";
        format-full-prefix-foreground = "\${colors.success}";
        format-full-underline = "\${colors.success}";

        ramp-capacity-0 = "󰁺";
        ramp-capacity-1 = "󰁻";
        ramp-capacity-2 = "󰁼";
        ramp-capacity-3 = "󰁽";
        ramp-capacity-4 = "󰁾";
        ramp-capacity-5 = "󰁿";
        ramp-capacity-6 = "󰂀";
        ramp-capacity-7 = "󰂁";
        ramp-capacity-8 = "󰂂";
        ramp-capacity-9 = "󰁹";
        ramp-capacity-foreground = "\${colors.warning}";

        animation-charging-0 = "󰢜";
        animation-charging-1 = "󰂆";
        animation-charging-2 = "󰂇";
        animation-charging-3 = "󰂈";
        animation-charging-4 = "󰢝";
        animation-charging-5 = "󰂉";
        animation-charging-6 = "󰢞";
        animation-charging-7 = "󰂊";
        animation-charging-8 = "󰂋";
        animation-charging-9 = "󰂅";
        animation-charging-foreground = "\${colors.success}";
        animation-charging-framerate = 750;
      };

      "module/filesystem" = {
        type = "internal/fs";
        interval = 25;

        mount-0 = "/";

        label-mounted = "󰋊 %percentage_used%%";
        label-mounted-foreground = "\${colors.foreground}";
        label-mounted-underline = "\${colors.cyan}";

        label-unmounted = "󰋊 not mounted";
        label-unmounted-foreground = "\${colors.foreground-alt}";
      };

      "settings" = {
        screenchange-reload = true;
      };

      "global/wm" = {
        margin-top = 0;
        margin-bottom = 0;
      };
    };
  };
}
