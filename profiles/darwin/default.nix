{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ../../modules/shared-packages/default.nix
    ../../modules/darwin/local-hosts.nix
  ];

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
        "com.apple.swipescrolldirection" = true;
        "com.apple.sound.beep.feedback" = 0;
        AppleInterfaceStyleSwitchesAutomatically = false;
        # Force light mode - unset AppleInterfaceStyle means light mode
        AppleInterfaceStyle = null;
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
        TrackpadRightClick = true;
        ActuationStrength = 0; # 0 to enable Silent Clicking, 1 to disable
        FirstClickThreshold = 1; # 0 for light, 1 for medium, 2 for firm
        SecondClickThreshold = 1; # 0 for light, 1 for medium, 2 for firm
        # Note: Natural scrolling is configured via NSGlobalDomain."com.apple.swipescrolldirection" above
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
