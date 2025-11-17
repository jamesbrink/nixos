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
      # agenix CLI temporarily disabled due to nix 2.28.3 build failure with Determinate Nix

      # macOS specific
      mas # Mac App Store CLI
      dockutil
      grandperspective # Visual disk usage analyzer for macOS

      # From unstable
      pkgs.unstablePkgs.atuin
    ];
}
