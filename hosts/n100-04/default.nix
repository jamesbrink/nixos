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
    # GNOME desktop with X11, XRDP, and RustDesk
    ../../profiles/desktop/gnome.nix
  ];

  # Host-specific configuration
  networking.hostName = "n100-04";
  networking.hostId = "ce7b643e"; # Keep existing hostId for ZFS compatibility

  # Let SSH generate its own host keys on first boot
  # This avoids dependency on agenix secrets during initial installation

  # Override disk device if needed (default is /dev/nvme0n1)
  # disko.devices.disk.main.device = "/dev/sda";
}
