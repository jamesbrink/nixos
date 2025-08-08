# Server-specific packages
{ pkgs, ... }:

{
  imports = [
    ../../modules/shared-packages/default.nix
    ../../modules/shared-packages/python.nix
    ../../modules/claude-desktop.nix
    ../../modules/ssh-keys.nix
    ../../modules/nfs-mounts.nix
    ../../modules/local-hosts.nix
    ../../modules/aws-root-config.nix
    ../../users/root.nix
  ];

  # Enable zsh as default shell
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
  };

  # Set zsh as default shell
  users.defaultUserShell = pkgs.zsh;

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
