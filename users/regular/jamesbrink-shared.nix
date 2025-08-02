# Shared user configuration for both Linux and Darwin
{
  config,
  pkgs,
  lib,
  ...
}:

let
  homeDir = if pkgs.stdenv.isDarwin then "/Users/jamesbrink" else "/home/jamesbrink";
in
{
  # Common home-manager configuration
  home-manager.users.jamesbrink =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      home.stateVersion = "25.05";

      # Import the unified shell configuration
      imports = [
        ../../modules/home-manager/shell
      ];

      # SSH configuration files
      home.file."${homeDir}/.ssh/config_external" = {
        source = ./ssh/config_external;
      };

      home.file."${homeDir}/.ssh/config.d/00-local-hosts" = {
        source = ./ssh/config.d/00-local-hosts;
      };

      # SSH include configuration
      programs.ssh.includes = [
        # Include Nix-managed local hosts configuration first
        "${config.home.homeDirectory}/.ssh/config.d/00-local-hosts"
        # Then include user's external config for manual additions
        "${homeDir}/.ssh/config_external"
      ];

      # Git user configuration
      programs.git = {
        userName = "James Brink";
        userEmail = "brink.james@gmail.com";
      };

      # Platform-specific update aliases
      programs.zsh.shellAliases.update =
        if pkgs.stdenv.isDarwin then
          "darwin-rebuild switch --flake ~/Projects/jamesbrink/nixos#halcyon"
        else
          "sudo nixos-rebuild switch --flake /etc/nixos/#default";

      # Heroku CLI configuration with authentication
      home.activation.setupHeroku = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        HEROKU_KEY_PATH="/run/agenix/heroku-key"
        if [ -f "$HEROKU_KEY_PATH" ]; then
          cat > ${homeDir}/.netrc <<EOF
        machine api.heroku.com
          login brink.james@gmail.com
          password $(cat "$HEROKU_KEY_PATH")
        machine git.heroku.com
          login brink.james@gmail.com
          password $(cat "$HEROKU_KEY_PATH")
        EOF
          chmod 600 ${homeDir}/.netrc
        fi
      '';
    };
}
