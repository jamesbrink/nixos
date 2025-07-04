# Disko configuration for N100 cluster nodes with ZFS
{ lib, ... }:
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = lib.mkDefault "/dev/nvme0n1"; # Can be overridden per host
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [
                  "fmask=0022"
                  "dmask=0022"
                ];
              };
            };
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zpool";
              };
            };
          };
        };
      };
    };
    zpool = {
      zpool = {
        type = "zpool";
        rootFsOptions = {
          compression = "lz4";
          "com.sun:auto-snapshot" = "false";
          acltype = "posixacl";
          xattr = "sa";
          atime = "off";
          mountpoint = "none";
        };
        options = {
          ashift = "12";
          autotrim = "on";
        };

        datasets = {
          root = {
            type = "zfs_fs";
            mountpoint = "/";
            options = {
              mountpoint = "legacy";
              "com.sun:auto-snapshot" = "false";
            };
          };
          nix = {
            type = "zfs_fs";
            mountpoint = "/nix";
            options = {
              mountpoint = "legacy";
              atime = "off";
              "com.sun:auto-snapshot" = "false";
            };
          };
          var = {
            type = "zfs_fs";
            mountpoint = "/var";
            options = {
              mountpoint = "legacy";
              "com.sun:auto-snapshot" = "false";
            };
          };
          home = {
            type = "zfs_fs";
            mountpoint = "/home";
            options = {
              mountpoint = "legacy";
              "com.sun:auto-snapshot" = "true";
            };
          };
          # Swap zvol instead of swapfile
          swap = {
            type = "zfs_volume";
            size = "16G";
            content = {
              type = "swap";
              priority = 100;
            };
          };
        };
      };
    };
  };
}

