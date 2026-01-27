# Install theme extensions that aren't available in VSCode/Cursor marketplaces
# These are packaged from source and symlinked to both editors
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.editor.extraThemeExtensions;

  # Import our custom extensions
  customExtensions = import ../../../packages/vscode-extensions {
    inherit (pkgs)
      lib
      vscode-utils
      fetchFromGitHub
      stdenv
      ;
  };

  # Extension definitions: name -> package
  # These are theme extensions not available in marketplaces
  extensions = {
    "qufiwefefwoyn.kanagawa" = customExtensions.kanagawa;
    "jovejonovski.ocean-green" = customExtensions.ocean-green;
    "kepano.flexoki" = customExtensions.flexoki;
  };

  # Generate symlinks for Cursor
  cursorLinks = lib.mapAttrs' (name: pkg: {
    name = ".cursor/extensions/${name}";
    value = {
      source = "${pkg}/share/vscode/extensions/${name}";
    };
  }) extensions;

  # Generate symlinks for VSCode
  vscodeLinks = lib.mapAttrs' (name: pkg: {
    name = ".vscode/extensions/${name}";
    value = {
      source = "${pkg}/share/vscode/extensions/${name}";
    };
  }) extensions;
in
{
  options.programs.editor.extraThemeExtensions = {
    enable = lib.mkEnableOption "Install missing theme extensions to VSCode and Cursor";
  };

  config = lib.mkIf cfg.enable {
    home.file = cursorLinks // vscodeLinks;
  };
}
