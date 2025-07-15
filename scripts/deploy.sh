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
  echo "Usage: deploy <hostname>"
  echo "Available hosts:"
  find ./hosts -maxdepth 1 -mindepth 1 -type d | sort | sed 's|./hosts/||'
  exit 1
fi

HOSTNAME=$(hostname | cut -d. -f1 | tr '[:upper:]' '[:lower:]')
SYSTEM=$(uname -s | tr '[:upper:]' '[:lower:]')
HOST_LOWER=$(echo "$HOST" | tr '[:upper:]' '[:lower:]')

echo "Deploying configuration to $HOST..."

# Always use rsync to ensure submodules are included
if [ "$HOSTNAME" = "$HOST_LOWER" ]; then
  echo "Deploying locally to $HOST..."
  # Even for local deployments, use rsync to ensure git submodules are included
  if [ "$SYSTEM" = "darwin" ]; then
    rm -rf /private/tmp/nixos-config
    mkdir -p /private/tmp/nixos-config
    rsync -avz --exclude '.git' --exclude '.gitignore' --exclude '.gitmodules' --exclude 'result' . /private/tmp/nixos-config/
    # macOS deployment - darwin-rebuild requires sudo
    sudo NIXPKGS_ALLOW_UNFREE=1 nix run nix-darwin -- switch --flake /private/tmp/nixos-config#"$HOST" --impure --no-update-lock-file
  else
    rm -rf /tmp/nixos-config
    mkdir -p /tmp/nixos-config
    rsync -avz --exclude '.git' --exclude '.gitignore' --exclude '.gitmodules' --exclude 'result' . /tmp/nixos-config/
    # NixOS deployment
    sudo NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild switch --fast --flake /tmp/nixos-config#"$HOST" --verbose --impure
  fi
else
  echo "Deploying remotely to $HOST..."
  # Check if host is darwin or linux by checking flake configuration
  if nix eval --json .#darwinConfigurations."$HOST"._type 2>/dev/null >/dev/null; then
    # Darwin host - use regular user
    # Copy the flake to the remote darwin server and build there
    rsync -avz --exclude '.git' --exclude '.gitignore' --exclude '.gitmodules' --exclude 'result' . jamesbrink@"$HOST":/private/tmp/nixos-config/
    ssh jamesbrink@"$HOST" "sudo NIXPKGS_ALLOW_UNFREE=1 nix run nix-darwin -- switch --flake /private/tmp/nixos-config#$HOST --impure --no-update-lock-file"
  else
    # NixOS host - use root
    # Copy the flake to the remote NixOS server and build there
    rsync -avz --exclude '.git' --exclude '.gitignore' --exclude '.gitmodules' --exclude 'result' . root@"$HOST":/tmp/nixos-config/
    ssh root@"$HOST" "NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild switch --fast --flake /tmp/nixos-config#$HOST --verbose --impure"
  fi
fi

echo "Deployment to $HOST complete!"