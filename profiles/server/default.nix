# Server-specific packages
{ pkgs, ... }:

{
  imports = [
    ../../modules/shared-packages/default.nix
    ../../modules/claude-desktop.nix
    ../../modules/ssh-keys.nix
    ../../modules/nfs-mounts.nix
    ../../modules/local-hosts.nix
  ];

  environment.systemPackages = with pkgs; [
    # Infrastructure tools
    ansible
    awscli2
    docker
    kubectl
    k3s
    terraform-lsp
    opentofu

    # Monitoring and maintenance
    iperf2
    ipmitool
    speedtest-cli

    # Security
    git-crypt
    git-secrets

    # Networking
    tailscale
  ];
}
