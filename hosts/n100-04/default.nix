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
  networking.hostName = "n100-04";
  networking.hostId = "ce7b643e"; # Keep existing hostId for ZFS compatibility

  # Pre-generated SSH host keys
  age.secrets = {
    "ssh-host-ed25519-key" = {
      file = "${secretsPath}/secrets/n100-04/ssh/host-ed25519-key.age";
      path = "/etc/ssh/ssh_host_ed25519_key";
      mode = "0600";
    };
    "ssh-host-rsa-key" = {
      file = "${secretsPath}/secrets/n100-04/ssh/host-rsa-key.age";
      path = "/etc/ssh/ssh_host_rsa_key";
      mode = "0600";
    };
  };

  # Ensure SSH host keys are used
  services.openssh.hostKeys = [
    {
      path = "/etc/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }
    {
      path = "/etc/ssh/ssh_host_rsa_key";
      type = "rsa";
      bits = 4096;
    }
  ];

  # Override disk device if needed (default is /dev/nvme0n1)
  # disko.devices.disk.main.device = "/dev/sda";
}
