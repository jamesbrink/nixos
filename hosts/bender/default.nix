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
  # Core runtime (nodejs, pnpm, bun) comes from shared-packages
  # Channel integrations use API libraries (no native clients needed for Discord/Telegram/Slack/WhatsApp)
  environment.systemPackages = with pkgs; [
    # Signal channel support
    signal-cli

    # Skills dependencies
    ffmpeg # video-frames skill, camsnap, sherpa-onnx-tts
    uv # Python-based skills (nano-banana-pro, local-places, etc.)

    # Productivity tools for OpenClaw skills
    jq # session-logs, trello
    ripgrep # session-logs skill (rg)
    gh # github skill

    # Audio/Voice
    # openai-whisper # local speech-to-text (large, enable if needed)

    # macOS automation
    # Add via homebrew: peekaboo, remindctl, imsg, camsnap
  ];

  # Homebrew packages for OpenClaw (steipete/tap has many useful tools)
  homebrew.taps = [
    "steipete/tap"
  ];

  homebrew.brews = [
    # OpenClaw macOS skills
    "steipete/tap/peekaboo" # macOS UI automation
    "steipete/tap/gifgrep" # GIF search
    # "steipete/tap/imsg"      # iMessage CLI (requires Full Disk Access)
    # "steipete/tap/camsnap"   # IP camera snapshots
    # "steipete/tap/remindctl" # Apple Reminders
  ];
}
