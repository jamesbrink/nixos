{
  config,
  pkgs,
  lib,
  ...
}:

{
  # Nix configuration
  nix = {
    # Disable nix-darwin from managing nix (for Determinate Nix compatibility)
    enable = false;

    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      warn-dirty = false;
      auto-optimise-store = true;
      trusted-users = [ "@admin" ];
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
        "com.apple.swipescrolldirection" = false;
        "com.apple.sound.beep.feedback" = 0;
        AppleInterfaceStyleSwitchesAutomatically = true;
      };

      dock = {
        autohide = false;
        orientation = "bottom";
        show-recents = false;
        tilesize = 48;
        minimize-to-application = true;
      };

      finder = {
        _FXShowPosixPathInTitle = true;
        AppleShowAllExtensions = false;
        FXEnableExtensionChangeWarning = false;
        QuitMenuItem = true;
        ShowPathbar = true;
        ShowStatusBar = true;
      };

      trackpad = {
        Clicking = true;
        TrackpadThreeFingerDrag = true;
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
