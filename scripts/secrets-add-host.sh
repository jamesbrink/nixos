#!/usr/bin/env bash
set -euo pipefail

if [ $# -eq 0 ]; then
  echo "Error: You must specify a hostname."
  echo "Usage: secrets-add-host <hostname>"
  exit 1
fi

HOST="$1"
echo "Getting SSH host key for $HOST..."

# Try to get the host key
KEY=$(ssh-keyscan -t ed25519 "$HOST" 2>/dev/null | grep -v "^#" | head -1)

if [ -z "$KEY" ]; then
  echo "Error: Could not retrieve SSH key for $HOST"
  exit 1
fi

echo "Found key: $KEY"
echo ""
echo "Add this to secrets/secrets.nix in the host keys section:"
echo "  $HOST = \"$(echo "$KEY" | cut -d' ' -f2-3)\";"
echo ""
echo "Then run 'secrets-rekey' to re-encrypt all secrets"