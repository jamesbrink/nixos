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
  echo "Usage: show-generations <hostname>"
  echo "Available hosts:"
  find ./hosts -maxdepth 1 -mindepth 1 -type d | sort | sed 's|./hosts/||'
  exit 1
fi

HOSTNAME=$(hostname)

if [ "$HOSTNAME" = "$HOST" ]; then
  # Local generations
  echo "System generations on $HOST:"
  sudo nix-env -p /nix/var/nix/profiles/system --list-generations
else
  # Remote generations
  # Check if host is darwin or linux by checking flake configuration
  if nix eval --json .#darwinConfigurations."$HOST"._type 2>/dev/null >/dev/null; then
    # Darwin host - use regular user with sudo
    echo "Darwin generations on $HOST:"
    ssh jamesbrink@"$HOST" "sudo nix-env -p /nix/var/nix/profiles/system --list-generations"
  else
    # NixOS host - use root
    echo "NixOS generations on $HOST:"
    ssh root@"$HOST" "nix-env -p /nix/var/nix/profiles/system --list-generations"
  fi
fi
