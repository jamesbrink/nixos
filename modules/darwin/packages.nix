{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  environment.systemPackages =
    with pkgs;
    [
      # Core utilities
      coreutils
      findutils
      gnugrep
      gnused
      gawk

      # Development tools
      git
      gh
      direnv

      # System tools
      htop
      btop
      duf

      # Note: ncdu and other disk usage analyzers are in modules/home-manager/cli-tools.nix
    ]
    ++ [
      # Network tools
      wget
      curl
      nmap

      # File management
      ripgrep
      fd
      bat
      eza
      tree

      # Text processing
      jq
      yq

      # Archive tools
      unzip
      p7zip

      # Security tools
      age

      # macOS specific
      mas # Mac App Store CLI
      dockutil
      grandperspective # Visual disk usage analyzer for macOS
      macmon # Sudoless performance monitoring for Apple Silicon

      # From unstable
      pkgs.unstablePkgs.atuin
    ];
}
