# PostgreSQL Development Database Management Guide

This guide covers managing the PostgreSQL development read-replica on HAL9000, including ZFS snapshot imports, WAL synchronization, and recovery management.

**Last Updated:** July 31, 2025 - Fixed WAL sync permissions and webhook functionality

## Import Process

1. **Import the ZFS snapshot:**
   ```bash
   sudo zfs receive -F storage-fast/quantierra/base < ~/Downloads/pg_base_20250727.zfs
   ```

2. **Create a clone from the snapshot:**
   ```bash
   sudo zfs clone storage-fast/quantierra/base@backup_20250727 storage-fast/quantierra/postgres13
   ```

3. **Add standby signal (for read-only mode):**
   ```bash
   sudo touch /storage-fast/quantierra/postgres13/standby.signal
   ```

4. **Start the PostgreSQL container:**
   ```bash
   sudo systemctl start podman-postgres13.service
   ```

5. **Sync WAL files for recovery (if needed):**
   ```bash
   # One-time manual sync to catch up
   postgres13-wal-sync
   
   # Or use the full sync with retention
   postgres13-wal-sync-full
   ```

## Update Configuration

If the snapshot name changes, update the webhook reset script:
1. Edit `/modules/packages/postgres13-reset/default.nix`
2. Update the snapshot name in line 24 (currently `backup_20250727`)
3. Deploy: `deploy hal9000`

## Verify

```bash
# Check clone exists
sudo zfs list -t all | grep postgres13

# Test connection
PGPASSWORD=postgres psql -h localhost -p 5432 -U postgres -d postgres -c "\l"

# Test reset functionality
sudo postgres13-rollback
```

## Reset Methods

- **Command:** `sudo postgres13-rollback`
- **Webhook:** POST to `http://localhost:9000/hooks/postgres-rollback` with header `X-Webhook-Token: WEBHOOK_TOKEN_RESET`
  ```bash
  curl -X POST http://localhost:9000/hooks/postgres-rollback -H "X-Webhook-Token: WEBHOOK_TOKEN_RESET"
  ```
- **Web UI:** Reset button at `https://zfs.home.urandom.io`

## WAL Sync and Retention

### Initial Setup After Snapshot Import

After importing a snapshot and starting PostgreSQL in recovery mode, you'll need to sync WAL files to catch up to the current state:

1. **Check which WAL file PostgreSQL needs:**
   ```bash
   sudo podman logs postgres13 | grep "gzip:" | tail -1
   # Look for the file it's trying to restore (e.g., 00000001000042900000000E.gz)
   ```

2. **Start WAL sync from the needed point:**
   ```bash
   # The postgres13-wal-sync script automatically detects the starting point
   postgres13-wal-sync
   ```

### Manual WAL Sync

```bash
# Sync only needed WAL files from the Quantierra server
postgres13-wal-sync

# Full sync with retention cleanup (3-day retention) - safe to run repeatedly
postgres13-wal-sync-full

# Just retention cleanup
postgres13-wal-retention
```

**Note:** The sync commands are idempotent and safe to run multiple times. They will only download files that don't already exist locally.

### WAL File Source

WAL files are synced from: `jamesbrink@server01.myquantierra.com:/mnt/spinners/postgresql_backups/archive/`

This avoids AWS S3 transfer costs while maintaining access to production WAL files.

### Automated WAL Sync Service

The PostgreSQL WAL sync is configured as a systemd service that runs as root for proper permissions:

```bash
# Enable nightly WAL sync (runs at 3 AM daily)
sudo systemctl enable postgresql-wal-sync.timer
sudo systemctl start postgresql-wal-sync.timer

# Check status
sudo systemctl status postgresql-wal-sync.timer
sudo systemctl status postgresql-wal-sync.service

# View logs
journalctl -u postgresql-wal-sync.service

# Run manually
sudo systemctl start postgresql-wal-sync.service
```

**Note:** The service runs as root but uses `sudo -u jamesbrink` for rsync to access SSH keys.

