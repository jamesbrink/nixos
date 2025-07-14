# System-wide Restic shell initialization for root and all users
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

{
  config =
    mkIf (config.services.resticBackups.enable or config.programs.restic-backups.enable or false)
      {
        # System-wide shell initialization
        environment.shellInit = ''
          # Restic environment configuration for all users
          restic_setup() {
            local config_dir=""
            
            # Determine config directory based on user
            if [ "$USER" = "root" ]; then
              # For root on Linux
              if [ -f "/root/.config/restic/s3-env" ]; then
                config_dir="/root/.config/restic"
              # For root on Darwin (running with sudo)
              elif [ -f "/var/root/.config/restic/s3-env" ]; then
                config_dir="/var/root/.config/restic"
              # Fall back to checking the sudo user's config
              elif [ -n "$SUDO_USER" ] && [ -f "/Users/$SUDO_USER/.config/restic/s3-env" ]; then
                config_dir="/Users/$SUDO_USER/.config/restic"
              elif [ -n "$SUDO_USER" ] && [ -f "/home/$SUDO_USER/.config/restic/s3-env" ]; then
                config_dir="/home/$SUDO_USER/.config/restic"
              fi
            else
              # For regular users
              if [ -f "$HOME/.config/restic/s3-env" ]; then
                config_dir="$HOME/.config/restic"
              fi
            fi
            
            # Load environment if config found
            if [ -n "$config_dir" ] && [ -f "$config_dir/s3-env" ]; then
              set -a
              source "$config_dir/s3-env"
              set +a
              export RESTIC_REPOSITORY="s3:s3.us-west-2.amazonaws.com/urandom-io-backups/$(hostname -s)"
              
              if [ -f "$config_dir/password" ]; then
                export RESTIC_PASSWORD_FILE="$config_dir/password"
              fi
            fi
          }

          # Call the setup function
          restic_setup

          # Clean up the function
          unset -f restic_setup
        '';

        # Configure for zsh if enabled (which is what you use)
        programs.zsh.interactiveShellInit = mkIf (config.programs.zsh.enable or false) ''
          # Restic environment for zsh
          if [ -f "$HOME/.config/restic/s3-env" ]; then
            set -a
            source "$HOME/.config/restic/s3-env"
            set +a
            export RESTIC_REPOSITORY="s3:s3.us-west-2.amazonaws.com/urandom-io-backups/$(hostname -s)"
            [ -f "$HOME/.config/restic/password" ] && export RESTIC_PASSWORD_FILE="$HOME/.config/restic/password"
          fi
        '';
      };
}
