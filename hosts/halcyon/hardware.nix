{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Hardware configuration for M4 Mac (minimal for darwin)
  # Most hardware is managed by macOS directly

  # Enable Rosetta for x86_64 emulation
  nix.extraOptions = ''
    extra-platforms = x86_64-darwin aarch64-darwin
  '';

  # Remote builders for Linux builds
  # hal9000 is x86_64-linux with binfmt emulation for aarch64-linux
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
