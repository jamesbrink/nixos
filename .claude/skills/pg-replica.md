# PostgreSQL Replica Management

Skill for checking status and interacting with the PostgreSQL 17 read replica on hal9000.

## Commands

### /pg-status

Check the current status of the PostgreSQL replica.

```bash
ssh hal9000 "systemctl status postgresql-replica --no-pager 2>&1 | head -15; echo '---'; sudo -u postgres psql -p 5439 -c \"SELECT pg_is_in_recovery(), pg_last_wal_replay_lsn(), pg_last_xact_replay_timestamp();\""
```

### /pg-query

Run a read-only query on the replica. Usage: `/pg-query SELECT * FROM table LIMIT 10`

```bash
ssh hal9000 "sudo -u postgres psql -p 5439 -c \"<query>\""
```

### /pg-databases

List all databases on the replica.

```bash
ssh hal9000 "sudo -u postgres psql -p 5439 -c \"SELECT datname, pg_size_pretty(pg_database_size(datname)) as size FROM pg_database WHERE datistemplate = false ORDER BY pg_database_size(datname) DESC;\""
```

### /pg-tables

List tables in a database. Usage: `/pg-tables <database>`

```bash
ssh hal9000 "sudo -u postgres psql -p 5439 -d <database> -c \"SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname || '.' || tablename)) as size FROM pg_tables WHERE schemaname NOT IN ('pg_catalog', 'information_schema') ORDER BY pg_total_relation_size(schemaname || '.' || tablename) DESC LIMIT 20;\""
```

### /pg-wal-status

Check WAL archive and sync status.

```bash
ssh hal9000 "echo '=== WAL Archive ===' && sudo find /mnt/storage20tb/quantierra/wal -name '*.gz' -type f 2>/dev/null | wc -l && echo 'files' && sudo du -sh /mnt/storage20tb/quantierra/wal/ 2>/dev/null && echo '=== Latest WAL ===' && sudo find /mnt/storage20tb/quantierra/wal -name '*.gz' -type f 2>/dev/null | sort | tail -3"
```

### /pg-sync

Manually trigger a WAL sync from S3.

```bash
ssh hal9000 "sudo pg17-wal-sync"
```

### /pg-logs

View recent PostgreSQL logs.

```bash
ssh hal9000 "sudo bash -c 'tail -50 /storage-fast/pg_base/log/\$(ls -t /storage-fast/pg_base/log/ | head -1)'"
```

### /pg-connections

Show active connections to the replica.

```bash
ssh hal9000 "sudo -u postgres psql -p 5439 -c \"SELECT datname, usename, client_addr, state, query_start, LEFT(query, 60) as query FROM pg_stat_activity WHERE state != 'idle' ORDER BY query_start;\""
```

### /pg-snapshots

List ZFS snapshots for the replica.

```bash
ssh hal9000 "sudo zfs list -t snapshot storage-fast/pg_base"
```

### /pg-rollback

Rollback to the latest ZFS snapshot (stops service, rolls back, restarts).

```bash
ssh hal9000 "sudo pg17-rollback"
```

### /pg-activate

Promote replica to writable mode (stops replication).

```bash
ssh hal9000 "sudo pg17-activate"
```

## Connection Info

- **Host:** hal9000
- **Port:** 5439
- **Mode:** Read-only standby (unless activated)
- **Auth:** Trust for local, md5 for remote (uses primary's credentials)

## Notes

- The replica syncs WAL files from `s3://quantierra-backups/postgresql-archive/` daily at 3 AM
- Base snapshots are taken every 3 days at 4 AM
- Use `pg17-status` on hal9000 for a comprehensive local status check
