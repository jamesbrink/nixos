#!/usr/bin/env bash
set -euo pipefail

if [ $# -eq 0 ]; then
  echo "Error: You must specify a secret file to edit."
  echo "Usage: secrets-edit <secret-name>"
  echo "Example: secrets-edit global/claude-desktop-config"
  echo "         secrets-edit hal9000/syncthing-password"
  echo ""
  echo "Note: Do NOT include the 'secrets/' prefix"
  exit 1
fi

SECRET_PATH="$1"

# Remove 'secrets/' prefix if present 
SECRET_PATH="${SECRET_PATH#secrets/}"

# Remove '.age' suffix if present
SECRET_PATH="${SECRET_PATH%.age}"

# The actual file path
SECRET_FILE="$SECRET_PATH.age"

# Change to secrets directory for proper path resolution
cd secrets

if [ ! -f "$SECRET_FILE" ]; then
  echo "Creating new secret: $SECRET_FILE"
  mkdir -p "$(dirname "$SECRET_FILE")"
fi

# Use proper agenix syntax - use ed25519 by default
if [ -f ~/.ssh/id_ed25519 ]; then
  IDENTITY_FILE=~/.ssh/id_ed25519
elif [ -f ~/.ssh/id_rsa ]; then
  IDENTITY_FILE=~/.ssh/id_rsa
else
  echo "Error: No SSH identity file found (~/.ssh/id_ed25519 or ~/.ssh/id_rsa)"
  exit 1
fi

RULES=./secrets.nix EDITOR="${EDITOR:-vim}" agenix -e "$SECRET_FILE" -i "$IDENTITY_FILE"
cd ..