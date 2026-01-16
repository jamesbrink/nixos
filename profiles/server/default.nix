# Server-specific packages
{ pkgs, ... }:

{
  imports = [
    ../../modules/nix-caches.nix
    ../../modules/shared-packages/default.nix
    ../../modules/shared-packages/python.nix
    ../../modules/claude-desktop.nix
    ../../modules/ssh-keys.nix
    ../../modules/nfs-mounts.nix
    ../../modules/local-hosts.nix
    ../../modules/aws-root-config.nix
    ../../users/root.nix
  ];

  # Enable gnome-keyring as Secret Service provider for libsecret
  # Required for CLI tools that store credentials (coderabbit, gh, etc.)
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;

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
