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
  echo "Usage: deploy-local <hostname>"
  echo "Available hosts:"
  find ./hosts -maxdepth 1 -mindepth 1 -type d | sort | sed 's|./hosts/||'
  exit 1
fi

HOSTNAME=$(hostname | cut -d. -f1 | tr '[:upper:]' '[:lower:]')
HOST_LOWER=$(echo "$HOST" | tr '[:upper:]' '[:lower:]')

# Check if we're trying to deploy to ourselves
if [ "$HOSTNAME" = "$HOST_LOWER" ]; then
  echo "Error: deploy-local is for remote hosts only. Use 'deploy' for local deployment."
  exit 1
fi

# Check if host is Darwin or NixOS
if nix eval --json .#darwinConfigurations.$HOST._type 2>/dev/null >/dev/null; then
  # Darwin deployment
  echo "Building darwin configuration for $HOST locally..."
  NIXPKGS_ALLOW_UNFREE=1 nix build --impure .#darwinConfigurations.$HOST.system
  if [ $? -ne 0 ]; then
    echo "Build failed! Aborting deployment."
    exit 1
  fi
  
  echo "Build complete! Copying closure to $HOST..."
  nix-copy-closure --to jamesbrink@$HOST ./result
  
  if [ $? -ne 0 ]; then
    echo "Failed to copy closure to $HOST! Aborting deployment."
    exit 1
  fi
  
  echo "Switching to new configuration on $HOST..."
  STORE_PATH=$(readlink -f ./result)
  ssh jamesbrink@$HOST "sudo $STORE_PATH/sw/bin/darwin-rebuild switch --flake .#$HOST"
  
  if [ $? -eq 0 ]; then
    echo "Deployment to $HOST complete!"
  else
    echo "Failed to switch configuration on $HOST!"
    exit 1
  fi
else
  # NixOS deployment
  # Check if we already have a build result
  if [ -L ./result ] && [ -e ./result ]; then
    # Verify this result is for the correct host (macOS-compatible grep)
    RESULT_HOST=$(readlink ./result | sed -n 's/.*nixos-system-\([^-]*\).*/\1/p' || echo "unknown")
    if [ "$RESULT_HOST" = "$HOST" ]; then
      echo "Found existing build result for $HOST, using it..."
    else
      echo "Existing build result is for '$RESULT_HOST', not '$HOST'. Building fresh..."
      NIXPKGS_ALLOW_UNFREE=1 nix build --impure .#nixosConfigurations.$HOST.config.system.build.toplevel
      if [ $? -ne 0 ]; then
        echo "Build failed! Aborting deployment."
        exit 1
      fi
    fi
  else
    echo "No existing build result found. Building configuration for $HOST locally..."
    NIXPKGS_ALLOW_UNFREE=1 nix build --impure .#nixosConfigurations.$HOST.config.system.build.toplevel
    if [ $? -ne 0 ]; then
      echo "Build failed! Aborting deployment."
      exit 1
    fi
  fi

  echo "Build complete! Copying closure to $HOST..."
  nix-copy-closure --to root@$HOST ./result

  if [ $? -ne 0 ]; then
    echo "Failed to copy closure to $HOST! Aborting deployment."
    exit 1
  fi

  echo "Switching to new configuration on $HOST..."
  STORE_PATH=$(readlink -f ./result)
  ssh root@$HOST "nix-env -p /nix/var/nix/profiles/system --set $STORE_PATH && /nix/var/nix/profiles/system/bin/switch-to-configuration switch"

  if [ $? -eq 0 ]; then
    echo "Deployment to $HOST complete!"
  else
    echo "Failed to switch configuration on $HOST!"
    exit 1
  fi
fi