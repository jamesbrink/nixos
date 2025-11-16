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

      # Alacritty terminal configuration
      # NOTE: On Linux, Alacritty is configured in modules/home-manager/hyprland/default.nix
      # with runtime theme support (Omarchy-style). On Darwin, the shell module provides config.
      # Only disable on Linux to avoid conflicts with Hyprland theme system.
      programs.alacritty.enable = lib.mkIf pkgs.stdenv.isLinux (lib.mkForce false);

      # SSH configuration files
      home.file."${homeDir}/.ssh/config_external" = {
        source = ./ssh/config_external;
      };

      home.file."${homeDir}/.ssh/config.d/00-local-hosts" = {
        source = ./ssh/config.d/00-local-hosts;
      };

      # Ensure kubeconfig directory exists for synced secrets
      home.file."${homeDir}/.kube/.keep".text = "";

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

      # NPM global packages in user directory
      home.file."${homeDir}/.npmrc".text = ''
        prefix=${homeDir}/.npm-global
      '';

      # Add npm global bin to PATH
      home.sessionPath = [
        "${homeDir}/.npm-global/bin"
      ];

      # Create npm global directory
      home.activation.setupNpmGlobal = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p ${homeDir}/.npm-global
      '';
    };
}
