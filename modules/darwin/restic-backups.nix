{
  config,
  lib,
  pkgs,
  secretsPath,
  ...
}:

with lib;

{
  imports = [ ../restic-shell-init.nix ];
  options = {
    programs.restic-backups = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Restic backup tools on Darwin";
      };
    };
  };

  config = mkIf config.programs.restic-backups.enable {
    # Install restic package
    environment.systemPackages = with pkgs; [
      restic

      # Create a helper script for manual backups
      (writeShellScriptBin "restic-backup" ''
        #!/usr/bin/env bash
        set -euo pipefail

        # Load environment variables
        if [ -f "$HOME/.config/restic/s3-env" ]; then
          set -a
          source "$HOME/.config/restic/s3-env"
          set +a
        else
          echo "Error: Restic S3 environment file not found at $HOME/.config/restic/s3-env"
          exit 1
        fi

        # Set repository based on hostname
        export RESTIC_REPOSITORY="s3:s3.us-west-2.amazonaws.com/urandom-io-backups/$(hostname -s)"

        # Load password
        if [ -f "$HOME/.config/restic/password" ]; then
          export RESTIC_PASSWORD_FILE="$HOME/.config/restic/password"
        else
          echo "Error: Restic password file not found at $HOME/.config/restic/password"
          exit 1
        fi

        # Default paths to backup
        BACKUP_PATHS=(
          "$HOME/Documents"
          "$HOME/Projects"
          "$HOME/.config"
          "$HOME/.ssh"
        )

        # Exclude patterns
        EXCLUDE_PATTERNS=(
          "*.cache"
          "*.trash"
          "node_modules"
          ".DS_Store"
          "*.tmp"
          "*.temp"
          "*.swp"
        )

        # Build exclude arguments
        EXCLUDE_ARGS=""
        for pattern in "''${EXCLUDE_PATTERNS[@]}"; do
          EXCLUDE_ARGS="$EXCLUDE_ARGS --exclude=\"$pattern\""
        done

        case "''${1:-}" in
          init)
            echo "Initializing Restic repository..."
            restic init
            ;;
          backup)
            echo "Starting backup to $RESTIC_REPOSITORY..."
            eval restic backup --compression max --verbose $EXCLUDE_ARGS "''${BACKUP_PATHS[@]}"
            ;;
          snapshots)
            restic snapshots
            ;;
          check)
            restic check
            ;;
          prune)
            restic forget --prune --keep-daily 7 --keep-weekly 4 --keep-monthly 12 --keep-yearly 2
            ;;
          restore)
            if [ -z "''${2:-}" ]; then
              echo "Usage: restic-backup restore <snapshot-id> [target-path]"
              exit 1
            fi
            TARGET="''${3:-restored-files}"
            restic restore "''${2}" --target "$TARGET"
            ;;
          *)
            echo "Usage: restic-backup {init|backup|snapshots|check|prune|restore}"
            echo ""
            echo "Commands:"
            echo "  init       - Initialize a new repository"
            echo "  backup     - Run a backup"
            echo "  snapshots  - List snapshots"
            echo "  check      - Check repository integrity"
            echo "  prune      - Remove old snapshots according to policy"
            echo "  restore    - Restore files from a snapshot"
            exit 1
            ;;
        esac
      '')
    ];

    # Create launchd agent for scheduled backups
    launchd.user.agents.restic-backup = {
      script = ''
        # Only run if restic config exists
        if [ -f "$HOME/.config/restic/s3-env" ] && [ -f "$HOME/.config/restic/password" ]; then
          ${pkgs.restic}/bin/restic-backup backup
        fi
      '';

      serviceConfig = {
        StartCalendarInterval = [
          {
            Hour = 2;
            Minute = 0;
          }
        ];
        StandardOutPath = "/tmp/restic-backup.log";
        StandardErrorPath = "/tmp/restic-backup.err";
      };
    };

    # Age secrets configuration
    age.secrets = {
      "restic-password" = {
        file = "${secretsPath}/global/restic/password.age";
        path = "${config.users.users.jamesbrink.home}/.config/restic/password";
        owner = "jamesbrink";
        mode = "0400";
      };
      "restic-s3-env" = {
        file = "${secretsPath}/global/restic/s3-env.age";
        path = "${config.users.users.jamesbrink.home}/.config/restic/s3-env";
        owner = "jamesbrink";
        mode = "0400";
      };
    };
  };
}
