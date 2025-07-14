{
  config,
  lib,
  pkgs,
  secretsPath,
  ...
}:

with lib;

let
  cfg = config.services.resticBackups;
in
{
  imports = [ ./restic-shell-init.nix ];
  options.services.resticBackups = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Restic backups to S3";
    };

    paths = mkOption {
      type = types.listOf types.str;
      default = [
        "/home"
      ];
      description = "Paths to backup";
    };

    exclude = mkOption {
      type = types.listOf types.str;
      default = [
        "/home/*/.cache"
        "/home/*/.local/share/Trash"
        "/home/*/.local/share/Steam"
        "/home/*/Downloads"
        "/home/*/.config/Code/Cache"
        "/home/*/.config/Code/CachedData"
        "/home/*/.mozilla/firefox/*/cache*"
        "/home/*/.thunderbird/*/cache*"
        "node_modules"
        "*.tmp"
        "*.temp"
        "*.swp"
        ".DS_Store"
        # AI/LLM model files
        "*.safetensors"
        "*.ckpt"
        "*.pt"
        "*.pth"
        "*.bin"
        "*.onnx"
        "*.gguf"
        "*.ggml"
        "*.q4_0"
        "*.q4_1"
        "*.q5_0"
        "*.q5_1"
        "*.q8_0"
        "*.f16"
        "*.f32"
        "*.pkl"
        "*.h5"
        "*.msgpack"
        "*.npz"
        "*.tflite"
        "*.pb"
        "*.mlmodel"
        # Model directories
        "/home/*/.cache/huggingface"
        "/home/*/stable-diffusion-webui/models"
        "/home/*/ComfyUI/models"
        "/home/*/.ollama/models"
        "/var/lib/docker/volumes/ollama"
        "/var/lib/containers/storage/volumes/ollama"
      ];
      description = "Patterns to exclude from backup";
    };

    timerConfig = mkOption {
      type = types.attrs;
      default = {
        OnCalendar = "daily";
        RandomizedDelaySec = "4h";
        Persistent = true;
      };
      description = "Systemd timer configuration";
    };

    pruneOpts = mkOption {
      type = types.listOf types.str;
      default = [
        "--keep-daily 7"
        "--keep-weekly 4"
        "--keep-monthly 12"
        "--keep-yearly 2"
      ];
      description = "Restic prune options";
    };
  };

  config = mkIf cfg.enable {
    # Ensure restic is installed
    environment.systemPackages = [
      pkgs.restic

      # Create a helper script for manual backups (matching Darwin functionality)
      (pkgs.writeShellScriptBin "restic-backup" ''
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

        # Default paths to backup (matching the service configuration)
        BACKUP_PATHS=(
          ${lib.concatMapStringsSep " " (path: ''"${path}"'') cfg.paths}
        )

        # Exclude patterns
        EXCLUDE_PATTERNS=(
          ${lib.concatMapStringsSep " " (pattern: ''"${pattern}"'') cfg.exclude}
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
            # Check if repository exists, initialize if not
            if ! restic snapshots &>/dev/null; then
              echo "Repository does not exist. Initializing..."
              restic init || { echo "Failed to initialize repository"; exit 1; }
            fi
            eval restic backup --compression max --verbose $EXCLUDE_ARGS "''${BACKUP_PATHS[@]}"
            ;;
          snapshots)
            restic snapshots
            ;;
          check)
            restic check
            ;;
          prune)
            restic forget --prune ${lib.concatStringsSep " " cfg.pruneOpts}
            ;;
          restore)
            if [ -z "''${2:-}" ]; then
              echo "Usage: restic-backup restore <snapshot-id> [target-path]"
              exit 1
            fi
            TARGET="''${3:-restored-files}"
            restic restore "''${2}" --target "$TARGET"
            ;;
          status)
            echo "Systemd backup service status:"
            systemctl status restic-backups-s3-backup.service || true
            echo ""
            echo "Timer status:"
            systemctl status restic-backups-s3-backup.timer || true
            ;;
          logs)
            journalctl -u restic-backups-s3-backup.service --no-pager -n 50
            ;;
          *)
            echo "Usage: restic-backup {init|backup|snapshots|check|prune|restore|status|logs}"
            echo ""
            echo "Commands:"
            echo "  init       - Initialize a new repository"
            echo "  backup     - Run a manual backup"
            echo "  snapshots  - List snapshots"
            echo "  check      - Check repository integrity"
            echo "  prune      - Remove old snapshots according to policy"
            echo "  restore    - Restore files from a snapshot"
            echo "  status     - Show systemd service and timer status"
            echo "  logs       - Show recent backup logs"
            echo ""
            echo "Note: Automatic backups run via systemd timer (${cfg.timerConfig.OnCalendar})"
            exit 1
            ;;
        esac
      '')
    ];

    # Configure the backup job
    services.restic.backups = {
      s3-backup = {
        paths = cfg.paths;
        exclude = cfg.exclude;

        repository = "s3:s3.us-west-2.amazonaws.com/urandom-io-backups/${config.networking.hostName}";

        passwordFile = config.age.secrets."restic-password".path;
        environmentFile = config.age.secrets."restic-s3-env".path;

        initialize = true;

        timerConfig = cfg.timerConfig;
        pruneOpts = cfg.pruneOpts;

        extraBackupArgs = [
          "--compression max"
          "--verbose"
        ];
      };
    };

    # Age secrets configuration
    age.secrets = {
      "restic-password" = {
        file = "${secretsPath}/global/restic/password.age";
        owner = "root";
        group = "root";
        mode = "0400";
      };
      "restic-s3-env" = {
        file = "${secretsPath}/global/restic/s3-env.age";
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };

    # Create restic configuration for all users
    system.activationScripts.setupResticForUsers = lib.stringAfter [ "users" "groups" ] ''
      # Setup restic config for root
      mkdir -p /root/.config/restic
      ln -sf ${config.age.secrets."restic-password".path} /root/.config/restic/password
      ln -sf ${config.age.secrets."restic-s3-env".path} /root/.config/restic/s3-env

      # Setup restic config for regular users
      for user in jamesbrink; do
        if id "$user" &>/dev/null; then
          user_home=$(eval echo ~$user)
          if [ -d "$user_home" ]; then
            mkdir -p "$user_home/.config/restic"
            chown $user:users "$user_home/.config/restic"
            
            # Copy the files instead of symlinking to avoid permission issues
            cp ${config.age.secrets."restic-password".path} "$user_home/.config/restic/password"
            cp ${config.age.secrets."restic-s3-env".path} "$user_home/.config/restic/s3-env"
            
            # Set proper ownership and permissions
            chown $user:users "$user_home/.config/restic/password"
            chown $user:users "$user_home/.config/restic/s3-env"
            chmod 0400 "$user_home/.config/restic/password"
            chmod 0400 "$user_home/.config/restic/s3-env"
          fi
        fi
      done
    '';
  };
}
