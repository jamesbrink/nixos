#!/usr/bin/env bash
set -euo pipefail

echo "Re-encrypting all secrets..."
cd secrets

# Use id_ed25519 by default, fall back to id_rsa
if [ -f ~/.ssh/id_ed25519 ]; then
  IDENTITY_FILE=~/.ssh/id_ed25519
elif [ -f ~/.ssh/id_rsa ]; then
  IDENTITY_FILE=~/.ssh/id_rsa
else
  echo "Error: No SSH identity file found (~/.ssh/id_ed25519 or ~/.ssh/id_rsa)"
  exit 1
fi

# Use ragenix instead of agenix to avoid the empty secrets bug
# See: secrets/CLAUDE.md for details about the agenix bug
nix run nixpkgs#ragenix -- --rekey --identity "$IDENTITY_FILE"
cd ..
echo "All secrets have been re-encrypted"