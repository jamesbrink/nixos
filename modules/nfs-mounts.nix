# Shared NFS mount configuration for Linux hosts
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  # Define all available NFS shares
  nfsShares = [
    {
      name = "storage";
      server = "alienware.home.urandom.io";
      path = "/export/storage";
      mountPoint = "/mnt/nfs/storage";
    }
    {
      name = "data";
      server = "alienware.home.urandom.io";
      path = "/export/data";
      mountPoint = "/mnt/nfs/data";
    }
    {
      name = "storage-fast";
      server = "hal9000.home.urandom.io";
      path = "/export/storage-fast";
      mountPoint = "/mnt/nfs/storage-fast";
    }
    {
      name = "n100-01";
      server = "n100-01.home.urandom.io";
      path = "/export";
      mountPoint = "/mnt/nfs/n100-01";
    }
    {
      name = "n100-02";
      server = "n100-02.home.urandom.io";
      path = "/export";
      mountPoint = "/mnt/nfs/n100-02";
    }
    {
      name = "n100-03";
      server = "n100-03.home.urandom.io";
      path = "/export";
      mountPoint = "/mnt/nfs/n100-03";
    }
    {
      name = "n100-04";
      server = "n100-04.home.urandom.io";
      path = "/export";
      mountPoint = "/mnt/nfs/n100-04";
    }
  ];

  # Common NFS mount options
  mountOptions = "noatime,noauto,x-systemd.automount,x-systemd.device-timeout=10,x-systemd.idle-timeout=600";

  # Function to create systemd mount unit
  mkNfsMount = share: {
    type = "nfs";
    what = "${share.server}:${share.path}";
    where = share.mountPoint;
    mountConfig = {
      Options = mountOptions;
    };
  };

  # Function to create systemd automount unit
  mkNfsAutomount = share: {
    where = share.mountPoint;
    wantedBy = [ "multi-user.target" ];
    automountConfig = {
      TimeoutIdleSec = "600";
    };
  };

  # Filter out mounts where the server is the current host
  filteredShares = builtins.filter (
    share:
    # Don't mount exports from ourselves
    share.server != "${config.networking.hostName}.${config.networking.domain or "home.urandom.io"}"
  ) nfsShares;
in
{
  # Create mount directories
  systemd.tmpfiles.rules = map (share: "d ${share.mountPoint} 0755 root root -") filteredShares;

  # Create systemd mount units
  systemd.mounts = map mkNfsMount filteredShares;

  # Create systemd automount units
  systemd.automounts = map mkNfsAutomount filteredShares;

  # Ensure NFS utilities are installed
  environment.systemPackages = with pkgs; [
    nfs-utils
  ];
}
