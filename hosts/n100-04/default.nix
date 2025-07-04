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

  # SSH host keys managed through agenix
  age.secrets = {
    "ssh_host_ed25519_key" = {
      file = "${secretsPath}/secrets/n100-04/ssh/host-ed25519-key.age";
      path = "/etc/ssh/ssh_host_ed25519_key";
      mode = "0600";
      owner = "root";
      group = "root";
    };
    "ssh_host_rsa_key" = {
      file = "${secretsPath}/secrets/n100-04/ssh/host-rsa-key.age";
      path = "/etc/ssh/ssh_host_rsa_key";
      mode = "0600";
      owner = "root";
      group = "root";
    };
  };

  # SSH host key configuration
  services.openssh.hostKeys = [
    {
      path = config.age.secrets."ssh_host_ed25519_key".path;
      type = "ed25519";
    }
    {
      path = config.age.secrets."ssh_host_rsa_key".path;
      type = "rsa";
      bits = 4096;
    }
  ];

  # Override disk device if needed (default is /dev/nvme0n1)
  # disko.devices.disk.main.device = "/dev/sda";
}
