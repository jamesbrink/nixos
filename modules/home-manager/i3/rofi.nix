# Rofi configuration for i3 - Tokyo Night theme
{
  config,
  pkgs,
  lib,
  ...
}:

{
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
    terminal = "${pkgs.alacritty}/bin/alacritty";

    extraConfig = {
      modi = "drun,run,window,ssh";
      show-icons = true;
      icon-theme = "Papirus-Dark";
      display-drun = " Apps";
      display-run = " Run";
      display-window = " Windows";
      display-ssh = " SSH";
      drun-display-format = "{name}";
      disable-history = false;
      sidebar-mode = false;
      hover-select = true;
      me-select-entry = "";
      me-accept-entry = "MousePrimary";
    };

    theme =
      let
        inherit (config.lib.formats.rasi) mkLiteral;
      in
      {
        "*" = {
          bg0 = mkLiteral "#1a1b26";
          bg1 = mkLiteral "#24283b";
          bg2 = mkLiteral "#414868";
          bg3 = mkLiteral "#565f89";
          fg0 = mkLiteral "#c0caf5";
          fg1 = mkLiteral "#a9b1d6";
          fg2 = mkLiteral "#787c99";

          accent = mkLiteral "#7aa2f7";
          urgent = mkLiteral "#f7768e";
          active = mkLiteral "#9ece6a";

          background-color = mkLiteral "transparent";
          text-color = mkLiteral "@fg0";

          margin = 0;
          padding = 0;
          spacing = 0;
        };

        "window" = {
          location = mkLiteral "center";
          width = 640;
          background-color = mkLiteral "@bg0";
          border = mkLiteral "2px";
          border-color = mkLiteral "@accent";
          border-radius = mkLiteral "8px";
        };

        "inputbar" = {
          spacing = mkLiteral "8px";
          padding = mkLiteral "12px";
          background-color = mkLiteral "@bg1";
          border-radius = mkLiteral "8px 8px 0 0";
        };

        "prompt, entry, element-icon, element-text" = {
          vertical-align = mkLiteral "0.5";
        };

        "prompt" = {
          text-color = mkLiteral "@accent";
        };

        "textbox" = {
          padding = mkLiteral "8px 12px";
          background-color = mkLiteral "@bg1";
        };

        "listview" = {
          padding = mkLiteral "4px 0";
          lines = 10;
          columns = 1;
          fixed-height = false;
          dynamic = true;
        };

        "element" = {
          padding = mkLiteral "8px 12px";
          spacing = mkLiteral "8px";
          border-radius = mkLiteral "4px";
        };

        "element normal normal" = {
          text-color = mkLiteral "@fg1";
        };

        "element normal urgent" = {
          text-color = mkLiteral "@urgent";
        };

        "element normal active" = {
          text-color = mkLiteral "@active";
        };

        "element selected" = {
          background-color = mkLiteral "@bg2";
        };

        "element selected normal" = {
          text-color = mkLiteral "@accent";
        };

        "element selected urgent" = {
          text-color = mkLiteral "@urgent";
        };

        "element selected active" = {
          text-color = mkLiteral "@active";
        };

        "element-icon" = {
          size = mkLiteral "1em";
        };

        "element-text" = {
          text-color = mkLiteral "inherit";
        };
      };
  };
}
