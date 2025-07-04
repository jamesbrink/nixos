{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.netbootConfigs;

  # Generate a single node configuration
  generateNodeConfig =
    name: node:
    pkgs.writeText "${node.macAddress}.yaml" ''
      # N100 Configuration for ${name}
      # MAC Address: ${node.macAddress}
      ---
      hostname: ${name}
      mac_address: ${node.macAddress}
      install_options:
        disk: ${node.disk}
        zfs_pool: ${node.zfsPool}
        network:
          dhcp: ${if node.dhcp then "true" else "false"}
    '';

in
{
  options.services.netbootConfigs = {
    enable = mkEnableOption "N100 netboot configuration file generation";

    configDir = mkOption {
      type = types.path;
      default = "/export/storage-fast/netboot/configs";
      description = "Directory where netboot configuration files will be stored";
    };

    nodes = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            macAddress = mkOption {
              type = types.str;
              description = "MAC address of the node";
              example = "e0:51:d8:12:ba:97";
            };

            disk = mkOption {
              type = types.str;
              default = "/dev/nvme0n1";
              description = "Disk device for installation";
            };

            zfsPool = mkOption {
              type = types.str;
              default = "rpool";
              description = "ZFS pool name";
            };

            dhcp = mkOption {
              type = types.bool;
              default = true;
              description = "Whether to use DHCP for network configuration";
            };
          };
        }
      );
      default = { };
      description = "N100 nodes configuration";
      example = literalExpression ''
        {
          "n100-01" = {
            macAddress = "e0:51:d8:12:ba:97";
            disk = "/dev/nvme0n1";
            zfsPool = "rpool";
            dhcp = true;
          };
        }
      '';
    };
  };

  config = mkIf cfg.enable {
    # Create the config directory
    systemd.tmpfiles.rules = [
      "d ${cfg.configDir} 0755 nginx nginx -"
    ];

    # Generate configuration files using systemd service
    systemd.services.netboot-configs = {
      description = "Generate N100 netboot configuration files";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-tmpfiles-setup.service" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "nginx";
        Group = "nginx";
      };

      script = ''
        # Generate configuration files for each node
        ${concatStringsSep "\n" (
          mapAttrsToList (name: node: ''
              echo "Generating config for ${name} (${node.macAddress})"
              cat > "${cfg.configDir}/${node.macAddress}.yaml" <<'EOF'
            # N100 Configuration for ${name}
            # MAC Address: ${node.macAddress}
            ---
            hostname: ${name}
            mac_address: ${node.macAddress}
            install_options:
              disk: ${node.disk}
              zfs_pool: ${node.zfsPool}
              network:
                dhcp: ${if node.dhcp then "true" else "false"}
            EOF
          '') cfg.nodes
        )}

        echo "Netboot configurations generated successfully"
      '';
    };
  };
}
