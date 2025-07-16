#!/usr/bin/env bash
set -euo pipefail

echo "Checking Restic backup status on all hosts..."
echo ""

# Define all hosts
LINUX_HOSTS="alienware hal9000 n100-01 n100-02 n100-03 n100-04"
DARWIN_HOSTS="halcyon sevastopol darkstarmk6mod1"

for HOST in $LINUX_HOSTS; do
  echo "──────────────────────────────────────────────────────"
  echo "Host: $HOST (Linux)"
  echo "──────────────────────────────────────────────────────"
  
  # Check if host is reachable
  if ! ssh -o ConnectTimeout=5 -o BatchMode=yes root@$HOST echo >/dev/null 2>&1; then
    echo "❌ Host unreachable"
    echo ""
    continue
  fi
  
  # Check backup timer status
  ssh root@$HOST "systemctl status restic-backups-s3-backup.timer --no-pager | head -n 15" 2>&1 || echo "Timer not found"
  echo ""
done

for HOST in $DARWIN_HOSTS; do
  echo "──────────────────────────────────────────────────────"
  echo "Host: $HOST (Darwin)"
  echo "──────────────────────────────────────────────────────"
  
  # Check if host is reachable
  if ! ssh -o ConnectTimeout=5 -o BatchMode=yes jamesbrink@$HOST echo >/dev/null 2>&1; then
    echo "❌ Host unreachable"
    echo ""
    continue
  fi
  
  # Check launchd agent status
  ssh jamesbrink@$HOST "launchctl list | grep restic-backup || echo 'Backup agent not loaded'" 2>&1
  echo ""
done