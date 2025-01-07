# keychron-keyboard.nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.keychron-keyboard;
in {
  options.services.keychron-keyboard = {
    enable = mkEnableOption "macOS-like keyboard configuration";
    user = mkOption {
      type = types.str;
      description = "Username to apply dconf settings for";
    };
  };

  config = mkIf cfg.enable {
    programs.dconf.enable = true;

    environment.systemPackages = with pkgs; [
      xdotool
      maim
      xclip
      libnotify
      gnome.gnome-screenshot
      gnome.dconf-editor
    ];

    # Basic keyboard settings
    services.xserver = {
      enable = true;
      xkbOptions = "apple:alupckeys";
      
      # For Keychron K2 function key behavior
      extraConfig = ''
        options hid_apple fnmode=2
        options hid_apple iso_layout=0
        options hid_apple swap_opt_cmd=0
      '';
    };

    # Load the hid-apple module with correct options
    boot.extraModprobeConfig = ''
      options hid_apple fnmode=2
      options hid_apple iso_layout=0
      options hid_apple swap_opt_cmd=0
    '';

    services.xserver.desktopManager.gnome.enable = true;

    home-manager.users.${cfg.user}.dconf.settings = {
      "org/gnome/desktop/input-sources" = {
        xkb-options = ["apple:alupckeys"];
      };

      "org/gnome/desktop/wm/keybindings" = {
        "close" = ["<Super>w"];
        "minimize" = ["<Super>m"];
        "maximize" = ["<Super>f"];
        "switch-to-workspace-left" = ["<Super>Left"];
        "switch-to-workspace-right" = ["<Super>Right"];
      };

      "org/gnome/settings-daemon/plugins/media-keys" = {
        "screenshot" = ["<Shift><Super>3"];
        "screenshot-window" = ["<Shift><Super>5"];
        "area-screenshot" = ["<Shift><Super>4"];
        "screenshot-clip" = ["<Shift><Super><Control>3"];
        "window-screenshot-clip" = ["<Shift><Super><Control>5"];
        "area-screenshot-clip" = ["<Shift><Super><Control>4"];
      };

      # GNOME Shell custom keybindings
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
        name = "Copy";
        command = "xdotool key ctrl+c";
        binding = "<Super>c";
      };

      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
        name = "Paste";
        command = "xdotool key ctrl+v";
        binding = "<Super>v";
      };

      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2" = {
        name = "Cut";
        command = "xdotool key ctrl+x";
        binding = "<Super>x";
      };

      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3" = {
        name = "Select All";
        command = "xdotool key ctrl+a";
        binding = "<Super>a";
      };

      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4" = {
        name = "Undo";
        command = "xdotool key ctrl+z";
        binding = "<Super>z";
      };

      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5" = {
        name = "Redo";
        command = "xdotool key ctrl+shift+z";
        binding = "<Shift><Super>z";
      };

      # Register custom keybindings
      "org/gnome/settings-daemon/plugins/media-keys" = {
        custom-keybindings = [
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5/"
        ];
      };

      # GNOME Shell settings
      "org/gnome/shell/keybindings" = {
        "toggle-overview" = ["<Super>Space"]; # Prevent conflict with copy/paste
      };
    };

    # Keyboard backlight control
    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="leds", KERNEL=="*::kbd_backlight", RUN+="${pkgs.coreutils}/bin/chgrp users /sys/class/leds/%k/brightness"
      ACTION=="add", SUBSYSTEM=="leds", KERNEL=="*::kbd_backlight", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/leds/%k/brightness"
    '';
  };
}