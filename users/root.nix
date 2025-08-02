# Root user configuration with home-manager
{
  config,
  pkgs,
  lib,
  ...
}:

{
  # Home-manager configuration for root
  home-manager.users.root =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      home.stateVersion = "25.05";

      # Root's home directory
      home.homeDirectory = if pkgs.stdenv.isDarwin then "/var/root" else "/root";

      # Import the unified shell configuration
      imports = [
        ../modules/home-manager/shell
      ];

      # Root-specific overrides
      programs.git = {
        userName = "root";
        userEmail = "root@localhost";
      };

      # Simplified shell aliases for root
      programs.zsh.shellAliases = {
        # Root-specific overrides
        ll = lib.mkForce "ls -la";
        la = lib.mkForce "ls -la";
        lt = lib.mkForce "ls -ltr";
        cleanup = lib.mkForce "nix-collect-garbage -d";
      };

      # Root prompt customization
      programs.starship.settings = {
        username = {
          show_always = true;
          style_user = lib.mkForce "red bold";
          style_root = lib.mkForce "red bold";
          format = lib.mkForce "[$user]($style) ";
        };
      };

      # Disable some features for root
      programs.direnv.enable = lib.mkForce false;
    };
}
