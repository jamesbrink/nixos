{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ./default.nix
    ../../modules/claude-desktop.nix
    ../../modules/darwin/file-sharing.nix
  ];

  documentation = {
    enable = false;
    man.enable = false;
    info.enable = false;
    doc.enable = false;
  };

  # Desktop-specific packages
  environment.systemPackages = with pkgs; [
    # Terminal and CLI tools
    ncurses # Provides terminfo database
    iterm2

    # Development tools
    vscode

    # System utilities
    rectangle # Window management
    stats # System monitor

    # Productivity
    raycast
  ];

  # Homebrew configuration
  homebrew = {
    # Command-line tools
    brews = [
      "node" # Node.js (provides npm and npx)
      "uv" # Python package manager and runner (provides uvx)
      "heroku" # Heroku CLI
      "geckodriver" # WebDriver for Firefox
    ];

    # GUI applications
    casks = [
      # Terminal applications
      "alacritty"

      # Browsers
      "zen"
      "firefox"
      "google-chrome"

      # Communication
      "discord"
      "slack"
      "telegram"
      "zoom"

      # Security
      "bitwarden"

      # Development
      "cursor"
      "datagrip"
      "github"
      "orbstack"
      "visual-studio-code"

      # Media
      "vlc"

      # Utilities
      "aerial"
      "bartender"
      "hammerspoon"
      "little-snitch"
      "balenaetcher"

      # Development Tools
      "meld"
      "wireshark-app"

      # AI Tools
      "claude" # Claude Desktop app
      "diffusionbee"
      "ollama-app"

      # Networking
      "tailscale-app"

      # Productivity
      "obsidian"
    ];

    # Mac App Store apps
    masApps = {
      "Amphetamine" = 937984704;
      "Xcode" = 497799835;
    };
  };

  # Enable file sharing on all Darwin desktop systems
  services.file-sharing = {
    enable = true;
    sharedFolders = [
      "/Users/Shared"
      "/Users/jamesbrink/Public"
    ];
  };

  # Set Aerial as the default screensaver on all Darwin desktop systems
  system.defaults.CustomUserPreferences = {
    "com.apple.screensaver" = {
      moduleDict = {
        moduleName = "Aerial";
        path = "/Library/Screen Savers/Aerial.saver";
        type = 0;
      };
    };
  };

  # Activation script to ensure Aerial is set as the screensaver
  system.activationScripts.userActivation.text = ''
    echo "Setting Aerial as the default screensaver..."

    # Set Aerial as the default screensaver for the user
    # Since activation runs as root, we need to use sudo -u
    sudo -u jamesbrink /usr/bin/defaults -currentHost write com.apple.screensaver modulePath -string "/Library/Screen Savers/Aerial.saver"
    sudo -u jamesbrink /usr/bin/defaults -currentHost write com.apple.screensaver moduleName -string "Aerial"
    sudo -u jamesbrink /usr/bin/defaults -currentHost write com.apple.screensaver moduleDict -dict moduleName Aerial path "/Library/Screen Savers/Aerial.saver" type 0

    echo "Aerial screensaver configuration complete."
  '';
}
