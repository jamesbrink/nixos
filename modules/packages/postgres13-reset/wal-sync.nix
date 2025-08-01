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
    if  ${pkgs.podman}/bin/podman ps | grep -q postgres13; then
      # Try to get the WAL file PostgreSQL is requesting from recent logs
      echo "Checking PostgreSQL logs for requested WAL files..."
      REQUESTED_WAL=$( journalctl -u podman-postgres13 -n 100 --no-pager | grep -oE "restored log file \"[0-9A-F]{24}\"" | tail -1 | grep -oE "[0-9A-F]{24}" || echo "")
      if [ -n "$REQUESTED_WAL" ]; then
        echo "PostgreSQL is looking for WAL file: $REQUESTED_WAL"
        # Use this as the starting point
        START_SEGMENT="$REQUESTED_WAL"
      else
        echo "No WAL restore requests found in logs, checking for missing WAL files..."
        # Check what PostgreSQL is trying to restore
        MISSING_WAL=$( journalctl -u podman-postgres13 -n 100 --no-pager | grep -oE "gzip: /var/lib/postgresql/archive/[0-9A-F]{24}\.gz: No such file" | tail -1 | grep -oE "[0-9A-F]{24}" || echo "")
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
            # Get the next segment after the last local one
            LAST_SEGMENT="''${LAST_LOCAL_WAL%.gz}"
            TIMELINE="''${LAST_SEGMENT:0:8}"
            LOG_SEQ="''${LAST_SEGMENT:8:8}"
            SEG_NUM="''${LAST_SEGMENT:16:8}"
            
            # Increment the segment number
            NEXT_SEG=$(printf "%08X" $((0x$SEG_NUM + 1)))
            
            # Handle segment wraparound (FF -> 00 with log increment)
            if [ "$NEXT_SEG" = "00000100" ]; then
              NEXT_SEG="00000000"
              LOG_SEQ=$(printf "%08X" $((0x$LOG_SEQ + 1)))
            fi
            
            START_SEGMENT="''${TIMELINE}''${LOG_SEQ}''${NEXT_SEG}"
            echo "Last local WAL: $LAST_SEGMENT"
            echo "Starting from next WAL: $START_SEGMENT"
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
        # Get the next segment after the last local one
        LAST_SEGMENT="''${LAST_LOCAL_WAL%.gz}"
        TIMELINE="''${LAST_SEGMENT:0:8}"
        LOG_SEQ="''${LAST_SEGMENT:8:8}"
        SEG_NUM="''${LAST_SEGMENT:16:8}"
        
        # Increment the segment number
        NEXT_SEG=$(printf "%08X" $((0x$SEG_NUM + 1)))
        
        # Handle segment wraparound (FF -> 00 with log increment)
        if [ "$NEXT_SEG" = "00000100" ]; then
          NEXT_SEG="00000000"
          LOG_SEQ=$(printf "%08X" $((0x$LOG_SEQ + 1)))
        fi
        
        START_SEGMENT="''${TIMELINE}''${LOG_SEQ}''${NEXT_SEG}"
        echo "Last local WAL: $LAST_SEGMENT"
        echo "Starting from next WAL: $START_SEGMENT"
      fi
    fi

    # Extract timeline and log/segment numbers
    TIMELINE="''${START_SEGMENT:0:8}"
    LOG_SEQ="''${START_SEGMENT:8:8}"
    SEG_NUM="''${START_SEGMENT:16:8}"

    echo "Syncing WAL files from $START_SEGMENT onwards..."
    echo "Timeline: $TIMELINE, Log: $LOG_SEQ, Segment: $SEG_NUM"

    # First, let's check what files exist on the remote for our log sequence
    echo "Checking remote for files around log sequence $LOG_SEQ..."
    if [ "$(id -u)" = "0" ]; then
      REMOTE_FILES=$( -u jamesbrink ssh jamesbrink@server01.myquantierra.com "ls -1 /mnt/spinners/postgresql_backups/archive/$TIMELINE$LOG_SEQ*.gz 2>/dev/null | head -10" || echo "")
    else
      REMOTE_FILES=$(ssh jamesbrink@server01.myquantierra.com "ls -1 /mnt/spinners/postgresql_backups/archive/$TIMELINE$LOG_SEQ*.gz 2>/dev/null | head -10" || echo "")
    fi

    if [ -n "$REMOTE_FILES" ]; then
      echo "Found remote files for current log sequence:"
      echo "$REMOTE_FILES" | head -5
    else
      echo "No files found on remote for log sequence $LOG_SEQ"
    fi

    # Build rsync include patterns starting from the exact segment we need
    INCLUDE_ARGS=()

    # Get the decimal value of log sequence and segment
    LOG_DEC=$((0x$LOG_SEQ))
    SEG_DEC=$((0x$SEG_NUM))

    # We'll create precise patterns to get files in order
    # Start with the exact file we need
    INCLUDE_ARGS+=("--include=''${START_SEGMENT}.gz")

    # Add patterns for subsequent segments in the same log
    for ((i = $((SEG_DEC + 1)); i <= 255; i++)); do
      NEXT_SEG=$(printf "%08X" $i)
      INCLUDE_ARGS+=("--include=''${TIMELINE}''${LOG_SEQ}''${NEXT_SEG}.gz")
    done

    # Add patterns for future log sequences (with all segments)
    for ((i = 1; i <= 100; i++)); do
      NEXT_LOG=$(printf "%08X" $((LOG_DEC + i)))
      INCLUDE_ARGS+=("--include=''${TIMELINE}''${NEXT_LOG}*.gz")
    done

    # Also include any previous segments we might have missed (just a few)
    if [ $SEG_DEC -gt 0 ]; then
      for ((i = $((SEG_DEC - 1)); i >= $((SEG_DEC - 5)) && i >= 0; i--)); do
        PREV_SEG=$(printf "%08X" $i)
        INCLUDE_ARGS+=("--include=''${TIMELINE}''${LOG_SEQ}''${PREV_SEG}.gz")
      done
    fi

    # Include history files
    INCLUDE_ARGS+=("--include=*.history.gz")

    echo "Syncing files directly to archive directory..."
    echo "Number of include patterns: ''${#INCLUDE_ARGS[@]}"

    # Fix permissions before syncing
    echo "Preparing archive directory..."
     chown -R 999:999 "$ARCHIVE_DIR"
     chmod 755 "$ARCHIVE_DIR"

    # Run rsync with  directly
    echo "Starting rsync..."
     ${pkgs.rsync}/bin/rsync -avz \
      --bwlimit=10000 \
      --include='*/' \
      "''${INCLUDE_ARGS[@]}" \
      --exclude='*' \
      --timeout=300 \
      --chown=999:999 \
      --chmod=F640,D755 \
      -e "${pkgs.openssh}/bin/ssh -o User=jamesbrink" \
      "$REMOTE_SOURCE" \
      "$ARCHIVE_DIR/"

    # Show what we have now
    echo ""
    echo "Current archive status:"
    TOTAL_FILES=$(find "$ARCHIVE_DIR" -name "*.gz" -type f | wc -l)
    NEWEST_FILE=$(ls -1t "$ARCHIVE_DIR"/*.gz 2>/dev/null | head -1 | xargs basename 2>/dev/null || echo "none")
    echo "Total WAL files: $TOTAL_FILES"
    echo "Newest file: $NEWEST_FILE"

    echo ""
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
      xargs -r -n1  ${pkgs.zfs}/bin/zfs destroy || true
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
    if !  ${pkgs.podman}/bin/podman ps | grep -q postgres13; then
      echo "Error: postgres13 container is not running"
      exit 1
    fi

    # Check current recovery status
    RECOVERY_STATUS=$( ${pkgs.podman}/bin/podman exec postgres13 psql -U postgres -t -c "SELECT pg_is_in_recovery();" | tr -d ' ')

    if [ "$RECOVERY_STATUS" = "f" ]; then
      echo "PostgreSQL is already in normal (read-write) mode"
      exit 0
    fi

    echo "PostgreSQL is currently in recovery mode"
    echo "Removing standby.signal to switch to normal mode..."

    # Remove standby signal file
     rm -f /storage-fast/quantierra/postgres13/standby.signal

    # Restart the container to apply changes
    echo "Restarting PostgreSQL container..."
     systemctl restart podman-postgres13.service

    # Wait for container to be ready
    echo "Waiting for PostgreSQL to start..."
    sleep 5

    # Verify the mode change
    for i in {1..10}; do
      if  ${pkgs.podman}/bin/podman exec postgres13 psql -U postgres -c "SELECT 1;" &>/dev/null; then
        RECOVERY_STATUS=$( ${pkgs.podman}/bin/podman exec postgres13 psql -U postgres -t -c "SELECT pg_is_in_recovery();" | tr -d ' ')
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

  # Base snapshot creation script
  postgres13-create-base-auto = pkgs.writeScriptBin "postgres13-create-base-auto" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    echo "=== Automatic Base Snapshot Creation ==="
    echo "Started at: $(date)"

    # Check if PostgreSQL is in recovery mode
    RECOVERY_STATUS=$( ${pkgs.podman}/bin/podman exec postgres13 psql -U postgres -t -c "SELECT pg_is_in_recovery();" 2>/dev/null | tr -d ' ' || echo "error")

    if [ "$RECOVERY_STATUS" != "t" ]; then
      echo "Error: PostgreSQL is not in recovery mode. Skipping base snapshot creation."
      exit 1
    fi

    # Check replication lag
    LAG_INFO=$( ${pkgs.podman}/bin/podman exec postgres13 psql -U postgres -t -c "SELECT CASE WHEN pg_is_in_recovery() THEN EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp()))::int ELSE 0 END as lag_seconds;" 2>/dev/null | tr -d ' ' || echo "999999")

    if [ "$LAG_INFO" -gt 3600 ]; then
      echo "Error: Replication lag is $LAG_INFO seconds (> 1 hour). Skipping base snapshot creation."
      exit 1
    fi

    # Check if a base snapshot already exists for today
    TODAY=$(date +%Y%m%d)
    EXISTING=$( ${pkgs.zfs}/bin/zfs list -t snapshot -o name | grep "base@base-$TODAY" || echo "")

    if [ -n "$EXISTING" ]; then
      echo "Base snapshot for today already exists: $EXISTING"
      exit 0
    fi

    # Create the base snapshot on the base dataset
    SNAPSHOT_NAME="base@base-$TODAY"
    echo "Creating base snapshot: $SNAPSHOT_NAME"
     ${pkgs.zfs}/bin/zfs snapshot "storage-fast/quantierra/$SNAPSHOT_NAME"

    # Clean up old base snapshots (keep last 3)
    echo "Cleaning up old base snapshots..."
    # Count total base snapshots
    TOTAL_SNAPSHOTS=$( ${pkgs.zfs}/bin/zfs list -t snapshot -o name | grep "storage-fast/quantierra/base@base-" | wc -l)
    if [ "$TOTAL_SNAPSHOTS" -gt 3 ]; then
      TO_DELETE=$((TOTAL_SNAPSHOTS - 3))
       ${pkgs.zfs}/bin/zfs list -t snapshot -o name -s creation | \
        grep "storage-fast/quantierra/base@base-" | \
        head -n "$TO_DELETE" | \
        xargs -r -n1  ${pkgs.zfs}/bin/zfs destroy || true
    fi

    # List remaining base snapshots
    echo ""
    echo "Current base snapshots:"
     ${pkgs.zfs}/bin/zfs list -t snapshot -o name,creation | grep "base@base-" || echo "None found"

    echo ""
    echo "Automatic base snapshot completed at: $(date)"
  '';

in
pkgs.symlinkJoin {
  name = "postgres13-wal-sync";
  paths = [
    postgres13-wal-sync
    postgres13-wal-retention
    postgres13-wal-sync-full
    postgres13-dev-mode
    postgres13-create-base-auto
  ];
}
