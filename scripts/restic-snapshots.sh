#!/usr/bin/env bash
set -euo pipefail

if [ $# -eq 0 ]; then
  echo "Error: You must specify a hostname."
  echo "Usage: restic-snapshots <hostname>"
  echo "Available hosts:"
  find ./hosts -maxdepth 1 -mindepth 1 -type d | sort | sed 's|./hosts/||'
  exit 1
fi

HOST="$1"

# Repository path
REPO="s3:s3.us-west-2.amazonaws.com/urandom-io-backups/$HOST"

echo "Listing snapshots for $HOST..."
echo "Repository: $REPO"
echo ""

# Check if we have the credentials
if [ ! -f "$HOME/.config/restic/s3-env" ]; then
  echo "Error: Restic S3 credentials not found at ~/.config/restic/s3-env"
  echo "Deploy to a host with Restic configured to get the credentials."
  exit 1
fi

if [ ! -f "$HOME/.config/restic/password" ]; then
  echo "Error: Restic password not found at ~/.config/restic/password"
  echo "Deploy to a host with Restic configured to get the password."
  exit 1
fi

# Load environment and run restic
set -a
source "$HOME/.config/restic/s3-env"
set +a

export RESTIC_PASSWORD_FILE="$HOME/.config/restic/password"

# Use RESTIC_PATH if provided, otherwise use restic from PATH
RESTIC_CMD="${RESTIC_PATH:-restic}"
"$RESTIC_CMD" -r "$REPO" snapshots