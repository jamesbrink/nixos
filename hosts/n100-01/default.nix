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
  networking.hostName = "n100-01";
  networking.hostId = "1990e8c0"; # Required for ZFS

  # K3s cluster configuration
  services.k3s-cluster.hostname = "n100-01";

  # Age secrets
  age.secrets."k3s-token".file = "${secretsPath}/n100-01/k3s-token.age";

  # Let SSH generate its own host keys on first boot
  # This avoids dependency on agenix secrets during initial installation

  # Override disk device if needed (default is /dev/sda)
  # disko.devices.disk.main.device = "/dev/nvme0n1";

  # Zerobyte backup management service
  services.zerobyte = {
    enable = true;
    port = 4096;
    openFirewall = true;
  };
}
