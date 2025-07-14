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
        "/etc/nixos"
        "/home"
        "/root"
        "/var/lib"
      ];
      description = "Paths to backup";
    };

    exclude = mkOption {
      type = types.listOf types.str;
      default = [
        "/home/*/.cache"
        "/home/*/.local/share/Trash"
        "/var/lib/docker"
        "/var/lib/containers"
        "/var/lib/libvirt/images"
        "*.tmp"
        "*.temp"
        "*.swp"
        ".DS_Store"
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
    environment.systemPackages = [ pkgs.restic ];

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
