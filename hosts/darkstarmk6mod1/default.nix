{
  config,
  pkgs,
  lib,
  inputs,
  secretsPath,
  ...
}:

{
  imports = [
    ./hardware.nix
    ../../profiles/darwin/desktop.nix # Use full desktop profile
    ../../modules/darwin/packages.nix
    ../../modules/darwin/dock.nix
    ../../modules/darwin/restic-backups.nix
    ../../modules/ssh-keys.nix
    ../../users/regular/jamesbrink-darwin.nix
    ../../modules/shared-packages/python.nix
    ../../modules/shared-packages/devops-darwin.nix
  ];

  # TODO: Remove this override once awscli2 tests are fixed on macOS Tahoe
  # The python s3transfer tests fail with "AF_UNIX path too long" on macOS 26 (Tahoe)
  # This issue only affects darkstarmk6mod1 - other Darwin hosts work fine
  nixpkgs.overlays = [
    (final: prev: {
      python313Packages = prev.python313Packages.override {
        overrides = self: super: {
          s3transfer = super.s3transfer.overridePythonAttrs (old: {
            doCheck = false;
            doInstallCheck = false;
          });
        };
      };
    })
  ];

  # Networking
  networking = {
    hostName = "darkstarmk6mod1";
    computerName = "DarkStar MK6 Mod1";
    localHostName = "darkstarmk6mod1";
  };

  # Dock configuration
  programs.dock = {
    enable = true;
    items = [
      { path = "/System/Applications/Messages.app"; }
      { path = "/Applications/Visual Studio Code.app"; }
      { path = "${config.users.users.jamesbrink.home}/.nix-profile/Applications/Alacritty.app"; }
      { path = "/Applications/Ghostty.app"; }
      { path = "/Applications/Claude.app"; }
      { path = "/Applications/Slack.app"; }
      { path = "/Applications/Discord.app"; }
      { path = "/System/Applications/System Settings.app"; }
      {
        path = "${config.users.users.jamesbrink.home}/Downloads";
        section = "others";
        view = "fan"; # Fan style
        display = "folder";
        sort = "dateadded"; # Sort by Date Added
      }
    ];
  };

  # Time zone
  time.timeZone = "America/Phoenix";

  # Additional Homebrew packages specific to this host
  homebrew = {
    brews = [
      "ffmpeg"
      "imagemagick"
      "pinentry-mac"
      "gnupg"
      "helm" # Not available in nixpkgs for darwin
    ];

    casks = [
      # Fonts
      "font-meslo-lg-nerd-font"

      # Development
      "jetbrains-toolbox"
      "postman"
      "firefox@developer-edition"
      "ghostty"
      "sublime-text"
      "podman-desktop"
      "miniconda"

      # Design & Creative
      "inkscape"
      "krita"

      # Communication
      "signal"
      "whatsapp"

      # Productivity
      "alfred"
      "keyboard-maestro"
      "notion"

      # Browsers
      "microsoft-edge"

      # System Tools
      "iterm2"
      "jdiskreport"
      "microsoft-remote-desktop"
      # "openzfs"
      "winbox"

      # Note: obsidian and raycast are already in profiles/darwin/desktop.nix
    ];
  };

  # User configuration is now imported from the module

  # NFS mounts configuration - mount to /opt/nfs-mounts to avoid conflicts with Finder's /Volumes
  system.activationScripts.preActivation.text = ''
        # Create /opt/nfs-mounts directory if it doesn't exist
        sudo mkdir -p /opt/nfs-mounts
        
        # Create auto_nfs file for automounter
        sudo tee /etc/auto_nfs > /dev/null <<'EOF'
    # NFS mounts from various hosts
    NFS-storage         -fstype=nfs,noowners,nolockd,noresvport,hard,bg,intr,rw,tcp,nfc alienware.home.urandom.io:/export/storage
    NFS-data            -fstype=nfs,noowners,nolockd,noresvport,hard,bg,intr,rw,tcp,nfc alienware.home.urandom.io:/export/data  
    NFS-storage-fast    -fstype=nfs,noowners,nolockd,noresvport,hard,bg,intr,rw,tcp,nfc hal9000.home.urandom.io:/export/storage-fast
    NFS-n100-01         -fstype=nfs,noowners,nolockd,noresvport,hard,bg,intr,rw,tcp,nfc n100-01.home.urandom.io:/export
    NFS-n100-02         -fstype=nfs,noowners,nolockd,noresvport,hard,bg,intr,rw,tcp,nfc n100-02.home.urandom.io:/export
    NFS-n100-03         -fstype=nfs,noowners,nolockd,noresvport,hard,bg,intr,rw,tcp,nfc n100-03.home.urandom.io:/export
    NFS-n100-04         -fstype=nfs,noowners,nolockd,noresvport,hard,bg,intr,rw,tcp,nfc n100-04.home.urandom.io:/export
    EOF
        
        # Update auto_master to include our NFS mounts in /opt/nfs-mounts
        if grep -q "/Volumes.*auto_nfs" /etc/auto_master 2>/dev/null; then
          # Remove the problematic /Volumes entry
          sudo sed -i "" '/\/Volumes.*auto_nfs/d' /etc/auto_master 2>/dev/null || true
        fi
        
        # Remove old /mnt entry if it exists
        if grep -q "/mnt.*auto_nfs" /etc/auto_master 2>/dev/null; then
          sudo sed -i "" '/\/mnt.*auto_nfs/d' /etc/auto_master 2>/dev/null || true
        fi
        
        if ! grep -q "/opt/nfs-mounts.*auto_nfs" /etc/auto_master 2>/dev/null; then
          # Backup existing auto_master
          sudo cp /etc/auto_master "/etc/auto_master.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
          # Add our mount configuration to /opt/nfs-mounts
          echo "/opt/nfs-mounts		/etc/auto_nfs" | sudo tee -a /etc/auto_master > /dev/null
        fi
        
        # Restart automount to pick up changes
        sudo automount -cv 2>/dev/null || true
  '';

  # Age secrets configuration is handled in the user module
}
