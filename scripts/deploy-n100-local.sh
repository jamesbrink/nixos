#!/usr/bin/env bash
set -euo pipefail

if [ $# -eq 0 ]; then
  echo "Error: You must specify an N100 hostname."
  echo "Usage: deploy-n100-local <n100-hostname>"
  echo "Available N100 hosts: n100-01, n100-02, n100-03, n100-04"
  echo ""
  echo "This command performs initial deployment with local building including:"
  echo "  - Building the configuration locally (not on the N100)"
  echo "  - Creating ZFS volumes with disko"
  echo "  - Installing NixOS configuration"
  echo "  - Setting up encrypted secrets"
  echo ""
  echo "Prerequisites:"
  echo "  - N100 node must be booted into netboot installer"
  echo "  - SSH access to root@nixos-installer must be available"
  echo ""
  echo "Environment variables:"
  echo "  NIXOS_ANYWHERE_NOCONFIRM=1  Skip confirmation prompt"
  echo "  TARGET_HOST_OVERRIDE=<ip>   Override target host IP/hostname"
  exit 1
fi

HOST="$1"

# Validate it's an N100 host
if ! echo "$HOST" | grep -q "^n100-0[1-4]$"; then
  echo "Error: Invalid N100 hostname. Must be n100-01, n100-02, n100-03, or n100-04"
  exit 1
fi

# Try to determine the target host
TARGET_HOST=""

# First try the hostname directly (in case it has the right IP)
echo "Checking if $HOST is running the installer..."
if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@"$HOST" "test -f /etc/is-installer" 2>/dev/null; then
  TARGET_HOST="$HOST"
  echo "Found installer at $HOST"
# Then try nixos-installer
elif ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@nixos-installer "test -f /etc/is-installer" 2>/dev/null; then
  TARGET_HOST="nixos-installer"
  echo "Found installer at nixos-installer"
else
  echo "Error: Cannot reach installer. Make sure:"
  echo "  1. N100 node is booted into netboot installer"
  echo "  2. You can SSH to either root@$HOST or root@nixos-installer"
  echo ""
  echo "If the installer is at a different IP, you can specify it:"
  echo "  TARGET_HOST_OVERRIDE=<ip-address> deploy-n100-local $HOST"
  exit 1
fi

# Allow override via environment variable
if [ -n "${TARGET_HOST_OVERRIDE:-}" ]; then
  TARGET_HOST="$TARGET_HOST_OVERRIDE"
  echo "Using override target: $TARGET_HOST"
fi

echo "Starting initial deployment to $HOST with local build..."
echo "This will:"
echo "  - Build the configuration locally"
echo "  - Create ZFS volumes according to disko configuration"
echo "  - Install NixOS configuration"
echo "  - Configure encrypted secrets"
echo ""

# Check if we're in non-interactive mode or auto-confirm
if [ "${NIXOS_ANYWHERE_NOCONFIRM:-}" = "1" ] || [ "${CI:-}" = "true" ]; then
  echo "Auto-confirming deployment (NIXOS_ANYWHERE_NOCONFIRM=1 or CI=true)"
else
  read -r -p "Continue? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
  fi
fi

# Run nixos-anywhere with local build
echo "Running nixos-anywhere with local build..."
echo "Target: root@$TARGET_HOST"
echo "Configuration: $HOST"
echo ""

if NIXPKGS_ALLOW_UNFREE=1 nixos-anywhere \
  --impure \
  --flake ".#$HOST" \
  --target-host "root@$TARGET_HOST" \
  --option experimental-features "nix-command flakes" \
  --print-build-logs; then
  echo ""
  echo "Initial deployment to $HOST complete!"
  echo "The system should reboot into the installed NixOS."
  echo ""
  echo "Next steps:"
  echo "  1. Wait for the system to reboot"
  echo "  2. SSH to root@$HOST"
  echo "  3. Run further deployments with: deploy-local $HOST"
else
  echo ""
  echo "Deployment failed! Check the error messages above."
  exit 1
fi
