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
    # Enable XFCE desktop for RustDesk and XRDP remote access
    ../../profiles/desktop/xfce.nix
  ];

  # Host-specific configuration
  networking.hostName = "n100-03";
  networking.hostId = "23b445bd"; # Required for ZFS

  # Let SSH generate its own host keys on first boot
  # This avoids dependency on agenix secrets during initial installation

  # Override disk device if needed (default is /dev/sda)
  # disko.devices.disk.main.device = "/dev/nvme0n1";
}
