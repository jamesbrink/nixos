{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ../../modules/nix-caches.nix
    ../../modules/shared-packages/default.nix
    ../../modules/shared-packages/python.nix
    ../../modules/darwin/local-hosts.nix
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

    # macOS defaults
    defaults = {
      NSGlobalDomain = {
        AppleShowAllExtensions = false;
        ApplePressAndHoldEnabled = false;
        KeyRepeat = 2;
        InitialKeyRepeat = 15;
        "com.apple.swipescrolldirection" = true;
        "com.apple.sound.beep.feedback" = 0;
        AppleInterfaceStyleSwitchesAutomatically = false;
        AppleInterfaceStyle = null; # Force light mode
      };

      dock = {
        # NOTE: autohide is managed dynamically by themectl macos-mode
        # Do NOT set it here or it will override the user's mode preference on deploy
        orientation = "bottom";
        show-recents = false;
        tilesize = 48;
        minimize-to-application = true;
      };

    };

    # Keyboard settings
    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToControl = true;
    };
  };

  # Environment
  environment = {
    systemPath = [
      "/opt/homebrew/bin"
      "/opt/homebrew/sbin"
      "/usr/local/bin"
    ];

    pathsToLink = [ "/Applications" ];
  };

  # Services
  # nix-daemon is managed automatically when nix.enable is set

  # Programs
  programs = {
    zsh.enable = true;
  };

  # Security
  security.pam.services.sudo_local.touchIdAuth = true;

  # Homebrew configuration
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
      upgrade = true;
    };

    # We'll manage taps, brews, and casks in separate modules
  };

  # Fonts
  fonts = {
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      nerd-fonts.meslo-lg
    ];
  };

}
