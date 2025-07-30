# PostgreSQL ZFS Snapshot Import Guide

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
   sudo systemctl start podman-postgis13.service
   ```

## Update Configuration

If the snapshot name changes, update the webhook reset script:
1. Edit `/modules/packages/postgis-reset/default.nix`
2. Update the snapshot name in lines 23-24
3. Deploy: `deploy hal9000`

## Verify

```bash
# Check clone exists
sudo zfs list -t all | grep postgres13

# Test connection
PGPASSWORD=postgres psql -h localhost -p 5432 -U postgres -d postgres -c "\l"

# Test reset functionality
sudo postgis-rollback
```

## Reset Methods

- **Command:** `sudo postgis-rollback`
- **Webhook:** POST to `https://webhook.home.urandom.io/hooks/postgis-rollback` with header `X-Webhook-Token: reset`
- **Web UI:** Reset button at `https://zfs.home.urandom.io`