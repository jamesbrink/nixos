#!/usr/bin/env bash
set -euo pipefail

if [ $# -eq 0 ]; then
  echo "Error: You must specify a hostname."
  echo "Usage: restic-run <hostname>"
  echo "Available hosts:"
  find ./hosts -maxdepth 1 -mindepth 1 -type d | sort | sed 's|./hosts/||'
  exit 1
fi

HOST="$1"

# Check if host is Darwin or Linux
if nix eval --json .#darwinConfigurations."$HOST"._type 2>/dev/null >/dev/null; then
  # Darwin host
  echo "Running backup on Darwin host $HOST..."
  ssh jamesbrink@"$HOST" "restic-backup backup" || {
    echo "Backup failed. If this is the first run, the repository should have been auto-initialized."
    echo "Check the error message above for details."
    exit 1
  }
elif nix eval --json .#nixosConfigurations."$HOST"._type 2>/dev/null >/dev/null; then
  # Linux host
  echo "Running backup on Linux host $HOST..."
  ssh root@"$HOST" "systemctl start restic-backups-s3-backup.service"
  echo ""
  echo "Backup started. Check status with:"
  echo "  ssh root@$HOST 'journalctl -u restic-backups-s3-backup.service -f'"
else
  echo "Error: Host '$HOST' not found in configurations"
  exit 1
fi
