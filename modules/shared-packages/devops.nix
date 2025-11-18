{ pkgs, ... }:

let
  # Pin terraform-docs to a working nixpkgs revision (before the flake update)
  # This fixes the Go compilation error
  pinnedNixpkgs =
    import
      (builtins.fetchTarball {
        url = "https://github.com/NixOS/nixpkgs/archive/3016b4b15d13f3089db8a41ef937b13a9e33a8df.tar.gz";
        # sha256 will be computed on first build
      })
      {
        system = pkgs.stdenv.hostPlatform.system;
        config.allowUnfree = true;
      };
in
{
  environment.systemPackages = with pkgs; [
    act
    atool
    awscli2
    certbot
    cmake
    cw
    devbox
    devpod
    devpod-desktop
    gcc
    gh
    git-crypt
    git-secrets
    gnumake
    helm
    helm-ls
    incus
    infracost
    jdk
    kind
    kubectl
    kubectx
    kubescape
    lego
    libxisf
    mtr
    nodejs
    open-vm-tools
    opentofu
    openvpn3
    openvswitch
    packer
    podman-compose
    postgresql
    pre-commit
    restic
    restique
    ripgrep
    rng-tools
    rustfmt
    rustup
    shellcheck
    sshpass
    starship
    tailscale
    talosctl
    pinnedNixpkgs.terraform-docs # Pinned to working revision due to Go compilation issues
    terraform-lsp
    tflint
    tig
    treefmt
    uv
    webhook
    websocat
    websocketd
    yq-go
    zellij
    zfs
  ];
}
