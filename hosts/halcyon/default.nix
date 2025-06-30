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
    ../../users/regular/jamesbrink-darwin.nix
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

  # Age secrets configuration is handled in the user module
}
