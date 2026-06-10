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

# Stage the repo with submodule contents, mirroring deploy.sh. Building
# straight from the git tree ('.#...') omits submodule contents (secrets/,
# mikrotik-terraform/), producing closures whose agenix activation fails with
# "encrypted file ... does not exist".
STAGING=/private/tmp/nixos-config
echo "Staging repo (with submodules) to $STAGING..."
mkdir -p "$STAGING"
rsync -az --delete --exclude '.git' --exclude '.gitignore' --exclude '.gitmodules' --exclude 'result' . "$STAGING/"

# Check if host is Darwin or NixOS
if nix eval --json .#darwinConfigurations."$HOST"._type 2>/dev/null >/dev/null; then
  # Darwin deployment
  echo "Building darwin configuration for $HOST locally..."
  if ! NIXPKGS_ALLOW_UNFREE=1 nix build --impure "$STAGING#darwinConfigurations.${HOST}.system" -o ./result; then
    echo "Build failed! Aborting deployment."
    exit 1
  fi
  
  echo "Build complete! Copying closure to $HOST..."
  if ! nix-copy-closure --to jamesbrink@"$HOST" ./result; then
    echo "Failed to copy closure to $HOST! Aborting deployment."
    exit 1
  fi
  
  echo "Switching to new configuration on $HOST..."
  STORE_PATH=$(readlink -f ./result)
  # Activate the closure we just built and copied. Do NOT use
  # 'darwin-rebuild switch --flake .#$HOST' here: it re-evaluates the flake
  # from the remote $HOME, which has no repo checkout, and fails with
  # "could not find a flake.nix file".
  if ssh jamesbrink@"$HOST" "sudo nix-env -p /nix/var/nix/profiles/system --set $STORE_PATH && sudo $STORE_PATH/activate"; then
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
      if ! NIXPKGS_ALLOW_UNFREE=1 nix build --impure "$STAGING#nixosConfigurations.${HOST}.config.system.build.toplevel" -o ./result; then
        echo "Build failed! Aborting deployment."
        exit 1
      fi
    fi
  else
    echo "No existing build result found. Building configuration for $HOST locally..."
    if ! NIXPKGS_ALLOW_UNFREE=1 nix build --impure "$STAGING#nixosConfigurations.${HOST}.config.system.build.toplevel" -o ./result; then
      echo "Build failed! Aborting deployment."
      exit 1
    fi
  fi

  echo "Build complete! Copying closure to $HOST..."
  if ! nix-copy-closure --to root@"$HOST" ./result; then
    echo "Failed to copy closure to $HOST! Aborting deployment."
    exit 1
  fi

  echo "Switching to new configuration on $HOST..."
  STORE_PATH=$(readlink -f ./result)
  if ssh root@"$HOST" "nix-env -p /nix/var/nix/profiles/system --set $STORE_PATH && /nix/var/nix/profiles/system/bin/switch-to-configuration switch"; then
    echo "Deployment to $HOST complete!"
  else
    echo "Failed to switch configuration on $HOST!"
    exit 1
  fi
fi
