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

  # Desktop-specific packages
  environment.systemPackages = with pkgs; [
    # Terminal and CLI tools
    alacritty
    ncurses # Provides terminfo database
    iterm2

    # Development tools
    vscode

    # System utilities
    rectangle # Window management
    stats # System monitor
    istat-menus

    # Productivity
    raycast
    # obsidian # GUI app - use homebrew cask instead
    # notion # Not available on darwin - use homebrew cask instead
  ];

  # Homebrew configuration
  homebrew = {
    # Command-line tools
    brews = [
      "node" # Node.js (provides npm and npx)
      "uv" # Python package manager and runner (provides uvx)
      "heroku" # Heroku CLI
    ];

    # GUI applications
    casks = [
      # Browsers
      "zen"
      "firefox"
      "google-chrome"

      # Communication
      "discord"
      "slack"
      "zoom"

      # Security
      "bitwarden"

      # Development
      "datagrip"
      "orbstack"
      "visual-studio-code"

      # Media
      "spotify"
      "vlc"

      # Utilities
      "bartender"
      "little-snitch"

      # AI Tools
      "claude" # Claude Code
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
      "Spark" = 1176895641;
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
}
