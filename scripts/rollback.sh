#!/usr/bin/env bash
set -euo pipefail

# Check if argument is provided
if [ $# -eq 0 ]; then
  HOST=""
else
  HOST="$1"
fi
if [ -z "$HOST" ]; then
  echo "Error: You must specify a hostname."
  echo "Usage: rollback <hostname>"
  echo "Available hosts:"
  find ./hosts -maxdepth 1 -mindepth 1 -type d | sort | sed 's|./hosts/||'
  exit 1
fi

HOSTNAME=$(hostname)

echo "Rolling back to previous generation on $HOST..."

if [ "$HOSTNAME" = "$HOST" ]; then
  # Local rollback
  SYSTEM=$(uname -s | tr '[:upper:]' '[:lower:]')
  if [ "$SYSTEM" = "darwin" ]; then
    # macOS rollback
    sudo NIXPKGS_ALLOW_UNFREE=1 nix run nix-darwin -- --rollback switch --impure
  else
    # NixOS rollback
    sudo NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild --rollback switch --impure
  fi
else
  # Remote rollback
  # Check if host is darwin or linux by checking flake configuration
  if nix eval --json .#darwinConfigurations."$HOST"._type 2>/dev/null >/dev/null; then
    # Darwin host - use regular user with sudo
    ssh jamesbrink@"$HOST" "sudo NIXPKGS_ALLOW_UNFREE=1 nix run nix-darwin -- --rollback switch --impure"
  else
    # NixOS host - use root
    ssh root@"$HOST" "NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild --rollback switch --impure"
  fi
fi

echo "Rollback on $HOST complete!"
