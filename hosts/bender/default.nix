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
  # Gateway + CLI require Node 22+, pnpm for builds
  # Channel integrations use API libraries (no native clients needed for Discord/Telegram/Slack/WhatsApp)
  # Signal channel requires signal-cli binary
  environment.systemPackages = with pkgs; [
    # Core runtime
    nodejs_22
    nodePackages.pnpm

    # Signal channel support
    signal-cli

    # Skills dependencies
    ffmpeg # video-frames skill
    uv # Python-based skills (nano-banana-pro, local-places, etc.)
  ];
}
