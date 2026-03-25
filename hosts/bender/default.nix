# Host configuration for bender - Mac Mini M4
# Slim, headless configuration for SSH-focused usage
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  imports = [
    ./hardware.nix
    ../../profiles/darwin-slim # Minimal darwin profile
    ../../modules/ssh-keys.nix
    ../../users/regular/jamesbrink-darwin-slim.nix
  ];

  # Networking
  networking = {
    hostName = "bender";
    computerName = "Bender";
    localHostName = "bender";
  };

  # Time zone
  time.timeZone = "America/Phoenix";

  # OpenClaw dependencies
  # Point mold CLI at hal9000's inference server
  environment.variables.MOLD_HOST = "http://hal9000.home.urandom.io:7680";

  # Core runtime (nodejs, pnpm, bun) comes from shared-packages
  # Channel integrations use API libraries (no native clients needed for Discord/Telegram/Slack/WhatsApp)
  environment.systemPackages = with pkgs; [
    # AI image generation CLI
    inputs.mold.packages.${pkgs.stdenv.hostPlatform.system}.default

    # Signal channel support
    signal-cli

    # Skills dependencies
    ffmpeg # video-frames skill, camsnap, sherpa-onnx-tts
    uv # Python-based skills (nano-banana-pro, local-places, etc.)

    # Productivity tools for OpenClaw skills
    jq # session-logs, trello
    ripgrep # session-logs skill (rg)
    gh # github skill

    # Email
    himalaya # IMAP/SMTP CLI

    # Audio/Voice
    openai-whisper # local speech-to-text

    # Music
    spotify-player

    # Terminal
    alacritty
  ];

  # Homebrew packages for OpenClaw
  homebrew.taps = [
    "steipete/tap"
    "openhue/cli"
    "yakitrak/yakitrak"
  ];

  homebrew.brews = [
    # OpenClaw macOS skills
    "steipete/tap/peekaboo" # macOS UI automation
    "steipete/tap/gifgrep" # GIF search
    "steipete/tap/imsg" # iMessage CLI (requires Full Disk Access)
    "steipete/tap/camsnap" # IP camera snapshots
    "steipete/tap/remindctl" # Apple Reminders

    # Smart Home
    "openhue/cli/openhue-cli" # Philips Hue lights

    # Productivity
    "yakitrak/yakitrak/obsidian-cli" # Obsidian vault
  ];

  homebrew.casks = [
    "bitwarden" # Password manager
    "ghostty" # Terminal emulator
    "tailscale" # VPN/mesh networking
    "telegram" # Messaging
  ];

  # InvokeAI service
  # TODO: disabled — mediapipe fails to build on aarch64-darwin (x86_64 wheel + missing jax/jaxlib)
  # services.invokeai = {
  #   enable = true;
  #   user = "jamesbrink";
  # };

  # AI Toolkit training service
  services.ai-toolkit = {
    enable = true;
    user = "jamesbrink";
    secrets = {
      claudeOauthTokenFile = config.age.secrets."claude-secondary".path;
      hfTokenFile = config.age.secrets."huggingface-token".path;
    };
  };
}
