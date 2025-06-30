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
        AppleShowAllExtensions = true;
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
        AppleShowAllExtensions = true;
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

  # Activation scripts
  system.activationScripts.terminfo.text = ''
    # Install alacritty terminfo for all users
    echo "Setting up alacritty terminfo..."
    # Note: terminfo files are stored by first character (a for alacritty)
    # Try multiple possible locations for the terminfo file
    TERMINFO_SRC=""
    for path in "${pkgs.alacritty}/share/terminfo/a/alacritty" \
                "${pkgs.alacritty.terminfo}/share/terminfo/a/alacritty" \
                "${pkgs.ncurses}/share/terminfo/a/alacritty"; do
      if [ -f "$path" ]; then
        TERMINFO_SRC="$path"
        break
      fi
    done

    if [ -n "$TERMINFO_SRC" ]; then
      
      # System-wide installation
      mkdir -p /usr/share/terminfo/a
      cp -f "$TERMINFO_SRC" /usr/share/terminfo/a/alacritty || true
      
      # Also install for specific users
      for user_home in /Users/*; do
        if [ -d "$user_home" ]; then
          user_name=$(basename "$user_home")
          if id "$user_name" >/dev/null 2>&1; then
            sudo -u "$user_name" mkdir -p "$user_home/.terminfo/a" 2>/dev/null || true
            sudo -u "$user_name" cp -f "$TERMINFO_SRC" "$user_home/.terminfo/a/alacritty" 2>/dev/null || true
          fi
        fi
      done
      echo "Alacritty terminfo installed"
    fi
  '';
}
