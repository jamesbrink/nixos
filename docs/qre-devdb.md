# qre-devdb: Quantierra dev database on hal9000

A copy of Quantierra's production PostgreSQL (server01, 3.1 TB logical,
~2.1 TB on ZFS) that lives on hal9000's 20 TB disk and is served as a
promoted ZFS clone on port 5433. It is restored from prod's pgBackRest
repository in S3 (`s3://quantierra-backups/pgbackrest`, stanza `default`)
with a read-only IAM user; nothing on hal9000 can write to prod or to its
backups. Module: `modules/services/qre-devdb.nix`. The workflow is
loader-dev's (`quantierra/infra` `terraform/envs/dev/loader.nix`) without
the hot standby: refreshes are run by hand.

## Layout

| Thing                                                     | Where                                 | Role                                                                           |
| --------------------------------------------------------- | ------------------------------------- | ------------------------------------------------------------------------------ |
| `storage-ssd`                                             | SanDisk Extreme Pro 4 TB (USB, UAS)   | zpool, lz4, ashift 12, autotrim; `hosts/hal9000/default.nix`                   |
| `storage-ssd/qre-devdb/base`                              | `/qre-devdb/base/pg17`                | pristine prod image, kept stopped; refreshed from S3                           |
| `storage-ssd/qre-devdb/dev`                               | `/qre-devdb/dev/pg17`                 | clone of `base@<ts>`, the dev database                                         |
| `qre-devdb.service`                                       | `:5433`, socket `/run/qre-devdb`      | dev PostgreSQL 17 (postgis, pg_cron, pg_partman, pg_repack)                    |
| `qre-devdb-base.service`                                  | `:5434`, socket `/run/qre-devdb-base` | started only by `qre-devdb-restore` to recover and promote base                |
| `storage-ssd-import.service`                              |                                       | imports the pool when the SSD is present (udev on hotplug), exports on stop    |
| `/etc/pgbackrest/pgbackrest.conf` + `conf.d/secrets.conf` |                                       | client config; secrets from agenix `hal9000/qre-devdb-pgbackrest.age`          |
| `/run/agenix/qre-devdb-env`                               |                                       | `DEVDB_PASSWORD`, the dev password sanitize sets (`hal9000/qre-devdb-env.age`) |

The pool and the datasets were created by hand (never by Nix):

```sh
zpool create -o ashift=12 -o autotrim=on -o cachefile=none \
  -O compression=lz4 -O atime=off -O xattr=sa -O acltype=posixacl \
  -O mountpoint=/mnt/storage-ssd storage-ssd \
  /dev/disk/by-id/usb-SanDisk_Extreme_Pro_55AF_323531364250343032313335-0:0
zfs create -o mountpoint=none storage-ssd/qre-devdb
zfs create -o recordsize=8K -o logbias=throughput -o mountpoint=/qre-devdb/base storage-ssd/qre-devdb/base
install -d -m 0700 -o postgres -g postgres /qre-devdb/base/pg17
```

## Commands (root)

| Command                                          | What it does                                                                                                         | Time                    |
| ------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------- | ----------------------- |
| `qre-devdb-status`                               | pool, datasets, units, dev origin and prod data age, DB sizes                                                        | instant                 |
| `qre-devdb-restore [--to-latest]`                | rebuild base from S3 (`--delta` over the previous copy), recover, promote, snapshot `base@<ts>`                      | hours: ~20 MB/s from S3 |
| `qre-devdb-refresh [--to-latest] [--reuse-base]` | restore, then drop dev (and its checkpoints), re-clone from the newest base snapshot, sanitize, snapshot `dev@fresh` | restore + minutes       |
| `qre-devdb-sanitize`                             | strip prod from dev (idempotent, re-runnable)                                                                        | minutes                 |
| `qre-devdb-checkpoint NAME`                      | ZFS snapshot of dev                                                                                                  | instant                 |
| `qre-devdb-rollback NAME`                        | back to a checkpoint (drops later ones)                                                                              | seconds                 |

