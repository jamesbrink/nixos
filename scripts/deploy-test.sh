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
  echo "Usage: deploy-test <hostname>"
  echo "Available hosts:"
  find ./hosts -maxdepth 1 -mindepth 1 -type d | sort | sed 's|./hosts/||'
  exit 1
fi

HOSTNAME=$(hostname | cut -d. -f1 | tr '[:upper:]' '[:lower:]')
SYSTEM=$(uname -s | tr '[:upper:]' '[:lower:]')
HOST_LOWER=$(echo "$HOST" | tr '[:upper:]' '[:lower:]')

echo "Testing deployment to $HOST..."

# Check if we're on the target host
if [ "$HOSTNAME" = "$HOST_LOWER" ]; then
  echo "Testing locally on $HOST..."
  if [ "$SYSTEM" = "darwin" ]; then
    # macOS dry-run (darwin doesn't have dry-activate)
    echo "Note: darwin doesn't support dry-activate. Building configuration instead..."
    NIXPKGS_ALLOW_UNFREE=1 nix build .#darwinConfigurations."$HOST".system --impure
  else
    # NixOS dry-run
    sudo NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild dry-activate --flake .#"$HOST" --impure
  fi
else
  echo "Testing remotely on $HOST..."
  # Check if host is darwin or linux by checking flake configuration
  if nix eval --json .#darwinConfigurations."$HOST"._type 2>/dev/null >/dev/null; then
    # Darwin host - use regular user
    # Copy the flake to the remote darwin server and test there
    rsync -avz --exclude '.git' --exclude 'result' . jamesbrink@"$HOST":/private/tmp/nixos-config/
    echo "Note: darwin doesn't support dry-activate. Building configuration instead..."
    ssh jamesbrink@"$HOST" "cd /private/tmp/nixos-config && NIXPKGS_ALLOW_UNFREE=1 nix build .#darwinConfigurations.$HOST.system --impure"
  else
    # NixOS host - use root
    # Copy the flake to the remote NixOS server and test there
    rsync -avz --exclude '.git' --exclude 'result' . root@"$HOST":/tmp/nixos-config/
    ssh root@"$HOST" "cd /tmp/nixos-config && NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild dry-activate --flake .#$HOST --impure"
  fi
fi

echo "Deployment test for $HOST complete!"