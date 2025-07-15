#!/usr/bin/env bash
set -euo pipefail

echo "Verifying all secrets..."
FAILED=0

# Use id_ed25519 by default, fall back to id_rsa
if [ -f ~/.ssh/id_ed25519 ]; then
  IDENTITY_FILE=~/.ssh/id_ed25519
elif [ -f ~/.ssh/id_rsa ]; then
  IDENTITY_FILE=~/.ssh/id_rsa
else
  echo "Error: No SSH identity file found (~/.ssh/id_ed25519 or ~/.ssh/id_rsa)"
  exit 1
fi

for secret in $(find secrets -name "*.age" -type f | sort); do
  echo -n "Checking $secret... "
  # Extract the path relative to secrets/
  SECRET_PATH="${secret#secrets/}"
  SECRET_PATH="${SECRET_PATH%.age}"
  
  # We need to cd into secrets directory because agenix expects paths relative to rules file
  if (cd secrets && RULES=./secrets.nix agenix -d "$SECRET_PATH.age" -i "$IDENTITY_FILE" > /dev/null 2>&1); then
    echo "✓"
  else
    echo "✗ FAILED"
    FAILED=$((FAILED + 1))
  fi
done

if [ $FAILED -eq 0 ]; then
  echo "All secrets verified successfully!"
else
  echo "WARNING: $FAILED secrets failed verification"
  exit 1
fi