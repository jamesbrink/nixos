#!/usr/bin/env bash
set -euo pipefail

if [ $# -eq 0 ]; then
  echo "Error: You must specify a secret file to print."
  echo "Usage: secrets-print <secret-name>"
  echo "Example: secrets-print global/claude-desktop-config"
  echo "         secrets-print hal9000/syncthing-password"
  echo ""
  echo "Available secrets:"
  find secrets -name "*.age" -type f | sort | sed 's|^secrets/||; s|\.age$||'
  exit 1
fi

SECRET_PATH="$1"

# Remove 'secrets/' prefix if present 
SECRET_PATH="${SECRET_PATH#secrets/}"

# Remove '.age' suffix if present
SECRET_PATH="${SECRET_PATH%.age}"

# The actual file path
SECRET_FILE="secrets/$SECRET_PATH.age"

if [ ! -f "$SECRET_FILE" ]; then
  echo "Error: Secret file not found: $SECRET_PATH"
  echo ""
  echo "Available secrets:"
  find secrets -name "*.age" -type f | sort | sed 's|^secrets/||; s|\.age$||'
  exit 1
fi

# Check for identity file
IDENTITY_FILE=""
if [ -f ~/.ssh/id_ed25519 ]; then
  IDENTITY_FILE="$HOME/.ssh/id_ed25519"
elif [ -f ~/.ssh/id_rsa ]; then
  IDENTITY_FILE="$HOME/.ssh/id_rsa"
else
  echo "Error: No SSH identity file found (~/.ssh/id_ed25519 or ~/.ssh/id_rsa)"
  exit 1
fi

echo "Decrypting $SECRET_FILE..."
echo "────────────────────────────────────────────────────────"

# Decrypt and capture output
# We need to cd into secrets directory because agenix expects paths relative to rules file
DECRYPTED_CONTENT=$(cd secrets && RULES=./secrets.nix agenix -d "$SECRET_PATH.age" -i "$IDENTITY_FILE" 2>&1)
DECRYPT_STATUS=$?

if [ $DECRYPT_STATUS -eq 0 ]; then
  echo "$DECRYPTED_CONTENT"
  echo "────────────────────────────────────────────────────────"
  echo "Secret decrypted successfully!"
else
  echo "────────────────────────────────────────────────────────"
  echo "Error: Failed to decrypt secret. Make sure you have access to this secret."
  echo "This usually means your SSH key is not listed as a recipient for this secret."
  echo ""
  echo "Error details: $DECRYPTED_CONTENT"
  exit 1
fi