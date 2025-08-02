{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.services.samba-server;
in
{
  options.services.samba-server = {
    enable = mkEnableOption "Samba file sharing server";

    workgroup = mkOption {
      type = types.str;
      default = "WORKGROUP";
      description = "The workgroup name for the Samba server";
    };

    serverString = mkOption {
      type = types.str;
      default = config.networking.hostName;
      description = "Server description shown to clients";
    };

    allowedNetworks = mkOption {
      type = types.listOf types.str;
      default = [
        "10.70.100.0/24"
        "100.64.0.0/10"
      ];
      description = "List of allowed networks in CIDR notation";
    };

    shares = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            path = mkOption {
              type = types.str;
              description = "Path to the shared directory";
            };
            comment = mkOption {
              type = types.str;
              default = "";
              description = "Share description";
            };
            browseable = mkOption {
              type = types.bool;
              default = true;
              description = "Whether the share is visible in browse lists";
            };
            readOnly = mkOption {
              type = types.bool;
              default = false;
              description = "Whether the share is read-only";
            };
            guestOk = mkOption {
              type = types.bool;
              default = false;
              description = "Whether to allow guest access";
            };
            validUsers = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "List of users allowed to access this share";
            };
            forceUser = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Force all file operations to use this user";
            };
            forceGroup = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Force all file operations to use this group";
            };
            createMask = mkOption {
              type = types.str;
              default = "0664";
              description = "File creation mask";
            };
            directoryMask = mkOption {
              type = types.str;
              default = "0775";
              description = "Directory creation mask";
            };
          };
        }
      );
      default = { };
      description = "Samba share definitions";
    };

    enableWins = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable WINS server";
    };

    enableWSDD = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Web Service Discovery for Windows 10/11";
    };

    enableTimeMachine = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Time Machine support for macOS";
    };

    timeMachineShares = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "List of share names to enable Time Machine on";
    };
  };

  config = mkIf cfg.enable {
    # Install Samba and related packages
    environment.systemPackages =
      with pkgs;
      [
        samba
      ]
      ++ optional cfg.enableWSDD wsdd;

    # Configure Samba
    services.samba = {
      enable = true;
      package = pkgs.samba4Full;
      openFirewall = true;

      settings = {
        global = {
          workgroup = cfg.workgroup;
          "server string" = cfg.serverString;
          "server role" = "standalone";
          security = "user";
          "map to guest" = "never";
          "guest account" = "nobody";

          # Protocol settings - Critical for macOS compatibility
          "server min protocol" = "SMB2";
          "server max protocol" = "SMB3"; # Explicitly set max protocol
          "client min protocol" = "SMB2";
          "client max protocol" = "SMB3";
          "server smb encrypt" = "if_required"; # Changed from 'desired' for better compatibility
          "ntlm auth" = "ntlmv2-only"; # Force NTLMv2 for macOS
          "raw NTLMv2 auth" = "yes";

          # Additional macOS compatibility
          "ea support" = "yes";
          "inherit acls" = "yes";
          "map acl inherit" = "yes";

          # Performance settings - Simplified for compatibility
          "socket options" = "TCP_NODELAY"; # Removed buffer size overrides
          "use sendfile" = "yes";
          "aio read size" = "1";
          "aio write size" = "1";
          "min receivefile size" = "16384";
          "getwd cache" = "yes";
          "read raw" = "yes";
          "write raw" = "yes";
          "strict locking" = "no";

          # Network restrictions
          "hosts allow" = concatStringsSep " " (cfg.allowedNetworks ++ [ "127.0.0.1" ]);
          "hosts deny" = "0.0.0.0/0";

          # Logging
          "log file" = "/var/log/samba/log.%m";
          "max log size" = "50";
          "log level" = "1";

          # NetBIOS settings
          "netbios name" = config.networking.hostName;
          "wins support" = if cfg.enableWins then "yes" else "no";
          "dns proxy" = "no";

          # Misc settings
          "load printers" = "no";
          "printing" = "bsd";
          "printcap name" = "/dev/null";
          "disable spoolss" = "yes";
          "multicast dns register" = "yes"; # Help with macOS discovery
          "unix extensions" = "no"; # Disable for better macOS compatibility

          # macOS compatibility - MUST be in this order
          "vfs objects" = "catia fruit streams_xattr";
          "fruit:metadata" = "stream";
          "fruit:model" = "MacSamba";
          "fruit:veto_appledouble" = "no";
          "fruit:posix_rename" = "yes";
          "fruit:zero_file_id" = "yes";
          "fruit:wipe_intentionally_left_blank_rfork" = "yes";
          "fruit:delete_empty_adfiles" = "yes";
          "fruit:nfs_aces" = "no";
          "fruit:encoding" = "native";

          # Additional macOS optimizations
          "veto files" = "/._*/.DS_Store/";
          "delete veto files" = "yes";
        };
      }
      // mapAttrs (
        name: share:
        {
          path = share.path;
          comment = share.comment;
          browseable = if share.browseable then "yes" else "no";
          "read only" = if share.readOnly then "yes" else "no";
          "guest ok" = if share.guestOk then "yes" else "no";
          "create mask" = share.createMask;
          "directory mask" = share.directoryMask;
        }
        // optionalAttrs (share.validUsers != [ ]) {
          "valid users" = concatStringsSep " " share.validUsers;
        }
        // optionalAttrs (share.forceUser != null) {
          "force user" = share.forceUser;
        }
        // optionalAttrs (share.forceGroup != null) {
          "force group" = share.forceGroup;
        }
        // optionalAttrs (cfg.enableTimeMachine && elem name cfg.timeMachineShares) {
          "fruit:time machine" = "yes";
          "fruit:time machine max size" = "0";
        }
      ) cfg.shares;
    };

    # Configure WSDD for Windows network discovery
    systemd.services.wsdd = mkIf cfg.enableWSDD {
      description = "Web Service Discovery Daemon";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.wsdd}/bin/wsdd --workgroup ${cfg.workgroup} --hostname ${config.networking.hostName} ${
          concatMapStringsSep " " (net: "--listen ${net}") cfg.allowedNetworks
        }";
        Restart = "always";
        RestartSec = "10s";
        User = "nobody";
        Group = "nogroup";
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        NoNewPrivileges = true;
      };
    };

    # Additional firewall rules
    networking.firewall = {
      allowedTCPPorts = [
        445 # SMB
        139 # NetBIOS Session Service
      ]
      ++ optional cfg.enableWSDD 5357; # WSDD

      allowedUDPPorts = [
        137 # NetBIOS Name Service
        138 # NetBIOS Datagram Service
      ]
      ++ optional cfg.enableWSDD 3702; # WSDD
    };

    # Create log directory
    systemd.tmpfiles.rules = [
      "d /var/log/samba 0750 root root -"
    ];
  };
}
