# Hardware configuration for Mac Mini M4 (bender)
{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Enable Rosetta for x86_64 emulation
  nix.extraOptions = ''
    extra-platforms = x86_64-darwin aarch64-darwin
  '';

  # Remote builders for Linux builds (use hal9000 for x86_64-linux and aarch64-linux)
  nix.distributedBuilds = true;
  nix.buildMachines = [
    {
      hostName = "hal9000";
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      protocol = "ssh-ng";
      sshUser = "root";
      maxJobs = 8;
      speedFactor = 2;
      supportedFeatures = [
        "nixos-test"
        "benchmark"
        "big-parallel"
        "kvm"
      ];
    }
  ];
  nix.settings.builders-use-substitutes = true;
}
