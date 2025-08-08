{
  pkgs,
  config,
  lib,
  inputs,
  ...
}:

let
  unstable = pkgs.unstablePkgs;
in
{
  environment.systemPackages =
    with pkgs;
    [
      age
      inputs.agenix.packages.${pkgs.system}.default
      bandwhich
      bfg-repo-cleaner
      bzip2
      cachix
      dig
      dnsutils
      fastfetch
      git-lfs
      gitleaks
      home-manager
      httpie
      jq
      lf
      lsof
      neofetch
      netcat
      nixfmt-rfc-style
      nixpkgs-fmt
      openssh
      p7zip
      # Language servers for Neovim (kept here for system-wide availability)
      nodePackages.bash-language-server
      terraform-ls
      marksman
      nil
      rsync
      screen
      speedtest-cli
      restic-browser
      tree
      unzip
      virt-viewer
      watch
      wget
      wireguard-tools
      yarn
      # Additional development and utility tools
      act
      code2prompt
      llm
      nushell
      slack-cli
      nodejs
      nodePackages.pnpm
    ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      # Code editors - Cursor on Linux (macOS uses Homebrew cask)
      unstable.code-cursor
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
      # GUI applications (Linux-only, macOS uses Homebrew casks)
      meld
      wireshark
      # Zen Browser (twilight version for reproducibility)
      inputs.zen-browser.packages.${pkgs.system}.twilight
    ];
}
