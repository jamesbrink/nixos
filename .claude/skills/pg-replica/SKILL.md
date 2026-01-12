---
name: pg-replica
description: Manage the PostgreSQL 17 read replica on hal9000. Use this skill when asked to check PostgreSQL status, run queries on the replica, view replication lag, manage WAL archives, or interact with the hal9000 database. Always use the helper scripts in the scripts/ directory rather than constructing SSH commands manually.
---

# PostgreSQL 17 Replica Management

Manage the read replica of Quantierra's PostgreSQL 17 database running on hal9000.

## Quick Reference

| Task                                | Script                               |
| ----------------------------------- | ------------------------------------ |
| Quick status                        | `pg17-status`                        |
| Full status (service + replication) | `pg17-full-status`                   |
| Replication lag                     | `pg17-lag`                           |
| Run query                           | `pg17-query "SELECT ..." [database]` |
| List databases                      | `pg17-databases`                     |
| List tables                         | `pg17-tables <database>`             |
| View logs                           | `pg17-logs [lines]`                  |
| WAL archive status                  | `pg17-wal-status`                    |
| Active connections                  | `pg17-connections`                   |
| ZFS snapshots                       | `pg17-snapshots`                     |

## Usage

**Always use the helper scripts** located in `.claude/skills/pg-replica/scripts/`. These scripts handle SSH connection, proper port (5432), and host (localhost) configuration automatically.

```bash
# Check replica status
.claude/skills/pg-replica/scripts/pg17-status

# Run a query
.claude/skills/pg-replica/scripts/pg17-query "SELECT count(*) FROM users" quantierra

# View last 100 lines of logs
.claude/skills/pg-replica/scripts/pg17-logs 100
```

## Remote Commands (on hal9000)

For operations not covered by scripts, SSH to hal9000 and use these system commands:

| Command                                      | Description                             |
| -------------------------------------------- | --------------------------------------- |
| `sudo pg17-wal-sync`                         | Trigger WAL sync from S3                |
| `sudo pg17-create-snapshot`                  | Create ZFS snapshot                     |
| `sudo pg17-rollback`                         | Rollback to latest snapshot             |
| `sudo pg17-activate`                         | Promote to writable (stops replication) |
| `sudo systemctl <action> postgresql-replica` | Service control (start/stop/restart)    |

## Architecture

See [architecture.md](architecture.md) for detailed infrastructure information.
