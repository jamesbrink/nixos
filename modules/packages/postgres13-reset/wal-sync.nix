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

    # First, check what PostgreSQL is actually looking for
    if sudo ${pkgs.podman}/bin/podman ps | grep -q postgres13; then
      # Try to get the WAL file PostgreSQL is requesting from recent logs
      echo "Checking PostgreSQL logs for requested WAL files..."
      REQUESTED_WAL=$(sudo journalctl -u podman-postgres13 -n 100 --no-pager | grep -oE "restored log file \"[0-9A-F]{24}\"" | tail -1 | grep -oE "[0-9A-F]{24}" || echo "")
      if [ -n "$REQUESTED_WAL" ]; then
        echo "PostgreSQL is looking for WAL file: $REQUESTED_WAL"
        # Use this as the starting point
        START_SEGMENT="$REQUESTED_WAL"
      else
        echo "No WAL restore requests found in logs, checking for missing WAL files..."
        # Check what PostgreSQL is trying to restore
        MISSING_WAL=$(sudo journalctl -u podman-postgres13 -n 100 --no-pager | grep -oE "gzip: /var/lib/postgresql/archive/[0-9A-F]{24}\.gz: No such file" | tail -1 | grep -oE "[0-9A-F]{24}" || echo "")
        if [ -n "$MISSING_WAL" ]; then
          echo "PostgreSQL is missing WAL file: $MISSING_WAL"
          START_SEGMENT="$MISSING_WAL"
        else
          # Fall back to checking local files
          LAST_LOCAL_WAL=$(ls -1 "$ARCHIVE_DIR" 2>/dev/null | grep -E '^[0-9A-F]{24}\.gz$' | sort | tail -1 || echo "")
          if [ -z "$LAST_LOCAL_WAL" ]; then
            echo "No local WAL files found. Starting from snapshot base (00000001000042900000000D)"
            START_SEGMENT="00000001000042900000000D"
          else
            START_SEGMENT="''${LAST_LOCAL_WAL%.gz}"
          fi
        fi
      fi
    else
      # Container not running, use local files
      LAST_LOCAL_WAL=$(ls -1 "$ARCHIVE_DIR" 2>/dev/null | grep -E '^[0-9A-F]{24}\.gz$' | sort | tail -1 || echo "")
      if [ -z "$LAST_LOCAL_WAL" ]; then
        echo "No local WAL files found. Starting from snapshot base (00000001000042900000000D)"
        START_SEGMENT="00000001000042900000000D"
      else
        START_SEGMENT="''${LAST_LOCAL_WAL%.gz}"
      fi
    fi

    echo "Last local WAL/Starting point: $START_SEGMENT"

    # Extract timeline and log/segment numbers
    TIMELINE="''${START_SEGMENT:0:8}"
    LOG_SEQ="''${START_SEGMENT:8:8}"
    SEG_NUM="''${START_SEGMENT:16:8}"

    echo "Syncing WAL files from $START_SEGMENT onwards..."
    echo "Timeline: $TIMELINE, Log: $LOG_SEQ, Segment: $SEG_NUM"
    
    # First, let's check what files exist on the remote for our log sequence
    echo "Checking remote for files around log sequence $LOG_SEQ..."
    if [ "$(id -u)" = "0" ]; then
      REMOTE_FILES=$(sudo -u jamesbrink ssh jamesbrink@server01.myquantierra.com "ls -1 /mnt/spinners/postgresql_backups/archive/$TIMELINE$LOG_SEQ*.gz 2>/dev/null | head -10" || echo "")
    else
      REMOTE_FILES=$(ssh jamesbrink@server01.myquantierra.com "ls -1 /mnt/spinners/postgresql_backups/archive/$TIMELINE$LOG_SEQ*.gz 2>/dev/null | head -10" || echo "")
    fi
    
    if [ -n "$REMOTE_FILES" ]; then
      echo "Found remote files for current log sequence:"
      echo "$REMOTE_FILES" | head -5
    else
      echo "No files found on remote for log sequence $LOG_SEQ"
    fi

    # Build rsync include patterns for current and PREVIOUS log sequences too
    # This ensures we get any missing files that PostgreSQL might be looking for
    # Use an array to properly handle the arguments
    INCLUDE_ARGS=()
    
    # Include 10 sequences before the current one
    for i in {10..1}; do
      PREV_LOG=$(printf "%08X" $((0x$LOG_SEQ - i)))
      if [ $((0x$LOG_SEQ - i)) -ge 0 ]; then
        INCLUDE_ARGS+=("--include=$TIMELINE$PREV_LOG*")
      fi
    done

    # Include current and future sequences
    for i in {0..100}; do
      NEXT_LOG=$(printf "%08X" $((0x$LOG_SEQ + i)))
      INCLUDE_ARGS+=("--include=$TIMELINE$NEXT_LOG*")
    done

    # Also include any history files
    INCLUDE_ARGS+=("--include=*.history.gz")

    # Sync with bandwidth limit and compression
    # If running as root, use jamesbrink's SSH configuration
    echo "Syncing files from remote..."
    TEMP_DIR="/tmp/wal-sync-temp-$$"
    mkdir -p "$TEMP_DIR"
    
    # Debug: Show what patterns we're including
    echo "Include patterns being used:"
    printf '%s\n' "''${INCLUDE_ARGS[@]}"
    
    echo ""
    echo "Testing rsync command (dry-run):"
    if [ "$(id -u)" = "0" ]; then
      # Running as root, use jamesbrink's SSH key
      echo "Running as root, using sudo -u jamesbrink"
      sudo -u jamesbrink ${pkgs.rsync}/bin/rsync -avz \
        --bwlimit=10000 \
        --include='*/' \
        "''${INCLUDE_ARGS[@]}" \
        --exclude='*' \
        --dry-run --stats \
        "$REMOTE_SOURCE" \
        "$TEMP_DIR/"
      echo ""
      echo "Now running actual sync:"
      sudo -u jamesbrink ${pkgs.rsync}/bin/rsync -avz \
        --bwlimit=10000 \
        --include='*/' \
        "''${INCLUDE_ARGS[@]}" \
        --exclude='*' \
        "$REMOTE_SOURCE" \
        "$TEMP_DIR/"
    else
      # Running as regular user
      echo "Running as user $(whoami)"
      ${pkgs.rsync}/bin/rsync -avz \
        --bwlimit=10000 \
        --include='*/' \
        "''${INCLUDE_ARGS[@]}" \
        --exclude='*' \
        --dry-run --stats \
        "$REMOTE_SOURCE" \
        "$TEMP_DIR/"
      echo ""
      echo "Now running actual sync:"
      ${pkgs.rsync}/bin/rsync -avz \
        --bwlimit=10000 \
        --include='*/' \
        "''${INCLUDE_ARGS[@]}" \
        --exclude='*' \
        "$REMOTE_SOURCE" \
        "$TEMP_DIR/"
    fi
    
    # Move files to final destination with proper permissions
    echo "Checking temp directory for synced files:"
    ls -la "$TEMP_DIR/" | head -10 || echo "No files in temp directory"
    
    if ls "$TEMP_DIR"/*.gz >/dev/null 2>&1; then
      echo "Moving $(ls "$TEMP_DIR"/*.gz | wc -l) files to archive directory"
      sudo mv "$TEMP_DIR"/*.gz "$ARCHIVE_DIR/" 2>/dev/null || true
    else
      echo "No .gz files found in temp directory to move"
    fi
    rm -rf "$TEMP_DIR"

    # Fix permissions for PostgreSQL container (postgres user is UID 999 in container)
    echo "Fixing permissions for PostgreSQL container..."
    sudo chown -R 999:999 "$ARCHIVE_DIR"
    sudo chmod 755 "$ARCHIVE_DIR"
    # Only chmod actual .gz files, not rsync temporary files
    # Rsync creates temp files like .filename.gz.XXXXXX during transfer
    find "$ARCHIVE_DIR" -maxdepth 1 -name "*.gz" -type f ! -name ".*" -exec sudo chmod 640 {} \; 2>/dev/null || true

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
    sudo ${pkgs.zfs}/bin/zfs snapshot "storage-fast/quantierra/$SNAPSHOT_NAME" || true
    echo "Created ZFS snapshot: $SNAPSHOT_NAME"

    # Clean up old WAL sync snapshots (keep last 3)
    echo "Cleaning up old WAL sync snapshots..."
    sudo ${pkgs.zfs}/bin/zfs list -t snapshot -o name -s creation | \
      grep "storage-fast/quantierra/postgres13@wal-sync-" | \
      head -n -3 | \
      xargs -r -n1 sudo ${pkgs.zfs}/bin/zfs destroy || true
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
