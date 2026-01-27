# modules/themes/default.nix
# Universal theme module for NixOS and Darwin systems
# Provides theme metadata and assets without runtime dependencies
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.themes;

  # Import theme library functions
  themeLib = import ./lib.nix { };
in
{
  options.themes = {
    available = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "List of all available theme names";
      default = map (theme: theme.name) themeLib.themeMetadata;
      readOnly = true;
    };

    metadata = lib.mkOption {
      type = lib.types.unspecified;
      description = "Complete theme metadata for all themes";
      default = themeLib.themeMetadata;
      readOnly = true;
    };

    metadataJSON = lib.mkOption {
      type = lib.types.str;
      description = "JSON-encoded theme metadata";
      default = themeLib.themeMetadataJSON;
      readOnly = true;
    };

    lib = lib.mkOption {
      type = lib.types.unspecified;
      description = "Theme library functions";
      default = themeLib;
      readOnly = true;
    };
  };

  config = {
    # No runtime configuration needed - this is a pure data module
  };
}
