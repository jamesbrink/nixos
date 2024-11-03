{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # 1. Cloud Provider Tools
    awscli2

    # 2. Container Tools
    incus
    kind
    kubectl
    kubectx

    # 3. Infrastructure as Code
    opentofu
    packer
    terraform-docs
    terraform-lsp
    tflint

    # 4. Version Control & Security
    git-crypt
    git-secrets

    # 5. Development Tools
    cmake
    gnumake
    jdk
    rustfmt
    rustup
    shellcheck

    # 6. Networking Tools
    mtr
    openvswitch

    # 7. System Tools
    atool
    open-vm-tools
    rng-tools
    zfs

    # 8. Security & Certificate Management
    certbot
    lego

    # 9. Monitoring & Logging
    cw

    # 10. Development Environment
    devbox
    nerdfonts
    pre-commit
    starship
    zellij

    # 11. Backup Tools
    restic
    restique

    # 12. Search Tools
    ripgrep

    # 13. Remote Access
    sshpass
    tailscale

    # 14. Image Processing
    libxisf
  ];
}
