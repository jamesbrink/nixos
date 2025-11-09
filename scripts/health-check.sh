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
  echo "Usage: health-check <hostname>"
  echo "Available hosts:"
  find ./hosts -maxdepth 1 -mindepth 1 -type d | sort | sed 's|./hosts/||'
  exit 1
fi

HOSTNAME=$(hostname)

echo "Checking system health on $HOST..."

if [ "$HOSTNAME" = "$HOST" ]; then
  # Local health check
  echo -e "\nDisk usage on $HOST:"
  df -h | grep -v tmpfs
  echo -e "\nMemory usage on $HOST:"
  free -h
  echo -e "\nSystem load on $HOST:"
  uptime
  echo -e "\nFailed services on $HOST:"
  systemctl --failed
  echo -e "\nJournal errors on $HOST (last 10):"
  journalctl -p 3 -xn 10
else
  # Remote health check
  # Check if host is darwin or linux by checking flake configuration
  if nix eval --json .#darwinConfigurations."$HOST"._type 2>/dev/null >/dev/null; then
    # Darwin host - use regular user with sudo where needed
    echo -e "\nDisk usage on $HOST:"
    ssh jamesbrink@"$HOST" "df -h | grep -v tmpfs"
    echo -e "\nMemory usage on $HOST:"
    ssh jamesbrink@"$HOST" "vm_stat | perl -ne '/page size of (\d+)/ and \$size=\$1; /Pages\s+([^:]+)[^\d]+(\d+)/ and printf(\"%-20s %8.2f GB\\n\", \"\$1:\", \$2 * \$size / 1073741824);'"
    echo -e "\nSystem load on $HOST:"
    ssh jamesbrink@"$HOST" "uptime"
    echo -e "\nSystem services on $HOST:"
    ssh jamesbrink@"$HOST" "sudo launchctl list | grep -E '(com.apple|org.nixos)' | head -20"
  else
    # NixOS host - use root
    echo -e "\nDisk usage on $HOST:"
    ssh root@"$HOST" "df -h | grep -v tmpfs"
    echo -e "\nMemory usage on $HOST:"
    ssh root@"$HOST" "free -h"
    echo -e "\nSystem load on $HOST:"
    ssh root@"$HOST" "uptime"
    echo -e "\nFailed services on $HOST:"
    ssh root@"$HOST" "systemctl --failed"
    echo -e "\nJournal errors on $HOST (last 10):"
    ssh root@"$HOST" "journalctl -p 3 -xn 10"
  fi
fi

echo -e "\nHealth check for $HOST complete."
