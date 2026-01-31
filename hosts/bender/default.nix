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
}
