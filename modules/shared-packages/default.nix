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
      cachix
      dig
      dnsutils
      fastfetch
      fh # FlakeHub CLI
      git-lfs
      gitleaks
      home-manager
      httpie
      jq
      lf
      lsof
      neofetch
      neovim-remote
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
      nvd
      rsync
      screen
      speedtest-cli
      tmuxinator
      # restic-browser wrapper added below with credential isolation
      terraform
      tree
      unzip
      virt-viewer
      watch
      wget
      wireguard-tools
      yarn
      zed-editor
      zellij
      # Additional development and utility tools
      act
      code2prompt
      llm
      opencode
      nushell
      slack-cli
      asciinema
      bun
      nodejs
      nodePackages.pnpm
      inputs.why.packages.${pkgs.stdenv.hostPlatform.system}.default

      # Restic browser with credential isolation wrapper
      (pkgs.writeShellScriptBin "restic-browser" ''
        #!/usr/bin/env bash
        # Wrapper for restic-browser that loads credentials in a subshell
        (
          # Load environment variables only for this invocation
          config_dir=""
          
          # Determine config directory based on user
          if [ "$USER" = "root" ]; then
            if [ -f "/root/.config/restic/s3-env" ]; then
              config_dir="/root/.config/restic"
            elif [ -f "/var/root/.config/restic/s3-env" ]; then
              config_dir="/var/root/.config/restic"
            elif [ -n "$SUDO_USER" ] && [ -f "/Users/$SUDO_USER/.config/restic/s3-env" ]; then
              config_dir="/Users/$SUDO_USER/.config/restic"
            elif [ -n "$SUDO_USER" ] && [ -f "/home/$SUDO_USER/.config/restic/s3-env" ]; then
              config_dir="/home/$SUDO_USER/.config/restic"
            fi
          else
            if [ -f "$HOME/.config/restic/s3-env" ]; then
              config_dir="$HOME/.config/restic"
            fi
          fi
          
          # Load environment if config found
          if [ -n "$config_dir" ] && [ -f "$config_dir/s3-env" ]; then
            set -a
            source "$config_dir/s3-env"
            set +a
            export RESTIC_REPOSITORY="s3:s3.us-west-2.amazonaws.com/urandom-io-backups/$(hostname -s)"
            
            if [ -f "$config_dir/password" ]; then
              export RESTIC_PASSWORD_FILE="$config_dir/password"
            fi
            
            # Execute the actual restic-browser command
            exec ${pkgs.restic-browser}/bin/restic-browser "$@"
          else
            echo "Error: Restic S3 environment file not found"
            echo "Please ensure ~/.config/restic/s3-env exists"
            exit 1
          fi
        )
      '')
    ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      # Code editors - Cursor on Linux (macOS uses Homebrew cask)
      unstable.code-cursor
      # Linux-only packages
      below
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
      inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.twilight
    ];
}
