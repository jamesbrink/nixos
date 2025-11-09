# PostgreSQL Development Database Management Guide

This guide covers managing the PostgreSQL 13 development database on HAL9000, which can operate in either standby mode (read-only replica) or development mode (read-write).

**Last Updated:** August 1, 2025 - Removed postgres13-recovery-mode command, disabled archiving, enabled query logging

## Quick Commands

```bash
# Reset to latest base snapshot (standby mode)
postgres13-reset

# Switch to development mode (read-write)
postgres13-activate        # Recommended command
postgres13-dev-mode       # Alternative command

# Create a new base snapshot manually
postgres13-create-base

# Sync WAL files manually
postgres13-wal-sync       # Smart sync - only needed files
postgres13-wal-sync-full  # Full sync with retention cleanup

# Check current mode
sudo podman exec postgres13 psql -U postgres -t -c "SELECT pg_is_in_recovery();"
# Returns: 't' = standby mode, 'f' = development mode

# Check replication lag (when in standby mode)
sudo podman exec postgres13 psql -U postgres -c "SELECT pg_is_in_recovery() as is_replica, pg_last_wal_replay_lsn() as current_lsn, CASE WHEN pg_is_in_recovery() THEN EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp()))::int ELSE 0 END as lag_seconds;"
```

## Base Snapshot Management

### Automatic Base Snapshots

Base snapshots are automatically created every 3 days at 4 AM if:

- PostgreSQL is in recovery mode
- Replication lag is less than 1 hour
- No snapshot already exists for that day

Snapshots are named: `base@base-YYYYMMDD`

Base snapshots are created on the `storage-fast/quantierra/base` dataset to ensure they persist through resets.

### Manual Base Snapshot Creation

```bash
# Create a base snapshot manually (with safety checks)
postgres13-create-base
```

The script will:

- Verify PostgreSQL is in standby mode (recommended)
- Check replication lag
- Create snapshot named `base@base-YYYYMMDD` on the base dataset
- Keep only the last 3 base snapshots

### List Base Snapshots

```bash
sudo zfs list -t snapshot -o name,creation | grep "base@base-"
```

## Reset and Activation

### Reset to Base Snapshot (Standby Mode)

```bash
# Using command
postgres13-reset

# Using webhook
curl -H "X-Webhook-Token: WEBHOOK_TOKEN_RESET" http://localhost:9000/hooks/postgres-rollback
```

This will:

1. Kill the postgres13 container
2. Destroy the current postgres13 dataset
3. Clone from the **most recent** `base@base-*` snapshot
4. Add standby.signal to ensure recovery mode
5. Restart the container

### Activate Development Mode (Read-Write)

```bash
# Using command
postgres13-activate

# Using webhook
curl -H "X-Webhook-Token: WEBHOOK_TOKEN_ACTIVE" http://localhost:9000/hooks/postgres-rollback
```

This will:

1. Check if PostgreSQL is running
2. Remove standby.signal
3. Restart the container in read-write mode
4. Wait up to 5 minutes for recovery to complete (with progress updates)

## Initial Import Process

For importing a new base snapshot:

1. **Import the ZFS snapshot:**

   ```bash
   sudo zfs receive -F storage-fast/quantierra/base < ~/Downloads/pg_base_20250727.zfs
   ```

2. **Create initial clone:**

   ```bash
   sudo zfs clone storage-fast/quantierra/base@backup_20250727 storage-fast/quantierra/postgres13
   ```

3. **Add standby signal:**

   ```bash
   sudo touch /storage-fast/quantierra/postgres13/standby.signal
   ```

4. **Start PostgreSQL:**
   ```bash
   sudo systemctl start podman-postgres13.service
   ```

## WAL Sync and Retention

### Automated WAL Sync

WAL sync runs automatically every night at 3 AM:

```bash
# Check timer status
sudo systemctl status postgresql-wal-sync.timer

# View recent sync logs
journalctl -u postgresql-wal-sync.service -n 50

# Run manually
sudo systemctl start postgresql-wal-sync.service
```

### Manual WAL Sync

```bash
# Smart sync - detects needed WAL files
postgres13-wal-sync

# Full sync with retention cleanup
postgres13-wal-sync-full

# Just retention cleanup (3-day retention)
postgres13-wal-retention
```

### WAL Sync Features

- **Smart detection**: Checks PostgreSQL logs to find needed WAL files
- **Ordered sync**: Downloads files in sequence starting from what's needed
- **Direct sync**: No temporary directories, files go straight to archive
- **Proper permissions**: Runs as root, sets ownership to 999:999 (postgres in container)
- **Bandwidth limit**: 10MB/s to avoid network saturation
- **Source**: `jamesbrink@server01.myquantierra.com:/mnt/spinners/postgresql_backups/archive/`
- **Retention**: Removes WAL files older than 3 days
- **ZFS snapshots**: Creates `postgres13@wal-sync-*` snapshots after each sync

