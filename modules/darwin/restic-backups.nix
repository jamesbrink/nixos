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

      paths = mkOption {
        type = types.listOf types.str;
        default = [
          "$HOME"
        ];
        description = "Paths to backup";
      };

      exclude = mkOption {
        type = types.listOf types.str;
        default = [
          "*.cache"
          "*.trash"
          "node_modules"
          ".DS_Store"
          "*.tmp"
          "*.temp"
          "*.swp"
          "$HOME/Library/Caches"
          "$HOME/Library/Logs"
          "$HOME/Library/Application Support/Steam"
          "$HOME/.Trash"
          "$HOME/.cache"
          "$HOME/.local/share/Trash"
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
          "$HOME/.cache/huggingface"
          "$HOME/stable-diffusion-webui/models"
          "$HOME/ComfyUI/models"
          "$HOME/.ollama/models"
        ];
        description = "Patterns to exclude from backup";
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
  };

  config = mkIf config.programs.restic-backups.enable {
    # Install restic package
    environment.systemPackages = with pkgs; [
      restic

      # Create a helper script for manual backups
      (writeShellScriptBin "restic-backup" ''
        #!/usr/bin/env bash
        set -euo pipefail

        # Function to run restic with credentials loaded in a subshell
        run_restic() {
          (
            # Set PATH to include restic
            export PATH="${pkgs.restic}/bin:$PATH"

            # Load environment variables only for this restic invocation
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

            # Execute restic with all arguments
            restic "$@"
          )
        }

        # Default paths to backup (from configuration)
        BACKUP_PATHS=(
          ${lib.concatMapStringsSep " " (path: ''"${path}"'') config.programs.restic-backups.paths}
        )

        # Exclude patterns (from configuration)
        EXCLUDE_PATTERNS=(
          ${lib.concatMapStringsSep " " (pattern: ''"${pattern}"'') config.programs.restic-backups.exclude}
        )

        # Build exclude arguments
        EXCLUDE_ARGS=""
        for pattern in "''${EXCLUDE_PATTERNS[@]}"; do
          EXCLUDE_ARGS="$EXCLUDE_ARGS --exclude=\"$pattern\""
        done

        case "''${1:-}" in
          init)
            echo "Initializing Restic repository..."
            run_restic init
            ;;
          backup)
            # Note: We need to get the repository info outside the subshell for the echo
            REPO_NAME="s3:s3.us-west-2.amazonaws.com/urandom-io-backups/$(hostname -s)"
            echo "Starting backup to $REPO_NAME..."
            # Check if repository exists, initialize if not
            if ! run_restic snapshots &>/dev/null; then
              echo "Repository does not exist. Initializing..."
              run_restic init || { echo "Failed to initialize repository"; exit 1; }
            fi
            # Run backup in subshell with credentials
            (
              # Load environment variables for the backup command
              if [ -f "$HOME/.config/restic/s3-env" ]; then
                set -a
                source "$HOME/.config/restic/s3-env"
                set +a
              fi
              export RESTIC_REPOSITORY="$REPO_NAME"
              [ -f "$HOME/.config/restic/password" ] && export RESTIC_PASSWORD_FILE="$HOME/.config/restic/password"
              
              eval restic backup --compression max --verbose $EXCLUDE_ARGS "''${BACKUP_PATHS[@]}"
            )
            ;;
          snapshots)
            run_restic snapshots
            ;;
          check)
            run_restic check
            ;;
          prune)
            run_restic forget --prune ${lib.concatStringsSep " " config.programs.restic-backups.pruneOpts}
            ;;
          restore)
            if [ -z "''${2:-}" ]; then
              echo "Usage: restic-backup restore <snapshot-id> [target-path]"
              exit 1
            fi
            TARGET="''${3:-restored-files}"
            run_restic restore "''${2}" --target "$TARGET"
            ;;
          status)
            echo "Launchd backup agent status:"
            launchctl list | grep restic-backup || echo "restic-backup agent not found"
            echo ""
            echo "Log files:"
            echo "  stdout: /tmp/restic-backup.log"
            echo "  stderr: /tmp/restic-backup.err"
            ;;
          logs)
            echo "=== Recent stdout logs ==="
            tail -n 50 /tmp/restic-backup.log 2>/dev/null || echo "No stdout logs found"
            echo ""
            echo "=== Recent stderr logs ==="
            tail -n 50 /tmp/restic-backup.err 2>/dev/null || echo "No stderr logs found"
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
            echo "  status     - Show launchd agent status"
            echo "  logs       - Show recent backup logs"
            echo ""
            echo "Note: Automatic backups run daily at 2:00 AM via launchd"
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
          # Run backup in a clean environment without polluting the shell
          exec /run/current-system/sw/bin/restic-backup backup
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
