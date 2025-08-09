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

  # Networking
  networking = {
    hostName = "halcyon";
    computerName = "Halcyon";
    localHostName = "halcyon";
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

  # Additional packages for this host
  environment.systemPackages = with pkgs; [
    # libpostal with data for address parsing/normalization
    unstablePkgs.libpostalWithData
    # pkg-config and headers for building Python bindings
    pkg-config
    # Additional build tools needed for compiling Python extensions
    clang
    darwin.apple_sdk.frameworks.CoreServices
    darwin.apple_sdk.frameworks.SystemConfiguration
  ];

  # Set environment variables for libpostal
  environment.variables = {
    LIBPOSTAL_DATA_DIR = "${pkgs.unstablePkgs.libpostalWithData}/share/libpostal";
    # Add include and lib paths for building Python bindings
    C_INCLUDE_PATH = "${pkgs.unstablePkgs.libpostalWithData}/include:\${C_INCLUDE_PATH}";
    LIBRARY_PATH = "${pkgs.unstablePkgs.libpostalWithData}/lib:\${LIBRARY_PATH}";
    # Also set PKG_CONFIG_PATH for pkg-config to find libpostal
    PKG_CONFIG_PATH = "${pkgs.unstablePkgs.libpostalWithData}/lib/pkgconfig:\${PKG_CONFIG_PATH}";
    # Set CFLAGS and LDFLAGS to ensure correct library is used
    CFLAGS = "-I${pkgs.unstablePkgs.libpostalWithData}/include";
    LDFLAGS = "-L${pkgs.unstablePkgs.libpostalWithData}/lib";
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
      "mailspring"
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
      "openzfs"
      "winbox"

      # AI Tools (Apple Silicon specific)
      "chatgpt" # ChatGPT desktop app

      # Note: obsidian and raycast are already in profiles/darwin/desktop.nix
    ];
  };

  # User configuration is now imported from the module

  # NFS mounts configuration - mount to /mnt to avoid conflicts with Finder's /Volumes
  # Note: On macOS, automounts appear at /System/Volumes/Data/mnt due to firmlinks
  system.activationScripts.preActivation.text = ''
        # Create /mnt directory if it doesn't exist
        sudo mkdir -p /mnt
        
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
        
        # Update auto_master to include our NFS mounts in /mnt
        if grep -q "/Volumes.*auto_nfs" /etc/auto_master 2>/dev/null; then
          # Remove the problematic /Volumes entry
          sudo sed -i "" '/\/Volumes.*auto_nfs/d' /etc/auto_master 2>/dev/null || true
        fi
        
        if ! grep -q "/mnt.*auto_nfs" /etc/auto_master 2>/dev/null; then
          # Backup existing auto_master
          sudo cp /etc/auto_master "/etc/auto_master.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
          # Add our mount configuration to /mnt
          echo "/mnt		/etc/auto_nfs" | sudo tee -a /etc/auto_master > /dev/null
        fi
        
        # Restart automount to pick up changes
        sudo automount -cv 2>/dev/null || true
  '';

  # Age secrets configuration
  age.identityPaths = [
    "/etc/ssh/ssh_host_ed25519_key"
  ];
}
