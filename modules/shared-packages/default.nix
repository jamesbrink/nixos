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
      inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
      bandwhich
      bfg-repo-cleaner
      bzip2
      cargo
      rustc
      gcc
      cachix
      dig
      dnsutils
      fastfetch
      fh # FlakeHub CLI
      git-lfs
      gitleaks
      bitwarden-cli
      gogcli
      google-cloud-sdk
      home-manager
      httpie
      jq
      lf
      lsof
      neovim-remote
      netcat
      nixfmt
      nixpkgs-fmt
      openssh
      p7zip
      # Language servers for Neovim (kept here for system-wide availability)
      bash-language-server
      terraform-ls
      marksman
      nil
      nvd
      rsync
      screen
      ookla-speedtest # Official Ookla CLI (unfree); speedtest-cli below is the OSS Python client
      speedtest-cli
      tmuxinator
      terraform
      tree
      unzip
      viu
      watch
      wget
      wireguard-tools
      yarn
      zed-editor
      zellij
      # Additional development and utility tools
      act
      code2prompt
      (callPackage ../../pkgs/create-context-model { })
      llm
      opencode
      nushell
      slack-cli
      asciinema
      asciinema-agg
      bun
      cloudflared
      flarectl
      nodejs
      pnpm
      # TEMP: disabled — mold flake does live `bun install` in build phase,
      # hits npm registry and hangs on aarch64-darwin. See utensils/mold#TBD.
      # inputs.mold.packages.${pkgs.stdenv.hostPlatform.system}.default
    ]
    ++ lib.optionals (!pkgs.stdenv.isDarwin) [
      # The Darwin build for Cloudflare Wrangler can fail inside tsup with EBADF;
      # macOS hosts install the CLI through Homebrew as cloudflare-wrangler.
      wrangler
    ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      # Code editors - Cursor on Linux (macOS uses Homebrew cask)
      unstable.code-cursor
      # Linux-only packages
      virt-viewer
      below
      gcr # Provides org.gnome.keyring.SystemPrompter for libsecret
      libsecret
      fio
      hdparm
      inxi
      iperf2
      ipmitool
      nfs-utils
      nvme-cli
      parted
      signal-cli
      sysstat
      usbutils # lsusb and friends for USB device inspection
      # GUI applications (Linux-only, macOS uses Homebrew casks)
      meld
      telegram-desktop
      wireshark
      # Zen Browser (twilight version for reproducibility)
      inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.twilight
    ];
}
