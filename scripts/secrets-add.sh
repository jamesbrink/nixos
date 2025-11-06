#!/usr/bin/env bash
set -euo pipefail

if [ $# -eq 0 ]; then
  echo "Error: You must specify a secret file to create."
  echo "Usage: secrets-add <secret-name>"
  echo "Example: secrets-add global/rustdesk-password"
  echo "         secrets-add hal9000/api-key"
  echo ""
  echo "Note: Do NOT include the 'secrets/' prefix or '.age' suffix"
  exit 1
fi

SECRET_PATH="$1"

# Remove 'secrets/' prefix if present
SECRET_PATH="${SECRET_PATH#secrets/}"

# Remove '.age' suffix if present
SECRET_PATH="${SECRET_PATH%.age}"

# The actual file path
SECRET_FILE="$SECRET_PATH.age"

# Change to secrets directory
cd secrets

# Check if secret already exists in secrets.nix
if grep -q "\"$SECRET_FILE\"" secrets.nix; then
  echo "Secret entry already exists in secrets.nix"
else
  echo "Adding new secret entry to secrets.nix..."

  # Read the current secrets.nix to get the key list
  # We'll use the same key list as the first secret (global/syncthing/*)

  # Backup secrets.nix
  cp secrets.nix secrets.nix.backup

  # Add the new secret entry before the closing brace
  awk -v new_line="  \"$SECRET_FILE\".publicKeys = allKeys;" '
    /^}$/ { print new_line; print; next }
    { print }
  ' secrets.nix > secrets.nix.new && mv secrets.nix.new secrets.nix

  echo "✓ Added entry for $SECRET_FILE to secrets.nix"
fi

# Create directory if it doesn't exist
mkdir -p "$(dirname "$SECRET_PATH")"

# Use proper agenix syntax
if [ -f ~/.ssh/id_ed25519 ]; then
  IDENTITY_FILE=~/.ssh/id_ed25519
elif [ -f ~/.ssh/id_rsa ]; then
  IDENTITY_FILE=~/.ssh/id_rsa
else
  echo "Error: No SSH identity file found (~/.ssh/id_ed25519 or ~/.ssh/id_rsa)"
  exit 1
fi

echo "Opening editor for new secret..."
RULES=./secrets.nix EDITOR="${EDITOR:-vim}" agenix -e "$SECRET_PATH.age" -i "$IDENTITY_FILE"

cd ..

echo ""
echo "✓ Secret created: $SECRET_FILE"
echo ""
echo "Next steps:"
echo "1. Review the changes: cd secrets && git diff secrets.nix"
echo "2. Commit the changes: git add secrets.nix $SECRET_PATH.age && git commit -m 'Add $SECRET_PATH secret'"
echo "3. Update the parent repo: cd .. && nix flake lock --update-input secrets"
