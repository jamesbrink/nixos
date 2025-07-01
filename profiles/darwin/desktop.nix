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
    obsidian
    # notion # Not available on darwin - use homebrew cask instead
  ];

  # Homebrew configuration
  homebrew = {
    # Command-line tools
    brews = [
      "node" # Node.js (provides npm and npx)
      "uv" # Python package manager and runner (provides uvx)
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

      # Development
      "datagrip"
      "orbstack"
      "visual-studio-code"

      # Media
      "spotify"
      "vlc"

      # Utilities
      "bartender"
      "cleanmymac"
      "little-snitch"

      # AI Tools
      "claude" # Claude Desktop
      "diffusionbee"
      "ollama-app"
    ];

    # Mac App Store apps
    masApps = {
      "Amphetamine" = 937984704;
      "Spark" = 1176895641;
      "Tailscale" = 1475387142;
      "Xcode" = 497799835;
    };
  };
}
