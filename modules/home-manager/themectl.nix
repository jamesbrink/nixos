{
  config,
  lib,
  pkgs,
  inputs ? null,
  ...
}:

let
  cfg = config.programs.themectl;
  inherit (lib)
    mkEnableOption
    mkOption
    types
    attrByPath
    ;
  resolvedInputs =
    if inputs != null then inputs else attrByPath [ "_module" "args" "inputs" ] null config;
  packageFor =
    name:
    if resolvedInputs != null then resolvedInputs.self.packages.${pkgs.stdenv.system}.${name} else null;
  themeData = packageFor "themectl-theme-data";
  themectlPkg = packageFor "themectl";
  hotkeysBundleArg = attrByPath [ "_module" "args" "hotkeysBundle" ] null config;
  hotkeysBundle =
    if hotkeysBundleArg != null then
      hotkeysBundleArg
    else
      import ../../lib/hotkeys.nix { inherit pkgs; };
  defaultMetadata = "${config.home.homeDirectory}/.config/themectl/themes.json";
  defaultState = "${config.home.homeDirectory}/.config/themes/.current-theme";
  defaultHotkeys = "${config.home.homeDirectory}/.config/themectl/hotkeys.json";
in
{
  options.programs.themectl = {
    enable = mkEnableOption "themectl CLI and configuration management";

    platform = mkOption {
      type = types.enum [
        "darwin"
        "linux"
      ];
      default = if pkgs.stdenv.isDarwin then "darwin" else "linux";
      description = "Platform hint used by themectl for automation hooks.";
    };

    metadataPath = mkOption {
      type = types.str;
      default = defaultMetadata;
      description = "Path to the generated theme metadata JSON file.";
    };

    stateFile = mkOption {
      type = types.str;
      default = defaultState;
      description = "Path to the mutable file that tracks the current theme.";
    };

    hotkeysFile = mkOption {
      type = types.str;
      default = defaultHotkeys;
      description = "Path to the hotkey manifest YAML consumed by themectl.";
    };

    cycle = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Preferred cycle order for `themectl cycle`.";
    };

    defaultTheme = mkOption {
      type = types.str;
      default = "tokyo-night";
      description = "Initial theme written to the state file when it is missing.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (themectlPkg != null) themectlPkg;

    xdg.configFile."themectl/themes.json" = lib.mkIf (themeData != null) {
      source = themeData;
    };
    xdg.configFile."themectl/hotkeys.json" = lib.mkIf (cfg.hotkeysFile == defaultHotkeys) {
      source = hotkeysBundle.jsonPath;
    };

    xdg.configFile."themectl/config.toml".text =
      let
        cycleList = lib.concatStringsSep ", " (map (name: ''"${name}"'') cfg.cycle);
      in
      ''
        platform = "${cfg.platform}"
        theme_metadata = "${cfg.metadataPath}"
        state_file = "${cfg.stateFile}"
        hotkeys_file = "${cfg.hotkeysFile}"

        [order]
        cycle = [${cycleList}]
      '';

    home.activation.themectlState = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      STATE="${cfg.stateFile}"
      STATE_DIR=$(dirname "$STATE")
      mkdir -p "$STATE_DIR"

      if [[ ! -f "$STATE" ]]; then
        $DRY_RUN_CMD echo "${cfg.defaultTheme}" > "$STATE"
        $DRY_RUN_CMD chmod 644 "$STATE"
        echo "Initialized theme state at $STATE"
      fi
    '';
  };
}
