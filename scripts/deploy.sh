#!/usr/bin/env bash
set -euo pipefail

# Parse arguments
HOST=""
BUILD_HOST=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --build-host)
      BUILD_HOST="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: deploy <hostname> [--build-host <build-hostname>]"
      echo ""
      echo "Arguments:"
      echo "  <hostname>                Target host to deploy to"
      echo "  --build-host <hostname>   Optional: Host to build on (for low-resource targets)"
      echo ""
      echo "Available hosts:"
      find ./hosts -maxdepth 1 -mindepth 1 -type d | sort | sed 's|./hosts/||'
      exit 0
      ;;
    *)
      if [ -z "$HOST" ]; then
        HOST="$1"
      else
        echo "Error: Unknown argument '$1'"
        echo "Usage: deploy <hostname> [--build-host <build-hostname>]"
        exit 1
      fi
      shift
      ;;
  esac
done

if [ -z "$HOST" ]; then
  echo "Error: You must specify a hostname."
  echo "Usage: deploy <hostname> [--build-host <build-hostname>]"
  echo "Available hosts:"
  find ./hosts -maxdepth 1 -mindepth 1 -type d | sort | sed 's|./hosts/||'
  exit 1
fi

HOSTNAME=$(hostname | cut -d. -f1 | tr '[:upper:]' '[:lower:]')
SYSTEM=$(uname -s | tr '[:upper:]' '[:lower:]')
HOST_LOWER=$(echo "$HOST" | tr '[:upper:]' '[:lower:]')

# If build host is specified, use remote build strategy
if [ -n "$BUILD_HOST" ]; then
  echo "Building on $BUILD_HOST and deploying to $HOST..."

  # Copy flake to build host
  echo "Copying configuration to build host $BUILD_HOST..."
  rsync -avz --exclude '.git' --exclude '.gitignore' --exclude '.gitmodules' --exclude 'result' . root@"$BUILD_HOST":/tmp/nixos-config/

  # Build on the build host and copy closure to target
  echo "Building configuration on $BUILD_HOST..."
  ssh root@"$BUILD_HOST" "cd /tmp/nixos-config && NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild build --flake .#$HOST --impure"

  # Get the system closure path
  SYSTEM_PATH=$(ssh root@"$BUILD_HOST" "readlink -f /tmp/nixos-config/result")

  # Copy closure to target host
  echo "Copying built system to $HOST..."
  ssh root@"$BUILD_HOST" "nix copy --to ssh://root@$HOST $SYSTEM_PATH"

  # Activate on target host
  echo "Activating configuration on $HOST..."
  ssh root@"$HOST" "nix-env --profile /nix/var/nix/profiles/system --set $SYSTEM_PATH && $SYSTEM_PATH/bin/switch-to-configuration switch"

  echo "Deployment to $HOST complete!"
  exit 0
fi

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

    # Special handling for hal9000 PixInsight package
    if [ "$HOST_LOWER" = "hal9000" ]; then
      echo "Checking for PixInsight tarball cache..."
      PIXINSIGHT_CACHE="/var/cache/pixinsight/PI-linux-x64-1.9.3-20250402-c.tar.xz"
      if [ -f "$PIXINSIGHT_CACHE" ]; then
        echo "Found PixInsight tarball in cache, adding to nix store with GC root..."
        STORE_PATH=$(sudo nix-store --add-fixed sha256 "$PIXINSIGHT_CACHE" 2>&1 | grep -v "warning:" || true)
        if [ -n "$STORE_PATH" ]; then
          # Create GC root to prevent garbage collection
          sudo mkdir -p /nix/var/nix/gcroots/pixinsight
          sudo ln -sf "$STORE_PATH" /nix/var/nix/gcroots/pixinsight/tarball || true
          echo "Created GC root to protect PixInsight from garbage collection"
        fi
      else
        echo "Warning: PixInsight tarball not found at $PIXINSIGHT_CACHE"
        echo "PixInsight package may fail to build. See docs/pixinsight-cache.md"
      fi
    fi

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

    # Special handling for hal9000 PixInsight package
    if [ "$HOST_LOWER" = "hal9000" ]; then
      echo "Checking for PixInsight tarball cache on hal9000..."
      ssh root@"$HOST" 'bash -s' << 'ENDSSH'
        PIXINSIGHT_CACHE="/var/cache/pixinsight/PI-linux-x64-1.9.3-20250402-c.tar.xz"
        if [ -f "$PIXINSIGHT_CACHE" ]; then
          echo "Found PixInsight tarball in cache, adding to nix store with GC root..."
          STORE_PATH=$(nix-store --add-fixed sha256 "$PIXINSIGHT_CACHE" 2>&1 | grep -v "warning:" || true)
          if [ -n "$STORE_PATH" ]; then
            # Create GC root to prevent garbage collection
            mkdir -p /nix/var/nix/gcroots/pixinsight
            ln -sf "$STORE_PATH" /nix/var/nix/gcroots/pixinsight/tarball || true
            echo "Created GC root to protect PixInsight from garbage collection"
          fi
        else
          echo "Warning: PixInsight tarball not found at $PIXINSIGHT_CACHE"
          echo "PixInsight package may fail to build. See docs/pixinsight-cache.md"
        fi
ENDSSH
    fi

    ssh root@"$HOST" "NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild switch --fast --flake /tmp/nixos-config#$HOST --verbose --impure"
  fi
fi

echo "Deployment to $HOST complete!"
