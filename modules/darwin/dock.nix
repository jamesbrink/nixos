{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.programs.dock;

  dockItem = types.submodule {
    options = {
      path = mkOption {
        type = types.str;
        description = "Path to the application";
      };

      section = mkOption {
        type = types.enum [
          "apps"
          "others"
        ];
        default = "apps";
        description = "Dock section for the item";
      };

      view = mkOption {
        type = types.nullOr (
          types.enum [
            "grid"
            "fan"
            "list"
            "automatic"
          ]
        );
        default = null;
        description = "View style for folders (grid = accordion, fan = fan, list = list, automatic = automatic)";
      };

      display = mkOption {
        type = types.nullOr (
          types.enum [
            "folder"
            "stack"
          ]
        );
        default = null;
        description = "Display as folder or stack";
      };

      sort = mkOption {
        type = types.nullOr (
          types.enum [
            "name"
            "dateadded"
            "datemodified"
            "datecreated"
            "kind"
          ]
        );
        default = null;
        description = "Sort by option for folders";
      };
    };
  };

  toDockItem = item: ''"${item.path}"'';

  dockScript = ''
    echo "Configuring dock items..."
    ${pkgs.dockutil}/bin/dockutil --no-restart --remove all

    ${concatMapStringsSep "\n" (item: ''
      ${pkgs.dockutil}/bin/dockutil --no-restart --add ${toDockItem item} ${
        if item.section == "others" then "--section others" else ""
      } ${if item.view != null then "--view ${item.view}" else ""} ${
        if item.display != null then "--display ${item.display}" else ""
      } ${if item.sort != null then "--sort ${item.sort}" else ""}
    '') cfg.items}

    killall Dock
  '';
in
{
  options.programs.dock = {
    enable = mkEnableOption "dock management";

    items = mkOption {
      type = types.listOf dockItem;
      default = [ ];
      example = literalExpression ''
        [
          { path = "/Applications/Safari.app"; }
          { path = "/Applications/Mail.app"; }
          { path = "/Applications/Terminal.app"; }
          { path = "~/Downloads"; section = "others"; }
        ]
      '';
      description = "Applications and folders to add to the dock";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.dockutil ];

    system.activationScripts.postActivation.text = mkAfter ''
      # Run dock configuration as the primary user
      sudo -u ${config.system.primaryUser} ${pkgs.writeScript "configure-dock" dockScript}
    '';
  };
}
