# Quantierra dev database on hal9000 (docs/qre-devdb.md): a copy of prod
# restored from prod's pgBackRest repository (S3, through a read-only IAM
# user) into a file-backed zpool on the 20 TB disk, served from a promoted
# ZFS clone on :5433. This is loader-dev's devpool/standby + devpool/dev
# workflow (quantierra/infra terraform/envs/dev/loader.nix) without the
# standby: refreshes are run by hand and pull a delta from S3.
#
#   qre-devpool          /mnt/storage20tb/qre-devpool.img (sparse image, 5 T)
#   qre-devpool/base     /qre-devdb/base/pg17: the pristine prod image, kept
#                        stopped; dev is cloned from its newest snapshot
#   qre-devpool/dev      /qre-devdb/dev/pg17: promoted clone of base@<ts>,
#                        the dev database (qre-devdb.service, :5433)
#
#   qre-devdb-status
#   qre-devdb-restore [--to-latest]      rebuild base from S3 (a delta over the
#                                        previous copy), recover, promote, snapshot
#   qre-devdb-refresh [--to-latest] [--reuse-base]
#                                        restore, then re-clone dev from the newest
#                                        base snapshot and sanitize it (drops dev
#                                        and all of its checkpoints)
#   qre-devdb-sanitize                   strip prod credentials and tuning from dev
#   qre-devdb-checkpoint NAME            ZFS snapshot of dev (instant)
#   qre-devdb-rollback NAME              back to it (drops later checkpoints)
#
# Guards: archive_mode=off on every instance (this host only ever holds
# read-only credentials for prod's repository and must never push WAL into
# it); pg_cron is never preloaded (prod's jobs must not run here); the
# postgres units only start on a data directory that has PG_VERSION (never
# initdb); the pool, its datasets and the image are created by hand, never
# by Nix.
{
  config,
  lib,
  pkgs,
  secretsPath,
  ...
}:
let
  pool = "qre-devpool";
  poolImage = "/mnt/storage20tb/qre-devpool.img";
  baseDir = "/qre-devdb/base/pg17";
  devDir = "/qre-devdb/dev/pg17";
  devPort = 5433;
  basePort = 5434;
  devSock = "/run/qre-devdb";
  baseSock = "/run/qre-devdb-base";
  envFile = config.age.secrets."qre-devdb-env".path;

  # Same major and extension set as prod (quantierra/infra
  # modules/services/database/postgresql.nix).
  pg = pkgs.postgresql_17.withPackages (
    ps: with ps; [
      postgis
      pg_cron
      pg_partman
      pg_repack
    ]
  );
  zfsPkg = config.boot.zfs.package;
  zfs = "${zfsPkg}/bin/zfs";
  zpool = "${zfsPkg}/bin/zpool";

  # Prod's postgresql.conf rides along in the restore (archive_command into
  # prod's repo, hba/ident/log/cert paths that do not exist here, pg_cron).
  # -c config_file replaces that file entirely. Prod's postgresql.auto.conf
  # (ALTER SYSTEM tuning: 16 GB shared_buffers) still applies on top of the
  # config file, so memory is set with -c on the command line, which beats
  # both; qre-devdb-sanitize's ALTER SYSTEM RESET ALL clears it on dev.
  commonConf = ''
    log_destination = 'stderr'
    logging_collector = off
    log_line_prefix = '[%p] %u@%d '
    log_checkpoints = on
    archive_mode = off
    hot_standby = on
    ssl = off
    huge_pages = off
    jit = off
    shared_preload_libraries = 'pg_stat_statements'
    # Recovery refuses to run below the primary's values (pg_control).
    max_connections = 400
    max_worker_processes = 16
    max_wal_senders = 10
    max_prepared_transactions = 0
    max_locks_per_transaction = 64
    max_wal_size = '16GB'
    min_wal_size = '1GB'
    checkpoint_timeout = '15min'
    checkpoint_completion_target = 0.9
    wal_compression = lz4
    recovery_prefetch = on
  '';
  devHba = pkgs.writeText "qre-devdb-hba.conf" ''
    # TYPE  DATABASE  USER                 ADDRESS              METHOD
    local   all       postgres,quantierra                       peer map=qre
    local   all       all                                       scram-sha-256
    host    all       all                  127.0.0.1/32         scram-sha-256
    host    all       all                  ::1/128              scram-sha-256
    host    all       all                  10.70.100.0/24       scram-sha-256
    host    all       all                  100.64.0.0/10        scram-sha-256
    host    all       all                  fd7a:115c:a1e0::/48  scram-sha-256
  '';
  devIdent = pkgs.writeText "qre-devdb-ident.conf" ''
    # MAP  SYSTEM-USER  PG-USER
    qre    postgres     postgres
    qre    root         postgres
    qre    jamesbrink   postgres
    qre    jamesbrink   quantierra
  '';
  devConf = pkgs.writeText "qre-devdb.conf" ''
    ${commonConf}
    cluster_name = 'qre-devdb'
    port = ${toString devPort}
    listen_addresses = '*'
    unix_socket_directories = '${devSock}'
    hba_file = '${devHba}'
    ident_file = '${devIdent}'
  '';
  # Prod's passwords are still in base: socket + peer as postgres only.
  baseHba = pkgs.writeText "qre-devdb-base-hba.conf" ''
    local   all   postgres   peer
  '';
  baseConf = pkgs.writeText "qre-devdb-base.conf" ''
    ${commonConf}
    cluster_name = 'qre-devdb-base'
    port = ${toString basePort}
    listen_addresses = '''
    unix_socket_directories = '${baseSock}'
    hba_file = '${baseHba}'
  '';
  postgresCmd =
    dir: conf: settings:
    lib.concatStringsSep " " (
      [
        "${pg}/bin/postgres"
        "-D"
        dir
        "-c"
        "config_file=${conf}"
      ]
      ++ map (s: "-c ${s}") settings
    );
  # Sized for a 62 GiB box that also runs mold, Strata and the other
  # PostgreSQL; the 20 TB disk behind the pool is a USB HDD.
  devSettings = [
    "shared_buffers=4GB"
    "effective_cache_size=12GB"
    "work_mem=32MB"
    "maintenance_work_mem=1GB"
    "max_parallel_workers=8"
    "max_parallel_workers_per_gather=2"
    "max_parallel_maintenance_workers=2"
  ];
  baseSettings = [
    "shared_buffers=2GB"
    "effective_cache_size=8GB"
    "work_mem=16MB"
    "maintenance_work_mem=512MB"
  ];

  psqlDev = "runuser -u postgres -- ${pg}/bin/psql -X -h ${devSock} -p ${toString devPort}";
  psqlBase = "runuser -u postgres -- ${pg}/bin/psql -X -h ${baseSock} -p ${toString basePort}";
  commonInputs = [
    zfsPkg
    pkgs.util-linux
    pkgs.systemd
    pkgs.coreutils
  ];

  # Long operations run inside a transient unit so a dropped SSH session
  # cannot kill a multi-hour restore; the caller follows the journal and
  # gets the unit's exit status.
  inUnit = unit: ''
    if [ -z "''${QRE_DEVDB_INNER:-}" ]; then
      if systemctl is-active -q ${unit}; then
        echo "${unit} is already running (journalctl -fu ${unit})" >&2
        exit 1
      fi
      echo "running as ${unit}.service; it survives this shell (journalctl -fu ${unit})"
      # runuser's pam lines are noise.
      journalctl -f -u ${unit} -o cat --since "@$(date +%s)" | grep --line-buffered -v pam_unix &
      jpid=$!
      rc=0
      systemd-run --unit ${unit} --wait --collect -q -E QRE_DEVDB_INNER=1 \
        -p Type=exec -p TimeoutStartSec=infinity \
        -p StandardOutput=journal -p StandardError=journal \
        "$0" "$@" || rc=$?
      sleep 1
      kill "$jpid" 2>/dev/null || true
      exit "$rc"
    fi
  '';

  statusTool = pkgs.writeShellApplication {
    name = "qre-devdb-status";
    runtimeInputs = commonInputs;
    text = ''
      echo "== pool"
      zpool list -o name,size,alloc,free,health ${pool} 2>/dev/null || echo "${pool} is not imported"
      df -h ${dirOf poolImage} | tail -n 1
      echo "== datasets"
      zfs list -t all -r -o name,used,refer,creation,qre:prod_as_of ${pool} 2>/dev/null || true
      echo "== units"
      for u in qre-devpool-import qre-devdb qre-devdb-base qre-devdb-restore qre-devdb-refresh; do
        printf '%-20s %s\n' "$u" "$(systemctl is-active "$u" 2>/dev/null || true)"
      done
      echo "== dev"
      origin=$(zfs get -H -o value origin ${pool}/dev 2>/dev/null || true)
      if [ -n "$origin" ] && [ "$origin" != - ]; then
        echo "origin: $origin (prod data as of $(zfs get -H -o value qre:prod_as_of "$origin"))"
      else
        echo "no ${pool}/dev yet: qre-devdb-refresh --reuse-base"
      fi
      if systemctl is-active -q qre-devdb; then
        ${psqlDev} -d postgres -c "select datname, pg_size_pretty(pg_database_size(datname)) as size
          from pg_database where not datistemplate order by pg_database_size(datname) desc"
        ${psqlDev} -At -d postgres -c "select 'clients: ' || count(*) from pg_stat_activity where backend_type = 'client backend'"
        ${psqlDev} -At -d postgres -c "select 'sanitized: ' || (count(*) > 0) from pg_db_role_setting
          where 'quantierra.devdb=hal9000' = any(setconfig)"
        echo "connect: psql -h ${devSock} -p ${toString devPort} -U quantierra -d scipre_nyc_real_estate"
        echo "         (peer as jamesbrink/root; TCP needs the password in ${envFile})"
      fi
    '';
  };

  restoreTool = pkgs.writeShellApplication {
    name = "qre-devdb-restore";
    runtimeInputs = [ pkgs.pgbackrest ] ++ commonInputs;
    text = ''
      ${inUnit "qre-devdb-restore"}
      type=immediate
      for a in "$@"; do
        case "$a" in
          --to-latest) type=default ;; # replay every archived WAL segment, not just to the backup's end
          *)
            echo "usage: qre-devdb-restore [--to-latest]" >&2
            exit 2
            ;;
        esac
      done
      [ "$(zfs get -H -o value mounted ${pool}/base)" = yes ] || {
        echo "${pool}/base is not mounted" >&2
        exit 1
      }
      systemctl stop qre-devdb-base
      install -d -m 0700 -o postgres -g postgres ${baseDir}
      args=(--stanza=default --pg1-path=${baseDir} --type="$type")
      if [ -e ${baseDir}/PG_VERSION ]; then
        args+=(--delta) # over the previous copy: only changed files are fetched
      fi
      if [ "$type" = immediate ]; then
        args+=(--target-action=promote)
      fi
      echo "restore: pgbackrest ''${args[*]} restore"
      runuser -u postgres -- pgbackrest "''${args[@]}" restore
      rm -f ${baseDir}/postmaster.pid

      echo "recovering to consistency and promoting (qre-devdb-base.service, port ${toString basePort})"
      systemctl start qre-devdb-base
      systemctl is-active -q qre-devdb-base || {
        echo "qre-devdb-base did not start (journalctl -u qre-devdb-base)" >&2
        exit 1
      }
      while [ "$(${psqlBase} -At -d postgres -c 'select pg_is_in_recovery()')" = t ]; do
        sleep 15
      done
      asof=$(${psqlBase} -At -d postgres -c "select coalesce(pg_last_xact_replay_timestamp()::text, 'unknown')")
      ${psqlBase} -At -d postgres -c checkpoint >/dev/null
      systemctl stop qre-devdb-base
      snap="${pool}/base@$(date -u +%Y%m%dT%H%M%SZ)"
      zfs snapshot "$snap"
      zfs set "qre:prod_as_of=$asof" "$snap"
      echo "base restored: $snap (prod data as of $asof)"
    '';
  };

  # Strip prod from the copy: every login password except the app roles'
  # (those get the dev password), prod's ALTER SYSTEM tuning, Lockbox
  # ciphertexts dev's key cannot decrypt, OAuth/Crexi tokens, the users'
  # passwords (the shared dev login), prod's AI budgets, prod's TLS certs.
  # Idempotent; runs after every refresh and can be re-run by hand.
  sanitizeTool = pkgs.writeShellApplication {
    name = "qre-devdb-sanitize";
    runtimeInputs = commonInputs ++ [ pkgs.gnused ];
    text = ''
      systemctl is-active -q qre-devdb || {
        echo "qre-devdb is not running" >&2
        exit 1
      }
      pw=$(sed -n 's/^DEVDB_PASSWORD=//p' ${envFile})
      [ -n "$pw" ] || {
        echo "no DEVDB_PASSWORD in ${envFile}" >&2
        exit 1
      }
      psqlx() { ${psqlDev} -v ON_ERROR_STOP=1 "$@"; }
      # Prod's hyphenated name -> the name dev tooling expects.
      if [ "$(psqlx -At -d postgres -c "select count(*) from pg_database where datname = 'scipre-nyc-real-estate'")" = 1 ]; then
        psqlx -d postgres -c 'alter database "scipre-nyc-real-estate" rename to scipre_nyc_real_estate'
      fi
      psqlx -d postgres -v pw="$pw" <<'SQL'
      DO $$
      DECLARE r record;
      BEGIN
        FOR r IN SELECT rolname FROM pg_authid
                 WHERE rolpassword IS NOT NULL
                   AND rolname NOT IN ('quantierra', 'report_reader',
                     'matview_refresh', 'llm_ro', 'blazer_reader') LOOP
          EXECUTE format('ALTER ROLE %I PASSWORD NULL', r.rolname);
        END LOOP;
      END $$;
      ALTER ROLE quantierra WITH LOGIN SUPERUSER PASSWORD :'pw';
      -- App roles the Rails app connects as (Report Builder, Blazer, matview
      -- refresh, LLM read-only): same dev credential, prod privileges unchanged.
      ALTER ROLE report_reader WITH LOGIN PASSWORD :'pw';
      ALTER ROLE matview_refresh WITH LOGIN PASSWORD :'pw';
      ALTER ROLE llm_ro WITH LOGIN PASSWORD :'pw';
      ALTER ROLE blazer_reader WITH LOGIN PASSWORD :'pw';
      ALTER SYSTEM RESET ALL;
      SQL
      psqlx -d scipre_nyc_real_estate <<'SQL'
      SET lock_timeout = '10s';
      -- Prod's Lockbox ciphertexts cannot be decrypted with dev's key and any
      -- read raises: NULL every public.*_ciphertext column, keep the rows.
      DO $$
      DECLARE r record; n bigint;
      BEGIN
        IF to_regclass('public.llm_credentials') IS NOT NULL THEN
          UPDATE llm_credentials SET status = 'disconnected', login_state = '{}'::jsonb
           WHERE auth_json_ciphertext IS NOT NULL OR api_key_ciphertext IS NOT NULL;
        END IF;
        FOR r IN SELECT c.table_name, c.column_name, c.is_nullable
                   FROM information_schema.columns c
                   JOIN information_schema.tables t USING (table_schema, table_name)
                  WHERE c.table_schema = 'public' AND t.table_type = 'BASE TABLE'
                    AND c.column_name LIKE '%\_ciphertext'
                  ORDER BY 1, 2 LOOP
          IF r.is_nullable = 'NO' THEN
            RAISE WARNING 'skipped NOT NULL %.%', r.table_name, r.column_name;
            CONTINUE;
          END IF;
          EXECUTE format('UPDATE public.%I SET %I = NULL WHERE %I IS NOT NULL',
                         r.table_name, r.column_name, r.column_name);
          GET DIAGNOSTICS n = ROW_COUNT;
          RAISE NOTICE '%.%: % cleared', r.table_name, r.column_name, n;
        END LOOP;
      END $$;
      -- Data a dev app pointed here must not honor (loader-dev's
      -- devdb-app-sanitize): prod's plaintext OAuth bearer tokens and app
      -- secrets, Crexi auth tokens; every user gets the shared dev login.
      DO $$
      DECLARE r record;
      BEGIN
        IF to_regclass('public.oauth_access_tokens') IS NOT NULL THEN
          DELETE FROM oauth_access_tokens;
        END IF;
        IF to_regclass('public.oauth_access_grants') IS NOT NULL THEN
          DELETE FROM oauth_access_grants;
        END IF;
        IF to_regclass('public.oauth_applications') IS NOT NULL THEN
          UPDATE oauth_applications SET secret = md5(random()::text) || md5(random()::text);
        END IF;
        IF to_regclass('public.crexi_account_registrations') IS NOT NULL THEN
          UPDATE crexi_account_registrations SET token_data = NULL WHERE token_data IS NOT NULL;
        END IF;
        IF to_regclass('public.users') IS NOT NULL THEN
          UPDATE users
             SET encrypted_password = '$2a$10$XOlfyH2srqjLIJyDr5yOE.gLupq.YB7b7MORmrNSieQLo3VU1NDu.', -- gitleaks:allow (Devise bcrypt of the word password)
                 failed_attempts = 0, locked_at = NULL, unlock_token = NULL,
                 reset_password_token = NULL, reset_password_sent_at = NULL -- gitleaks:allow
           WHERE encrypted_password IS DISTINCT FROM '$2a$10$XOlfyH2srqjLIJyDr5yOE.gLupq.YB7b7MORmrNSieQLo3VU1NDu.' -- gitleaks:allow
              OR failed_attempts <> 0 OR locked_at IS NOT NULL;
        END IF;
        -- AI spend cap: a prod copy carries prod's budgets; cap dev at $10/day
        -- and $1 per email (loader-dev fails here when the columns change;
        -- nothing runs agents on this host unattended, so warn instead).
        IF to_regclass('public.dealflow_agent_settings') IS NOT NULL
           AND (SELECT count(*) FROM information_schema.columns
                 WHERE table_schema = 'public' AND table_name = 'dealflow_agent_settings'
                   AND column_name IN ('daily_budget_usd', 'chat_daily_budget_usd',
                                       'contacts_assessment_daily_usd_cap', 'max_budget_usd_per_email')) = 4 THEN
          UPDATE dealflow_agent_settings
             SET daily_budget_usd = 10.00,
                 chat_daily_budget_usd = NULL,
                 contacts_assessment_daily_usd_cap = 10.0000,
                 max_budget_usd_per_email = LEAST(max_budget_usd_per_email, 1.00);
          FOR r IN SELECT id, daily_budget_usd, contacts_assessment_daily_usd_cap, max_budget_usd_per_email
                     FROM dealflow_agent_settings LOOP
            RAISE NOTICE 'ai-spend-cap: settings % daily=% contacts=% per_email=%',
              r.id, r.daily_budget_usd, r.contacts_assessment_daily_usd_cap, r.max_budget_usd_per_email;
          END LOOP;
        ELSE
          RAISE WARNING 'dealflow_agent_settings budget columns not found; AI spend cap not applied';
        END IF;
        -- Marker: this is a dev copy (the app's boot guard; prod never has it).
        EXECUTE format('ALTER DATABASE %I SET quantierra.devdb = %L', current_database(), 'hal9000');
      END $$;
      SQL
      # Prod's TLS material and the postgres home-dir leftovers that rode along.
      rm -rf ${devDir}/certs ${devDir}/certs.* ${devDir}/.aws
      # Pick up the reset (prod's shared_buffers etc.): reload, then restart
      # only if a restart-only setting changed.
      psqlx -At -d postgres -c 'select pg_reload_conf()' >/dev/null
      sleep 2
      if [ -n "$(psqlx -At -d postgres -c "select string_agg(name, ',') from pg_settings where pending_restart")" ]; then
        systemctl restart qre-devdb
      fi
      echo "dev sanitized"
    '';
  };

  refreshTool = pkgs.writeShellApplication {
    name = "qre-devdb-refresh";
    runtimeInputs = commonInputs;
    text = ''
      ${inUnit "qre-devdb-refresh"}
      reuse=""
      restore=()
      for a in "$@"; do
        case "$a" in
          --reuse-base) reuse=1 ;; # re-clone from the newest base snapshot; nothing from S3
          --to-latest) restore+=(--to-latest) ;;
          *)
            echo "usage: qre-devdb-refresh [--to-latest] [--reuse-base]" >&2
            exit 2
            ;;
        esac
      done
      if [ -z "$reuse" ]; then
        QRE_DEVDB_INNER=1 ${restoreTool}/bin/qre-devdb-restore "''${restore[@]}"
      fi
      snap=$(zfs list -H -t snapshot -o name -s createtxg ${pool}/base | tail -n 1)
      [ -n "$snap" ] || {
        echo "no ${pool}/base snapshot: run qre-devdb-restore first" >&2
        exit 1
      }
      systemctl stop qre-devdb
      if zfs list -H ${pool}/dev >/dev/null 2>&1; then
        checkpoints=$(zfs list -H -t snapshot -o name ${pool}/dev)
        [ -z "$checkpoints" ] || printf 'destroying dev checkpoints:\n%s\n' "$checkpoints"
        zfs destroy -r ${pool}/dev
      fi
      zfs clone -o mountpoint=${dirOf devDir} "$snap" ${pool}/dev
      rm -f ${devDir}/postmaster.pid ${devDir}/recovery.signal ${devDir}/standby.signal
      systemctl start qre-devdb
      systemctl is-active -q qre-devdb || {
        echo "qre-devdb did not start (journalctl -u qre-devdb)" >&2
        exit 1
      }
      ${sanitizeTool}/bin/qre-devdb-sanitize
      ${psqlDev} -At -d postgres -c checkpoint >/dev/null
      zfs snapshot ${pool}/dev@fresh
      # Older base snapshots are no longer clone origins.
      zfs list -H -t snapshot -o name ${pool}/base | while read -r s; do
        [ "$s" = "$snap" ] || zfs destroy "$s"
      done
      echo "dev refreshed from $snap (prod data as of $(zfs get -H -o value qre:prod_as_of "$snap"))"
    '';
  };

  checkpointTool = pkgs.writeShellApplication {
    name = "qre-devdb-checkpoint";
    runtimeInputs = commonInputs;
    text = ''
      name=''${1:?usage: qre-devdb-checkpoint NAME}
      ${psqlDev} -At -d postgres -c checkpoint >/dev/null
      zfs snapshot "${pool}/dev@$name"
      zfs list -t snapshot -o name,creation,used -s createtxg ${pool}/dev
    '';
  };

  rollbackTool = pkgs.writeShellApplication {
    name = "qre-devdb-rollback";
    runtimeInputs = commonInputs ++ [ pkgs.gnused ];
    text = ''
      name=''${1:?usage: qre-devdb-rollback NAME (qre-devdb-status lists them)}
      zfs list -H -t snapshot "${pool}/dev@$name" >/dev/null
      later=$(zfs list -H -t snapshot -o name -s createtxg ${pool}/dev \
        | sed -n "\|^${pool}/dev@$name\$|,\$p" | tail -n +2)
      [ -z "$later" ] || printf 'destroying later checkpoints:\n%s\n' "$later"
      systemctl stop qre-devdb
      zfs rollback -r "${pool}/dev@$name"
      rm -f ${devDir}/postmaster.pid
      systemctl start qre-devdb
      echo "dev rolled back to $name"
    '';
  };
in
{
  environment.systemPackages = [
    pkgs.pgbackrest
    statusTool
    restoreTool
    refreshTool
    sanitizeTool
    checkpointTool
    rollbackTool
  ];

  # Non-secret half of the pgBackRest client config; the S3 key and the
  # repository cipher passphrase are the agenix secret below, which
  # pgbackrest picks up from conf.d. Only restore/archive-get are ever run.
  environment.etc."pgbackrest/pgbackrest.conf".text = ''
    [global]
    repo1-type=s3
    repo1-path=/pgbackrest
    repo1-s3-bucket=quantierra-backups
    repo1-s3-region=us-east-1
    repo1-s3-endpoint=s3.amazonaws.com
    repo1-s3-key-type=shared
    repo1-cipher-type=aes-256-cbc
    lock-path=/run/pgbackrest
    spool-path=/var/spool/pgbackrest
    log-path=/var/log/pgbackrest
    log-level-file=info
    log-level-console=info
    archive-async=n

    [global:restore]
    process-max=4

    [global:archive-get]
    archive-async=y
    process-max=4

    [default]
    pg1-path=${baseDir}
    pg1-socket-path=${baseSock}
  '';

  age.secrets = {
    # repo1-s3-key, repo1-s3-key-secret (IAM user hal9000-pgbackrest-ro,
    # read-only on the pgbackrest/ prefix; quantierra/infra
    # terraform/envs/dev/iam.tf) and repo1-cipher-pass.
    "qre-devdb-pgbackrest" = {
      file = "${secretsPath}/hal9000/qre-devdb-pgbackrest.age";
      path = "/etc/pgbackrest/conf.d/secrets.conf";
      symlink = false;
      owner = "postgres";
      group = "postgres";
      mode = "0400";
    };
    # DEVDB_PASSWORD=...: the dev password qre-devdb-sanitize sets on
    # quantierra and the app roles.
    "qre-devdb-env" = {
      file = "${secretsPath}/hal9000/qre-devdb-env.age";
      owner = "root";
      group = "root";
      mode = "0400";
    };
  };

  systemd.tmpfiles.rules = [
    "d /qre-devdb 0755 root root -"
    "d /var/log/pgbackrest 0750 postgres postgres -"
    "d /var/spool/pgbackrest 0750 postgres postgres -"
    "d /run/pgbackrest 0750 postgres postgres -"
  ];

  networking.firewall.allowedTCPPorts = [ devPort ];

  # The pool lives in a file on the USB-attached 20 TB disk, so NixOS's
  # by-name import (boot.zfs.extraPools scans /dev/disk/by-id) cannot find
  # it; import it after the disk is mounted, export it before the disk goes
  # away. A missing disk or image just leaves the dev database off.
  systemd.services.qre-devpool-import = {
    description = "Import ${pool} (file-backed zpool on the 20 TB disk) and mount its datasets";
    wantedBy = [ "multi-user.target" ];
    after = [
      "zfs-import.target"
      "zfs-mount.service"
    ];
    unitConfig = {
      RequiresMountsFor = [ (dirOf poolImage) ];
      ConditionPathExists = poolImage;
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "-${zpool} export ${pool}";
    };
    script = ''
      if ! ${zpool} list -H ${pool} >/dev/null 2>&1; then
        ${zpool} import -N -d ${poolImage} ${pool}
      fi
      ${zfs} list -H -r -t filesystem -o name,mountpoint,canmount,mounted ${pool} \
        | while read -r name mountpoint canmount mounted; do
            if [ "$canmount" = on ] && [ "$mounted" = no ] \
              && [ "$mountpoint" != none ] && [ "$mountpoint" != legacy ]; then
              ${zfs} mount "$name"
            fi
          done
    '';
  };

  systemd.services.qre-devdb = {
    description = "Quantierra dev database (prod copy on ${pool}/dev, port ${toString devPort})";
    wantedBy = [ "multi-user.target" ];
    requires = [ "qre-devpool-import.service" ];
    after = [
      "qre-devpool-import.service"
      "network.target"
    ];
    unitConfig = {
      # Never initdb: only start on a cloned data directory.
      ConditionPathExists = "${devDir}/PG_VERSION";
      AssertPathIsMountPoint = dirOf devDir;
    };
    serviceConfig = {
      Type = "notify";
      User = "postgres";
      Group = "postgres";
      RuntimeDirectory = "qre-devdb";
      RuntimeDirectoryMode = "0755";
      ExecStart = postgresCmd devDir devConf devSettings;
      KillSignal = "SIGINT"; # fast shutdown
      TimeoutStartSec = "infinity";
      TimeoutStopSec = 600;
    };
  };

  # The pristine copy, started only by qre-devdb-restore: replays the WAL
  # the restore asked for, promotes, gets snapshotted, stops.
  systemd.services.qre-devdb-base = {
    description = "Quantierra dev database base copy (${pool}/base, recovery only, port ${toString basePort})";
    requires = [ "qre-devpool-import.service" ];
    after = [
      "qre-devpool-import.service"
      "network.target"
    ];
    unitConfig = {
      ConditionPathExists = "${baseDir}/PG_VERSION";
      AssertPathIsMountPoint = dirOf baseDir;
    };
    # restore_command (pgbackrest archive-get) runs while it recovers.
    path = [ pkgs.pgbackrest ];
    serviceConfig = {
      Type = "notify";
      User = "postgres";
      Group = "postgres";
      RuntimeDirectory = "qre-devdb-base";
      RuntimeDirectoryMode = "0755";
      ExecStart = postgresCmd baseDir baseConf baseSettings;
      KillSignal = "SIGINT";
      TimeoutStartSec = "infinity"; # --to-latest can replay days of WAL
      TimeoutStopSec = 600;
    };
  };
}
