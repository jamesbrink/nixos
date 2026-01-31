# Minimal Darwin profile for headless/SSH-focused Mac systems
# Use this for machines with limited storage or primarily accessed via SSH
{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ../../modules/nix-caches.nix
    ../../modules/shared-packages # Full shared packages (includes bun, nodejs, pnpm, etc.)
    ../../modules/shared-packages/python.nix
    ../../modules/shared-packages/devops-darwin.nix
  ];

  # Nix configuration
  nix = {
    enable = false; # Determinate Nix compatibility

    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      warn-dirty = false;
      auto-optimise-store = true;
      trusted-users = [
        "root"
        "jamesbrink"
        "@admin"
      ];
    };
  };

  # System configuration
  system = {
    stateVersion = 5;
    primaryUser = "jamesbrink";

    # Minimal macOS defaults
    defaults = {
      NSGlobalDomain = {
        ApplePressAndHoldEnabled = false;
        KeyRepeat = 2;
        InitialKeyRepeat = 15;
      };
    };

    # Keyboard settings
    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToControl = true;
    };
  };

  # Environment - minimal paths
  environment = {
    systemPath = [
      "/opt/homebrew/bin"
      "/opt/homebrew/sbin"
      "/usr/local/bin"
    ];

    pathsToLink = [ "/Applications" ];

    # Core system packages (devops + python modules add most tools)
    systemPackages = with pkgs; [
      # Essentials not in other modules
      curl
      gnupg
      htop
      neovim
      tmux
      tree
      wget
      zsh
    ];
  };

  # Programs
  programs = {
    zsh.enable = true;
  };

  # Security - enable Touch ID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  # Homebrew - minimal configuration (no desktop apps)
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = false; # Don't auto-update to save bandwidth
      cleanup = "zap";
      upgrade = false; # Don't auto-upgrade
    };

    # CLI brews only
    brews = [
      "helm" # Not available in nixpkgs for darwin
    ];

    # No casks - headless system
    casks = [ ];
  };

  # Fonts - just one essential nerd font
  fonts = {
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
    ];
  };
}
