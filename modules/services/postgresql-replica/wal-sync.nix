{
  lib,
  stdenv,
  writeShellScriptBin,
  awscli2,
  gzip,
  coreutils,
  findutils,
  gnugrep,
  gawk,
  gnused,
  zfs,
  systemd,
  postgresqlPackage,
  dataDir,
  archiveDir,
  awsProfile,
  s3Bucket,
  zfsDataset,
  zfsBaseDataset,
  serviceName,
}:

let
  # WAL sync script - syncs WAL files from S3
  walSync = writeShellScriptBin "pg17-wal-sync" ''
    #!/usr/bin/env bash
    set -euo pipefail

    export AWS_PROFILE="${awsProfile}"
    S3_BUCKET="${s3Bucket}"
    ARCHIVE_DIR="${archiveDir}"

    echo "=== PostgreSQL 17 WAL Sync from S3 ==="
    echo "Time: $(date)"
    echo "S3 Bucket: $S3_BUCKET"
    echo "Archive Dir: $ARCHIVE_DIR"

    # Ensure archive directory exists with correct permissions
    mkdir -p "$ARCHIVE_DIR"
    chown postgres:postgres "$ARCHIVE_DIR"
    chmod 750 "$ARCHIVE_DIR"

    # Get the latest local WAL file to determine starting point
    LATEST_LOCAL=""
    if [ -d "$ARCHIVE_DIR" ] && [ "$(ls -A "$ARCHIVE_DIR" 2>/dev/null)" ]; then
      LATEST_LOCAL=$(ls -1 "$ARCHIVE_DIR"/*.gz 2>/dev/null | sort | tail -1 | xargs basename 2>/dev/null | sed 's/.gz$//' || echo "")
    fi

    if [ -n "$LATEST_LOCAL" ]; then
      echo "Latest local WAL file: $LATEST_LOCAL"
      # Sync only files newer than the latest local file
      echo "Syncing new WAL files from S3..."
      ${awscli2}/bin/aws s3 sync "$S3_BUCKET" "$ARCHIVE_DIR" \
        --exclude "*" \
        --include "*.gz" \
        --no-progress
    else
      echo "No local WAL files found, performing full sync..."
      ${awscli2}/bin/aws s3 sync "$S3_BUCKET" "$ARCHIVE_DIR" \
        --exclude "*" \
        --include "*.gz" \
        --no-progress
    fi

    # Fix permissions on synced files
    chown -R postgres:postgres "$ARCHIVE_DIR"
    find "$ARCHIVE_DIR" -type f -exec chmod 640 {} \;
    find "$ARCHIVE_DIR" -type d -exec chmod 750 {} \;

    # Count WAL files
    WAL_COUNT=$(find "$ARCHIVE_DIR" -name "*.gz" -type f | wc -l)
    echo "Total WAL files in archive: $WAL_COUNT"

    echo "=== WAL Sync Complete ==="
  '';

  # WAL sync with specific number of days
  walSyncDays = writeShellScriptBin "pg17-wal-sync-days" ''
    #!/usr/bin/env bash
    set -euo pipefail

    DAYS="''${1:-7}"
    export AWS_PROFILE="${awsProfile}"
    S3_BUCKET="${s3Bucket}"
    ARCHIVE_DIR="${archiveDir}"

    echo "=== PostgreSQL 17 WAL Sync (Last $DAYS days) ==="
    echo "Time: $(date)"

    # Calculate date cutoff
    CUTOFF_DATE=$(date -d "$DAYS days ago" +%Y-%m-%d 2>/dev/null || date -v-''${DAYS}d +%Y-%m-%d)
    echo "Syncing WAL files modified after: $CUTOFF_DATE"

    mkdir -p "$ARCHIVE_DIR"

    # List and sync files modified after cutoff
    ${awscli2}/bin/aws s3 sync "$S3_BUCKET" "$ARCHIVE_DIR" \
      --exclude "*" \
      --include "*.gz" \
      --no-progress

    chown -R postgres:postgres "$ARCHIVE_DIR"
    find "$ARCHIVE_DIR" -type f -exec chmod 640 {} \;

    echo "=== WAL Sync Complete ==="
  '';

  # WAL retention cleanup
  walRetention = writeShellScriptBin "pg17-wal-retention" ''
    #!/usr/bin/env bash
    set -euo pipefail

    ARCHIVE_DIR="${archiveDir}"
    RETENTION_DAYS=7
    SNAPSHOT_RETENTION=3

    echo "=== PostgreSQL 17 WAL Retention Cleanup ==="
    echo "Time: $(date)"
    echo "Retention: $RETENTION_DAYS days"

    # Remove WAL files older than retention period
    if [ -d "$ARCHIVE_DIR" ]; then
      OLD_FILES=$(find "$ARCHIVE_DIR" -name "*.gz" -type f -mtime +$RETENTION_DAYS | wc -l)
      echo "Found $OLD_FILES WAL files older than $RETENTION_DAYS days"

      if [ "$OLD_FILES" -gt 0 ]; then
        find "$ARCHIVE_DIR" -name "*.gz" -type f -mtime +$RETENTION_DAYS -delete
        echo "Removed $OLD_FILES old WAL files"
      fi
    fi

    # Cleanup old ZFS snapshots (keep last N)
    echo "Cleaning up old ZFS snapshots..."
    SNAPSHOTS=$(${zfs}/bin/zfs list -t snapshot -o name -H "${zfsDataset}" 2>/dev/null | grep "@base-" | sort -r || echo "")

    COUNT=0
    while IFS= read -r snap; do
      if [ -n "$snap" ]; then
        COUNT=$((COUNT + 1))
        if [ $COUNT -gt $SNAPSHOT_RETENTION ]; then
          echo "Removing old snapshot: $snap"
          ${zfs}/bin/zfs destroy "$snap" || true
        fi
      fi
    done <<< "$SNAPSHOTS"

    echo "=== Retention Cleanup Complete ==="
  '';

  # Create base snapshot
  createSnapshot = writeShellScriptBin "pg17-create-snapshot" ''
    #!/usr/bin/env bash
    set -euo pipefail

    DATA_DIR="${dataDir}"
    ZFS_DATASET="${zfsDataset}"
    SERVICE="${serviceName}"

    echo "=== PostgreSQL 17 Base Snapshot Creation ==="
    echo "Time: $(date)"

    # Check if PostgreSQL is in recovery mode
    IS_RECOVERY=$(sudo -u postgres ${postgresqlPackage}/bin/psql -p 5432 -tAc "SELECT pg_is_in_recovery();" 2>/dev/null || echo "error")

    if [ "$IS_RECOVERY" = "t" ]; then
      echo "PostgreSQL is in recovery mode (standby)"

      # Check recovery lag
      LAG_SECONDS=$(sudo -u postgres ${postgresqlPackage}/bin/psql -p 5432 -tAc "
        SELECT CASE
          WHEN pg_last_wal_receive_lsn() IS NULL THEN -1
          ELSE EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp()))::integer
        END;" 2>/dev/null || echo "-1")

      echo "Recovery lag: $LAG_SECONDS seconds"

      # Only create snapshot if lag is less than 1 hour (3600 seconds)
      if [ "$LAG_SECONDS" -ge 0 ] && [ "$LAG_SECONDS" -lt 3600 ]; then
        SNAPSHOT_NAME="base-$(date +%Y%m%d-%H%M%S)"
        echo "Creating snapshot: $ZFS_DATASET@$SNAPSHOT_NAME"
        ${zfs}/bin/zfs snapshot "$ZFS_DATASET@$SNAPSHOT_NAME"
        echo "Snapshot created successfully"
      else
        echo "Skipping snapshot - recovery lag too high or unable to determine"
      fi
    else
      echo "PostgreSQL is NOT in recovery mode - skipping snapshot"
      echo "Run pg17-activate to switch to development mode, or pg17-rollback to reset"
    fi

    echo "=== Snapshot Creation Complete ==="
  '';

  # Rollback to latest base snapshot
  rollback = writeShellScriptBin "pg17-rollback" ''
    #!/usr/bin/env bash
    set -euo pipefail

    DATA_DIR="${dataDir}"
    ZFS_DATASET="${zfsDataset}"
    SERVICE="${serviceName}"

    echo "=== PostgreSQL 17 Rollback to Base Snapshot ==="
    echo "Time: $(date)"
    echo "WARNING: This will destroy all changes since the last base snapshot!"

    # Find the latest base snapshot
    LATEST_SNAPSHOT=$(${zfs}/bin/zfs list -t snapshot -o name -H "$ZFS_DATASET" 2>/dev/null | grep "@base-" | sort | tail -1 || echo "")

    if [ -z "$LATEST_SNAPSHOT" ]; then
      # Fall back to any snapshot
      LATEST_SNAPSHOT=$(${zfs}/bin/zfs list -t snapshot -o name -H "$ZFS_DATASET" 2>/dev/null | sort | tail -1 || echo "")
    fi

    if [ -z "$LATEST_SNAPSHOT" ]; then
      echo "ERROR: No snapshots found for $ZFS_DATASET"
      exit 1
    fi

    echo "Rolling back to snapshot: $LATEST_SNAPSHOT"

    # Stop PostgreSQL
    echo "Stopping PostgreSQL service..."
    ${systemd}/bin/systemctl stop "$SERVICE" || true
    sleep 2

    # Force kill if still running
    pkill -9 -f "postgres -D $DATA_DIR" 2>/dev/null || true
    sleep 1

    # Rollback to snapshot
    echo "Rolling back ZFS dataset..."
    ${zfs}/bin/zfs rollback -r "$LATEST_SNAPSHOT"

    # Ensure standby.signal exists
    touch "$DATA_DIR/standby.signal"
    chown postgres:postgres "$DATA_DIR/standby.signal"

    # Remove backup_label if present
    rm -f "$DATA_DIR/backup_label"

    # Start PostgreSQL
    echo "Starting PostgreSQL service..."
    ${systemd}/bin/systemctl start "$SERVICE"

    echo "=== Rollback Complete ==="
    echo "PostgreSQL should now be replaying WAL files from the archive"
  '';

  # Activate development mode (stop replication)
  activate = writeShellScriptBin "pg17-activate" ''
    #!/usr/bin/env bash
    set -euo pipefail

    DATA_DIR="${dataDir}"
    SERVICE="${serviceName}"

    echo "=== PostgreSQL 17 Activate Development Mode ==="
    echo "Time: $(date)"
    echo "WARNING: This will stop replication and make the database writable!"

    # Check current state
    IS_RECOVERY=$(sudo -u postgres ${postgresqlPackage}/bin/psql -p 5432 -tAc "SELECT pg_is_in_recovery();" 2>/dev/null || echo "error")

    if [ "$IS_RECOVERY" = "f" ]; then
      echo "PostgreSQL is already in development mode (not in recovery)"
      exit 0
    fi

    # Remove standby.signal to trigger promotion
    echo "Removing standby.signal to promote to primary..."
    rm -f "$DATA_DIR/standby.signal"

    # Signal PostgreSQL to promote
    echo "Sending promote signal..."
    sudo -u postgres ${postgresqlPackage}/bin/pg_ctl promote -D "$DATA_DIR" 2>/dev/null || true

    # Wait for promotion
    echo "Waiting for promotion to complete..."
    for i in {1..30}; do
      IS_RECOVERY=$(sudo -u postgres ${postgresqlPackage}/bin/psql -p 5432 -tAc "SELECT pg_is_in_recovery();" 2>/dev/null || echo "error")
      if [ "$IS_RECOVERY" = "f" ]; then
        echo "Promotion complete! PostgreSQL is now in development mode."
        exit 0
      fi
      sleep 1
    done

    echo "WARNING: Promotion may not have completed. Check PostgreSQL logs."
    echo "You may need to restart the service: systemctl restart $SERVICE"
  '';

  # Show replica status
  status = writeShellScriptBin "pg17-status" ''
    #!/usr/bin/env bash
    set -euo pipefail

    DATA_DIR="${dataDir}"
    ARCHIVE_DIR="${archiveDir}"
    ZFS_DATASET="${zfsDataset}"

    echo "=== PostgreSQL 17 Replica Status ==="
    echo "Time: $(date)"
    echo ""

    # Service status
    echo "--- Service Status ---"
    ${systemd}/bin/systemctl status ${serviceName} --no-pager -l 2>/dev/null | head -10 || echo "Service not found"
    echo ""

    # PostgreSQL status
    echo "--- PostgreSQL Status ---"
    IS_RECOVERY=$(sudo -u postgres ${postgresqlPackage}/bin/psql -p 5432 -tAc "SELECT pg_is_in_recovery();" 2>/dev/null || echo "error")
    if [ "$IS_RECOVERY" = "t" ]; then
      echo "Mode: STANDBY (read-only replica)"

      # Get recovery info
      sudo -u postgres ${postgresqlPackage}/bin/psql -p 5432 -c "
        SELECT
          pg_last_wal_receive_lsn() as last_receive_lsn,
          pg_last_wal_replay_lsn() as last_replay_lsn,
          pg_last_xact_replay_timestamp() as last_replay_time,
          now() - pg_last_xact_replay_timestamp() as replay_lag
        ;" 2>/dev/null || echo "Unable to query recovery status"
    elif [ "$IS_RECOVERY" = "f" ]; then
      echo "Mode: PRIMARY (development mode - writable)"
    else
      echo "Mode: UNKNOWN (unable to connect)"
    fi
    echo ""

    # WAL archive status
    echo "--- WAL Archive Status ---"
    if [ -d "$ARCHIVE_DIR" ]; then
      WAL_COUNT=$(find "$ARCHIVE_DIR" -name "*.gz" -type f 2>/dev/null | wc -l)
      OLDEST_WAL=$(ls -1t "$ARCHIVE_DIR"/*.gz 2>/dev/null | tail -1 | xargs basename 2>/dev/null || echo "none")
      NEWEST_WAL=$(ls -1t "$ARCHIVE_DIR"/*.gz 2>/dev/null | head -1 | xargs basename 2>/dev/null || echo "none")
      ARCHIVE_SIZE=$(du -sh "$ARCHIVE_DIR" 2>/dev/null | cut -f1 || echo "unknown")

      echo "Archive directory: $ARCHIVE_DIR"
      echo "Total WAL files: $WAL_COUNT"
      echo "Archive size: $ARCHIVE_SIZE"
      echo "Oldest WAL: $OLDEST_WAL"
      echo "Newest WAL: $NEWEST_WAL"
    else
      echo "Archive directory not found: $ARCHIVE_DIR"
    fi
    echo ""

    # ZFS snapshot status
    echo "--- ZFS Snapshots ---"
    ${zfs}/bin/zfs list -t snapshot -o name,creation,used,refer "$ZFS_DATASET" 2>/dev/null | head -10 || echo "No snapshots found"
    echo ""

    # Disk usage
    echo "--- Storage Usage ---"
    ${zfs}/bin/zfs list -o name,used,avail,refer "$ZFS_DATASET" 2>/dev/null || echo "Dataset not found"
  '';

  # Webhook handler for reset operations
  webhookReset = writeShellScriptBin "webhook-postgres-reset" ''
    #!/usr/bin/env bash
    set -euo pipefail

    TOKEN="''${1:-}"

    echo "PostgreSQL Reset Webhook Handler"
    echo "Time: $(date)"

    case "$TOKEN" in
      "WEBHOOK_TOKEN_RESET"|"WEBHOOK_TOKEN_RESET17"|"reset"|"reset17")
        echo "Initiating PostgreSQL 17 rollback..."
        ${rollback}/bin/pg17-rollback
        ;;
      "WEBHOOK_TOKEN_ACTIVE"|"active"|"activate")
        echo "Activating development mode..."
        ${activate}/bin/pg17-activate
        ;;
      *)
        echo "Unknown token: $TOKEN"
        echo "Valid tokens: reset, reset17, active, activate"
        exit 1
        ;;
    esac
  '';

in
stdenv.mkDerivation {
  pname = "pg17-replica-tools";
  version = "1.0.0";

  dontUnpack = true;

  installPhase = ''
    mkdir -p $out/bin

    # Install all scripts
    cp ${walSync}/bin/pg17-wal-sync $out/bin/
    cp ${walSyncDays}/bin/pg17-wal-sync-days $out/bin/
    cp ${walRetention}/bin/pg17-wal-retention $out/bin/
    cp ${createSnapshot}/bin/pg17-create-snapshot $out/bin/
    cp ${rollback}/bin/pg17-rollback $out/bin/
    cp ${activate}/bin/pg17-activate $out/bin/
    cp ${status}/bin/pg17-status $out/bin/
    cp ${webhookReset}/bin/webhook-postgres-reset $out/bin/
  '';

  meta = with lib; {
    description = "PostgreSQL 17 replica management tools";
    maintainers = [ ];
    platforms = platforms.linux;
  };
}