## Development Workflow

### Typical Development Cycle

1. **Ensure replica is up-to-date:**

   ```bash
   # Check replication lag
   sudo podman exec postgres13 psql -U postgres -c "SELECT EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp()))::int as lag_seconds;"
   ```

2. **Create a fresh base snapshot (optional):**

   ```bash
   postgres13-create-base
   ```

3. **Switch to development mode:**

   ```bash
   postgres13-activate
   ```

4. **Do your development work**

5. **Reset when done:**
   ```bash
   postgres13-reset
   ```

### Alternative Commands

```bash
# Alternative to postgres13-activate
postgres13-dev-mode      # Also switches to read-write mode

# Direct rollback script (called by postgres13-reset)
postgres13-rollback      # Resets to latest base snapshot
```

## Troubleshooting

### Check Current Mode

```bash
# Is it in recovery mode?
sudo podman exec postgres13 psql -U postgres -c "SELECT pg_is_in_recovery();"
# 't' = standby/recovery mode, 'f' = active/development mode
```

### WAL Recovery Issues

If PostgreSQL is stuck waiting for WAL files:

```bash
# Check what file it needs
sudo podman logs postgres13 | grep -E "(restored log file|gzip:)" | tail -20

# Run WAL sync
postgres13-wal-sync

# Monitor recovery progress
watch -n 2 'sudo podman exec postgres13 psql -U postgres -t -c "SELECT pg_last_wal_replay_lsn(), EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp()))::int as lag_seconds;"'
```

### Clean Recovery Restart

If you need a completely clean restart:

```bash
# Stop PostgreSQL
sudo systemctl stop podman-postgres13.service

# Clean WAL files
sudo rm -rf /storage-fast/quantierra/archive/*
sudo mkdir -p /storage-fast/quantierra/archive
sudo chown 999:999 /storage-fast/quantierra/archive

# Reset to base
postgres13-reset

# Start WAL sync
postgres13-wal-sync
```

## Service Configuration

### Timers

- **WAL Sync**: Daily at 3 AM
- **Base Snapshot**: Every 3 days at 4 AM (days 1,4,7,10,13,16,19,22,25,28,31)

### Webhook Endpoints

- **Reset**: `X-Webhook-Token: WEBHOOK_TOKEN_RESET`
- **Activate**: `X-Webhook-Token: WEBHOOK_TOKEN_ACTIVE`
- **Endpoint**: `http://localhost:9000/hooks/postgres-rollback`

### Web UI

- **ZFS Monitor**: <https://zfs.home.urandom.io> (includes reset button)

## Recent Updates (August 2025)

### Key Changes

- **Removed postgres13-recovery-mode**: Use `postgres13-reset` to return to standby mode
- **Disabled archiving**: Set `archive_mode = off` to prevent read-only filesystem errors
- **Query logging enabled**: All SQL statements are logged (`log_statement = 'all'`)
- **Verified all functionality**: All commands tested and working correctly

### Available Commands

1. **postgres13-reset**: Reset to latest base snapshot (standby mode)
2. **postgres13-activate**: Switch to development mode (read-write)
3. **postgres13-dev-mode**: Alternative command for development mode
4. **postgres13-create-base**: Manually create base snapshot
5. **postgres13-rollback**: Direct rollback script (used by reset)
6. **postgres13-wal-sync**: Smart WAL file synchronization
7. **postgres13-wal-sync-full**: Full sync with retention cleanup

### Features

- **Automatic base snapshots**: Every 3 days at 4 AM (days 1,4,7,10,13,16,19,22,25,28,31)
- **Automatic WAL sync**: Daily at 3 AM
- **Webhook control**: Reset via WEBHOOK_TOKEN_RESET, activate via WEBHOOK_TOKEN_ACTIVE
- **Smart WAL sync**: Only downloads needed files in correct order
- **Base dataset snapshots**: Snapshots persist through resets
- **Query logging**: All SQL statements logged for debugging

### Architecture Notes

- PostgreSQL runs in Podman container (postgis/postgis:13-3.5)
- Data stored on ZFS dataset: `/storage-fast/quantierra/postgres13`
- WAL files synced from production to `/storage-fast/quantierra/archive`
- Base snapshots created on `storage-fast/quantierra/base` dataset
- Configuration prevents archiving to avoid read-only filesystem errors in development mode
