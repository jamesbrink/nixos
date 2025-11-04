#!/usr/bin/env bash
set -euo pipefail

# Check for files larger than 5MB
LARGE_FILES=$(find . -type f -size +5000k | grep -vE "^\./\.(git|nix-profile)" | grep -vE "^\./(result|result-|secrets|nix-secrets|nixos-old)" || true)

if [ -n "$LARGE_FILES" ]; then
    echo "Error: Large files detected (>5MB):"
    echo "$LARGE_FILES"
    exit 1
fi

exit 0