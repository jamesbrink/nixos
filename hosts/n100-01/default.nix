{
  config,
  pkgs,
  lib,
  inputs,
  secretsPath,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ../../profiles/n100/default.nix
  ];

  # Host-specific configuration
  networking.hostName = "n100-01";
  networking.hostId = "1990e8c0"; # Required for ZFS

  # Override disk device if needed (default is /dev/sda)
  # disko.devices.disk.main.device = "/dev/nvme0n1";
}

