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
  networking.hostName = "n100-02";
  networking.hostId = "c6eb893b"; # Required for ZFS

  # Let SSH generate its own host keys on first boot
  # This avoids dependency on agenix secrets during initial installation

  # Override disk device if needed (default is /dev/sda)
  # disko.devices.disk.main.device = "/dev/nvme0n1";
}
