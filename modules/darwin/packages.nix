{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  environment.systemPackages = with pkgs; [
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
    ncdu
    duf

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
    inputs.agenix.packages.${pkgs.system}.default

    # macOS specific
    mas # Mac App Store CLI
    dockutil

    # From unstable
    pkgs.unstablePkgs.atuin
  ];
}