### WAL Sync Features

- **Smart sync**: Only downloads WAL files needed from the last local file onwards
- **Bandwidth limit**: 10MB/s to avoid network saturation
- **Compression**: Uses rsync compression for faster transfers
- **Source**: Syncs from `jamesbrink@server01.myquantierra.com:/mnt/spinners/postgresql_backups/archive/`
- **Retention**: Automatically removes WAL files older than 3 days
- **ZFS snapshots**: Creates snapshots after each successful sync (keeps last 3)

### Troubleshooting WAL Recovery

If PostgreSQL is stuck waiting for WAL files:

1. Check which file it needs:
   ```bash
   sudo podman logs postgres13 | tail -20
   ```

2. Manually sync the needed files:
   ```bash
   postgres13-wal-sync
   ```

3. Monitor recovery progress:
   ```bash
   sudo podman exec postgres13 psql -U postgres -c "SELECT pg_is_in_recovery(), pg_last_wal_replay_lsn();"
   ```

## Clean Recovery Restart Process

If you need to restart the recovery process clean (removing all WAL files):

1. **Stop PostgreSQL:**
   ```bash
   sudo systemctl stop podman-postgres13.service
   ```

2. **Clean up WAL files:**
   ```bash
   sudo rm -rf /storage-fast/quantierra/archive/*
   sudo mkdir -p /storage-fast/quantierra/archive
   sudo chown 999:999 /storage-fast/quantierra/archive
   ```

3. **Reset to base snapshot:**
   ```bash
   sudo postgres13-rollback
   ```

4. **Verify recovery mode:**
   ```bash
   sudo podman logs postgres13 | grep "gzip:" | tail -5
   # Should show it's looking for WAL files
   ```

5. **Start selective WAL sync:**
   ```bash
   postgres13-wal-sync
   # This will sync only from the needed WAL file onwards
   ```

## Development Mode Management

PostgreSQL can be switched between recovery (read-only) and normal (read-write) modes for development use:

### Switch to Development Mode (Read-Write)

```bash
# Enable read-write mode for development
postgres13-dev-mode
```

This command will:
- Check if PostgreSQL is in recovery mode
- Remove the `standby.signal` file
- Restart the container
- Verify PostgreSQL is in normal mode

### Switch Back to Recovery Mode (Read-Only)

```bash
# Return to read-only recovery mode
postgres13-recovery-mode
```

This command will:
- Check if PostgreSQL is in normal mode
- Add the `standby.signal` file
- Restart the container
- Verify PostgreSQL is back in recovery mode

### Check Current Mode

```bash
# Check if PostgreSQL is in recovery mode
sudo podman exec postgres13 psql -U postgres -c "SELECT pg_is_in_recovery();"
# Returns 't' for recovery mode, 'f' for normal mode
```

## Recent Fixes (July 2025)

### WAL Sync Improvements
- Fixed permission issues by running the systemd service as root
- Added logic to detect what WAL file PostgreSQL is requesting from logs
- Sync now includes previous sequences (10 back) to handle recovery gaps
- Added history file syncing for timeline changes
- Fixed ZFS snapshot creation permissions
- **Fixed rsync argument parsing**: Changed from string concatenation to bash array for include patterns
  - Root cause: Shell variable expansion was treating all include patterns as a single argument
  - Solution: Using `INCLUDE_ARGS=()` array and `"${INCLUDE_ARGS[@]}"` expansion
  - This fixed the issue where dry-run showed files but actual sync downloaded nothing

### Webhook Reset
- Updated webhook handler to accept both `WEBHOOK_TOKEN_RESET` and `reset`
- Fixed ZFS destroy to include snapshots with `-r` flag
- All ZFS commands now use sudo for proper permissions

### Known Issues
- PostgreSQL may show "invalid resource manager ID 39" errors for WAL files from different major versions
- The container uses UID 999 for the postgres user (not the standard system postgres user)