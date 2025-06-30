{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # DevOps tools that are compatible with darwin
    act
    atool
    awscli2
    cmake
    gh
    git-crypt
    git-secrets
    gnumake
    # helm # Not available on darwin - use homebrew instead
    # helm-ls # Depends on helm
    infracost
    jdk
    kind
    kubectl
    kubectx
    kubescape
    # nodejs # Using Homebrew's version instead (provides npm and npx)
    opentofu
    packer
    postgresql
    pre-commit
    restic
    ripgrep
    rustfmt
    rustup
    shellcheck
    sshpass
    starship
    tailscale
    talosctl
    terraform-docs
    terraform-lsp
    tflint
    tig
    treefmt
    # uv # Moved to Homebrew for darwin to match old setup
    webhook
    websocat
    websocketd
    yq-go
    zellij

    # Note: The following packages are excluded on darwin:
    # - certbot (requires linux-specific features)
    # - cw (CloudWatch tools, may have issues)
    # - devbox (needs testing)
    # - devpod/devpod-desktop (GUI app, use homebrew)
    # - incus (Linux containers)
    # - lego (ACME client, may need config)
    # - libxisf (astronomy lib, rarely needed)
    # - mtr (network tool, use homebrew)
    # - open-vm-tools (VMware, Linux-specific)
    # - openvpn3 (use homebrew)
    # - openvswitch (Linux networking)
    # - postgis-reset (custom package, needs porting)
    # - restique (may have Linux dependencies)
    # - rng-tools (Linux entropy)
    # - zfs (filesystem, macOS has own implementation)
  ];
}
