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
    };
  };

  toDockItem = item: ''"${item.path}"'';

  dockScript = ''
    echo "Configuring dock items..."
    ${pkgs.dockutil}/bin/dockutil --no-restart --remove all

    ${concatMapStringsSep "\n" (item: ''
      ${pkgs.dockutil}/bin/dockutil --no-restart --add ${toDockItem item} ${
        if item.section == "others" then "--section others" else ""
      }
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
