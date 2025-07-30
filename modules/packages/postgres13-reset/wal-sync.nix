# PostgreSQL WAL sync and retention management
{
  pkgs,
  lib ? pkgs.lib,
}:

let
  # WAL sync script with intelligent filtering
  postgres13-wal-sync = pkgs.writeScriptBin "postgres13-wal-sync" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    ARCHIVE_DIR="/storage-fast/quantierra/archive"
    REMOTE_SOURCE="jamesbrink@server01.myquantierra.com:/mnt/spinners/postgresql_backups/archive/"

    # Get the last WAL file we have locally
    LAST_LOCAL_WAL=$(ls -1 "$ARCHIVE_DIR" 2>/dev/null | grep -E '^[0-9A-F]{24}\.gz$' | sort | tail -1 || echo "")

    if [ -z "$LAST_LOCAL_WAL" ]; then
      echo "No local WAL files found. Starting from snapshot base (00000001000042900000000D)"
      START_SEGMENT="00000001000042900000000D"
    else
      # Extract the segment number from the last local WAL
      START_SEGMENT="''${LAST_LOCAL_WAL%.gz}"
      echo "Last local WAL: $START_SEGMENT"
    fi

    # Extract timeline and log/segment numbers
    TIMELINE="''${START_SEGMENT:0:8}"
    LOG_SEQ="''${START_SEGMENT:8:8}"
    SEG_NUM="''${START_SEGMENT:16:8}"

    echo "Syncing WAL files from $START_SEGMENT onwards..."
    echo "Timeline: $TIMELINE, Log: $LOG_SEQ, Segment: $SEG_NUM"

    # Build rsync include patterns for current and next few log sequences
    # This handles hex arithmetic for WAL file sequences
    INCLUDES=""
    for i in {0..2}; do
      NEXT_LOG=$(printf "%08X" $((0x$LOG_SEQ + i)))
      INCLUDES="$INCLUDES --include='$TIMELINE$NEXT_LOG*'"
    done

    # Sync with bandwidth limit and compression
    ${pkgs.rsync}/bin/rsync -avz \
      --bwlimit=10000 \
      --include='*/' \
      $INCLUDES \
      --exclude='*' \
      "$REMOTE_SOURCE" \
      "$ARCHIVE_DIR/"

    # Fix permissions for PostgreSQL container (postgres user is UID 999 in container)
    echo "Fixing permissions for PostgreSQL container..."
    sudo chown -R 999:999 "$ARCHIVE_DIR"
    sudo chmod -R 640 "$ARCHIVE_DIR"/*.gz 2>/dev/null || true

    echo "WAL sync completed successfully"
  '';

  # WAL retention script with ZFS snapshot integration
  postgres13-wal-retention = pkgs.writeScriptBin "postgres13-wal-retention" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    ARCHIVE_DIR="/storage-fast/quantierra/archive"
    RETENTION_DAYS=3

    echo "Running WAL retention cleanup (keeping $RETENTION_DAYS days)..."

    # Find and remove WAL files older than retention period
    find "$ARCHIVE_DIR" -name "*.gz" -type f -mtime +$RETENTION_DAYS -delete || true

    # Count remaining files
    WAL_COUNT=$(find "$ARCHIVE_DIR" -name "*.gz" -type f | wc -l)
    echo "Remaining WAL files: $WAL_COUNT"

    # Create ZFS snapshot after successful sync and cleanup
    SNAPSHOT_NAME="postgres13@wal-sync-$(date +%Y%m%d-%H%M%S)"
    ${pkgs.zfs}/bin/zfs snapshot "storage-fast/quantierra/$SNAPSHOT_NAME" || true
    echo "Created ZFS snapshot: $SNAPSHOT_NAME"

    # Clean up old WAL sync snapshots (keep last 3)
    echo "Cleaning up old WAL sync snapshots..."
    ${pkgs.zfs}/bin/zfs list -t snapshot -o name -s creation | \
      grep "storage-fast/quantierra/postgres13@wal-sync-" | \
      head -n -3 | \
      xargs -r -n1 ${pkgs.zfs}/bin/zfs destroy || true
  '';

  # Combined sync and retention script
  postgres13-wal-sync-full = pkgs.writeScriptBin "postgres13-wal-sync-full" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    echo "=== PostgreSQL WAL Sync and Retention ==="
    echo "Started at: $(date)"

    # Run sync
    ${postgres13-wal-sync}/bin/postgres13-wal-sync

    # Run retention cleanup
    ${postgres13-wal-retention}/bin/postgres13-wal-retention

    echo "Completed at: $(date)"
  '';

  # Development mode script to switch from recovery to normal mode
  postgres13-dev-mode = pkgs.writeScriptBin "postgres13-dev-mode" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    echo "=== Switching PostgreSQL to Development Mode ==="

    # Check if container is running
    if ! sudo ${pkgs.podman}/bin/podman ps | grep -q postgres13; then
      echo "Error: postgres13 container is not running"
      exit 1
    fi

    # Check current recovery status
    RECOVERY_STATUS=$(sudo ${pkgs.podman}/bin/podman exec postgres13 psql -U postgres -t -c "SELECT pg_is_in_recovery();" | tr -d ' ')

    if [ "$RECOVERY_STATUS" = "f" ]; then
      echo "PostgreSQL is already in normal (read-write) mode"
      exit 0
    fi

    echo "PostgreSQL is currently in recovery mode"
    echo "Removing standby.signal to switch to normal mode..."

    # Remove standby signal file
    sudo rm -f /storage-fast/quantierra/postgres13/standby.signal

    # Restart the container to apply changes
    echo "Restarting PostgreSQL container..."
    sudo systemctl restart podman-postgres13.service

    # Wait for container to be ready
    echo "Waiting for PostgreSQL to start..."
    sleep 5

    # Verify the mode change
    for i in {1..10}; do
      if sudo ${pkgs.podman}/bin/podman exec postgres13 psql -U postgres -c "SELECT 1;" &>/dev/null; then
        RECOVERY_STATUS=$(sudo ${pkgs.podman}/bin/podman exec postgres13 psql -U postgres -t -c "SELECT pg_is_in_recovery();" | tr -d ' ')
        if [ "$RECOVERY_STATUS" = "f" ]; then
          echo "✓ PostgreSQL is now in normal (read-write) mode"
          echo "✓ Development mode enabled successfully"
          exit 0
        fi
      fi
      echo "Waiting for PostgreSQL to be ready... ($i/10)"
      sleep 2
    done

    echo "Error: Failed to switch to development mode"
    exit 1
  '';

  # Recovery mode script to switch back to standby mode
  postgres13-recovery-mode = pkgs.writeScriptBin "postgres13-recovery-mode" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    echo "=== Switching PostgreSQL back to Recovery Mode ==="

    # Check if container is running
    if ! sudo ${pkgs.podman}/bin/podman ps | grep -q postgres13; then
      echo "Error: postgres13 container is not running"
      exit 1
    fi

    # Check current recovery status
    RECOVERY_STATUS=$(sudo ${pkgs.podman}/bin/podman exec postgres13 psql -U postgres -t -c "SELECT pg_is_in_recovery();" | tr -d ' ')

    if [ "$RECOVERY_STATUS" = "t" ]; then
      echo "PostgreSQL is already in recovery (read-only) mode"
      exit 0
    fi

    echo "PostgreSQL is currently in normal mode"
    echo "Adding standby.signal to switch to recovery mode..."

    # Add standby signal file
    sudo touch /storage-fast/quantierra/postgres13/standby.signal

    # Restart the container to apply changes
    echo "Restarting PostgreSQL container..."
    sudo systemctl restart podman-postgres13.service

    # Wait for container to be ready
    echo "Waiting for PostgreSQL to start in recovery mode..."
    sleep 5

    # Verify the mode change
    for i in {1..10}; do
      if sudo ${pkgs.podman}/bin/podman exec postgres13 psql -U postgres -c "SELECT 1;" &>/dev/null; then
        RECOVERY_STATUS=$(sudo ${pkgs.podman}/bin/podman exec postgres13 psql -U postgres -t -c "SELECT pg_is_in_recovery();" | tr -d ' ')
        if [ "$RECOVERY_STATUS" = "t" ]; then
          echo "✓ PostgreSQL is now in recovery (read-only) mode"
          echo "✓ Recovery mode enabled successfully"
          exit 0
        fi
      fi
      echo "Waiting for PostgreSQL to be ready... ($i/10)"
      sleep 2
    done

    echo "Error: Failed to switch to recovery mode"
    exit 1
  '';

in
pkgs.symlinkJoin {
  name = "postgres13-wal-sync";
  paths = [
    postgres13-wal-sync
    postgres13-wal-retention
    postgres13-wal-sync-full
    postgres13-dev-mode
    postgres13-recovery-mode
  ];
}