`qre-devdb-restore` and `qre-devdb-refresh` run inside a transient systemd
unit of the same name, so a dropped SSH session does not kill them; follow
with `journalctl -fu qre-devdb-refresh`. Only one can run at a time.

Default restore point is the end of the newest backup (daily diff at 05:00
UTC, so at most a day old). `--to-latest` replays every archived WAL segment
after it (~30 GB compressed per day of WAL, slower).

`--reuse-base` re-clones dev from the base snapshot already on disk:
nothing from S3, a pristine dev in a few minutes.

## Connecting

```sh
# on hal9000, as jamesbrink or root (peer auth, no password)
psql -h /run/qre-devdb -p 5433 -U quantierra -d scipre_nyc_real_estate

# over TCP (LAN or Tailscale; scram-sha-256)
PGPASSWORD=$(sudo sed -n 's/^DEVDB_PASSWORD=//p' /run/agenix/qre-devdb-env) \
  psql -h hal9000 -p 5433 -U quantierra -d scipre_nyc_real_estate
```

`quantierra` is a superuser here (as on loader-dev). `report_reader`,
`matview_refresh`, `llm_ro` and `blazer_reader` take the same password;
every other prod login is disabled. Every app user's password is
`password`. The TCP firewall allows 5433; pg_hba limits it to the LAN and
the tailnet. hal9000's CI runners get no password, so they cannot reach it.

## What sanitize does

Renames `scipre-nyc-real-estate` to `scipre_nyc_real_estate`; NULLs every
login password except the app roles'; `ALTER SYSTEM RESET ALL` (prod's
16 GB `shared_buffers` and friends ride along in `postgresql.auto.conf`);
NULLs every `public.*_ciphertext` column (prod's Lockbox key is not here);
deletes OAuth tokens/grants and rotates OAuth app secrets; NULLs Crexi
`token_data`; resets every user's Devise password to `password`; caps the
AI budgets at $10/day and $1/email; sets `quantierra.devdb = hal9000` on
the database; removes prod's TLS certs from the data directory.

## Guards

- `archive_mode = off` on both instances: hal9000 holds read-only
  credentials for prod's repo and must never push WAL into it.
- `pg_cron` is installed but never preloaded: prod's jobs do not run here.
- Both postgres units start only when `PG_VERSION` exists and the dataset
  is a mount point: never an `initdb` onto the root filesystem.
- Prod's `postgresql.conf` in the data directory is ignored (`-c config_file`
  points at the Nix-generated one); memory is forced with `-c`, which beats
  prod's `postgresql.auto.conf` until sanitize resets it.
- The SSD is USB: if it is absent `storage-ssd-import.service` is skipped and
  the dev database stays off; plugging it in imports the pool and the database
  can be started. `systemctl stop storage-ssd-import` exports it before
  unplugging. Nothing else depends on it.

## First build (2026-11-05)

Initial restore of backup set `20261101-000001F_20261104-000001D` took
7 h 38 min (596 GB from S3 at ~20 MB/s), recovery to consistency 2.5 min,
promoted on timeline 2 with prod data as of 2026-11-04 05:34 UTC. Snapshot
`qre-devpool/base@20261104T0534Z-initial`, then `qre-devdb-refresh
--reuse-base` built dev. Pool usage 2.12 T at 1.45x compression.

## Moving it

`zfs send -R <pool>/base@<snap> | zfs receive -u -s <other>/base` moves the
copy to another disk without touching S3; point the module's `pool` at the new
prefix, deploy, then `qre-devdb-refresh --reuse-base` rebuilds dev there.

The first build lived in a file-backed zpool `qre-devpool`
(`/mnt/storage20tb/qre-devpool.img`, 5 T sparse, on the 20 TB USB HDD) and was
moved to the SSD this way on 2026-11-06 (2.12 T, ~4 h). The old pool is kept
exported as a cold fallback copy of `base@20261104T0534Z-initial`; import it with
`zpool import -N -d /mnt/storage20tb/qre-devpool.img qre-devpool`, or reclaim
the 2.12 T with `rm /mnt/storage20tb/qre-devpool.img`.
