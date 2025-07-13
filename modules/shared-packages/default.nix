{
  pkgs,
  config,
  lib,
  inputs,
  ...
}:

{
  environment.systemPackages =
    with pkgs;
    [
      age
      inputs.agenix.packages.${pkgs.system}.default
      bandwhich
      bat
      (btop.override {
        cudaSupport = pkgs.stdenv.isLinux && (config.hardware.nvidia.package or null) != null;
      })
      bzip2
      cachix
      dig
      direnv
      dnsutils
      fastfetch
      fd
      git
      home-manager
      htop
      httpie
      jq
      lf
      lsof
      neofetch
      neovim
      netcat
      nixfmt-rfc-style
      nixpkgs-fmt
      openssh
      p7zip
      python311Full
      python311Packages.boto3
      python311Packages.pip
      python311Packages.pynvim
      rsync
      screen
      speedtest-cli
      pay-respects
      tmux
      tree
      unzip
      vim
      virt-viewer
      wget
      wireguard-tools
      zsh
    ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      # Linux-only packages
      bitwarden-cli
      fio
      hdparm
      inxi
      iperf2
      ipmitool
      nfs-utils
      nvme-cli
      parted
      sysstat
      # ML packages (heavy dependencies, Linux-only for now)
      python311Packages.torch
      python311Packages.torchvision
      python311Packages.torchaudio
      python311Packages.tensorflow
      python311Packages.huggingface-hub
      python311Packages.llvmlite
      python311Packages.numba
    ];
}
