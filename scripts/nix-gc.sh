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
  echo "Usage: nix-gc <hostname>"
  echo "Available hosts:"
  find ./hosts -maxdepth 1 -mindepth 1 -type d | sort | sed 's|./hosts/||'
  exit 1
fi

HOSTNAME=$(hostname)

echo "Running garbage collection on $HOST..."

if [ "$HOSTNAME" = "$HOST" ]; then
  # Local garbage collection
  sudo nix-collect-garbage -d
else
  # Remote garbage collection
  # Check if host is darwin or linux by checking flake configuration
  if nix eval --json .#darwinConfigurations.$HOST._type 2>/dev/null >/dev/null; then
    # Darwin host - use regular user with sudo
    ssh jamesbrink@$HOST "sudo nix-collect-garbage -d"
  else
    # NixOS host - use root
    ssh root@$HOST "nix-collect-garbage -d"
  fi
fi

echo "Garbage collection on $HOST complete!"