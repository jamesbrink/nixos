{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.postgresql-replica;

  # WAL sync and management scripts package
  walSyncPackage = pkgs.callPackage ./wal-sync.nix {
    inherit (cfg)
      dataDir
      archiveDir
      awsProfile
      s3Bucket
      ;
    zfsDataset = cfg.zfsDataset;
    zfsBaseDataset = cfg.zfsBaseDataset;
    postgresqlPackage = cfg.package;
    serviceName = cfg.serviceName;
  };
in
{
  options.services.postgresql-replica = {
    enable = mkEnableOption "PostgreSQL 17 read replica from S3 WAL archive";

    package = mkOption {
      type = types.package;
      default = pkgs.postgresql_17.withPackages (ps: [ ps.postgis ]);
      description = "PostgreSQL package to use (includes PostGIS by default)";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/storage-fast/pg_base";
      description = "PostgreSQL data directory (ZFS dataset mount point)";
    };

    archiveDir = mkOption {
      type = types.path;
      default = "/storage-fast/pg_archive";
      description = "Directory for WAL archive files synced from S3";
    };

    zfsDataset = mkOption {
      type = types.str;
      default = "storage-fast/pg_base";
      description = "ZFS dataset for the PostgreSQL data directory";
    };

    zfsBaseDataset = mkOption {
      type = types.str;
      default = "storage-fast/pg_base";
      description = "ZFS dataset for base snapshots";
    };

    port = mkOption {
      type = types.port;
      default = 5439;
      description = "Port for the PostgreSQL replica to listen on";
    };

    awsProfile = mkOption {
      type = types.str;
      default = "quantierra";
      description = "AWS CLI profile to use for S3 access";
    };

    s3Bucket = mkOption {
      type = types.str;
      default = "s3://quantierra-backups/postgresql-archive/";
      description = "S3 bucket path for WAL archive";
    };

    walSyncSchedule = mkOption {
      type = types.str;
      default = "*-*-* 03:00:00";
      description = "Systemd calendar schedule for WAL sync";
    };

    snapshotSchedule = mkOption {
      type = types.str;
      default = "*-*-1,4,7,10,13,16,19,22,25,28,31 04:00:00";
      description = "Systemd calendar schedule for base snapshots (every 3 days)";
    };

    snapshotRetention = mkOption {
      type = types.int;
      default = 3;
      description = "Number of base snapshots to retain";
    };

    walRetentionDays = mkOption {
      type = types.int;
      default = 7;
      description = "Number of days of WAL files to retain locally";
    };

    serviceName = mkOption {
      type = types.str;
      default = "postgresql-replica";
      description = "Name of the systemd service";
    };

    postgresUser = mkOption {
      type = types.str;
      default = "postgres";
      description = "PostgreSQL superuser name";
    };

    postgresPassword = mkOption {
      type = types.str;
      default = "postgres";
      description = "PostgreSQL superuser password (for development use)";
    };

    enableWebhook = mkOption {
      type = types.bool;
      default = true;
      description = "Enable webhook handler for database reset operations";
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "Extra PostgreSQL configuration to append";
    };
  };

  config = mkIf cfg.enable {
    # Ensure directories exist with correct permissions
    systemd.tmpfiles.rules = [
      "d ${cfg.archiveDir} 0750 postgres postgres -"
      "d /run/postgresql 0755 postgres postgres -"
    ];

    # PostgreSQL configuration file
    environment.etc."postgresql-replica/postgresql.conf".text = ''
      # Connection settings
      listen_addresses = '*'
      port = ${toString cfg.port}
      max_connections = 500  # Must be >= primary server (400)

      # Performance settings for development on ZFS
      fsync = off
      synchronous_commit = off
      full_page_writes = off

      # Memory settings (for 64GB RAM systems)
      effective_cache_size = 48GB
      maintenance_work_mem = 16GB
      work_mem = 8GB
      temp_buffers = 1GB

      # Query planner settings for ZFS
      random_page_cost = 1.1
      effective_io_concurrency = 200

      # Parallel query settings
      max_parallel_workers_per_gather = 2
      max_parallel_maintenance_workers = 2
      parallel_leader_participation = on

      # Checkpoint and WAL settings
      checkpoint_timeout = '1h'
      max_wal_size = '32GB'
      min_wal_size = '16GB'
      checkpoint_completion_target = 0.9

      # WAL Recovery Settings (read replica mode)
      wal_level = replica
      archive_mode = off
      archive_command = '/bin/true'
      restore_command = '${pkgs.gzip}/bin/gunzip -c ${cfg.archiveDir}/%f.gz > %p'
      recovery_target_timeline = 'latest'

      # Logging configuration
      log_destination = 'stderr'
      logging_collector = on
      log_directory = 'log'
      log_filename = 'postgresql-%Y-%m-%d.log'
      log_rotation_age = 1d
      log_rotation_size = 100MB
      log_statement = 'ddl'
      log_min_duration_statement = 1000
      log_checkpoints = on
      log_connections = on
      log_disconnections = on
      log_lock_waits = on
      log_timezone = 'UTC'
      log_line_prefix = '%t [%p] %u@%d '

      ${cfg.extraConfig}
    '';

    environment.etc."postgresql-replica/pg_hba.conf".text = ''
      # TYPE  DATABASE        USER            ADDRESS                 METHOD
      local   all             all                                     trust
      host    all             all             127.0.0.1/32           trust
      host    all             all             ::1/128                trust
      host    all             all             0.0.0.0/0              md5
      host    all             all             ::/0                   md5
    '';

    # Create postgres user/group if not exists
    users.users.postgres = {
      isSystemUser = true;
      group = "postgres";
      uid = 71;
      description = "PostgreSQL server user";
      home = cfg.dataDir;
    };

    users.groups.postgres = {
      gid = 71;
    };

    # Main PostgreSQL replica service
    systemd.services.${cfg.serviceName} = {
      description = "PostgreSQL 17 Read Replica";
      after = [
        "network.target"
        "local-fs.target"
      ];
      wants = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      preStart = ''
        # Ensure data directory has correct ownership
        if [ -d "${cfg.dataDir}" ]; then
          chown -R postgres:postgres "${cfg.dataDir}"
          chmod 700 "${cfg.dataDir}"
        fi

        # Copy configuration files
        cp /etc/postgresql-replica/postgresql.conf "${cfg.dataDir}/postgresql.conf"
        cp /etc/postgresql-replica/pg_hba.conf "${cfg.dataDir}/pg_hba.conf"
        chown postgres:postgres "${cfg.dataDir}/postgresql.conf" "${cfg.dataDir}/pg_hba.conf"

        # Ensure standby.signal exists for replica mode
        if [ ! -f "${cfg.dataDir}/standby.signal" ]; then
          touch "${cfg.dataDir}/standby.signal"
          chown postgres:postgres "${cfg.dataDir}/standby.signal"
        fi

        # Remove backup_label if present (from pg_basebackup)
        if [ -f "${cfg.dataDir}/backup_label" ]; then
          rm -f "${cfg.dataDir}/backup_label"
        fi

        # Create log directory
        mkdir -p "${cfg.dataDir}/log"
        chown postgres:postgres "${cfg.dataDir}/log"
      '';

      serviceConfig = {
        Type = "notify";
        User = "postgres";
        Group = "postgres";
        ExecStart = "${cfg.package}/bin/postgres -D ${cfg.dataDir}";
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
        KillMode = "mixed";
        KillSignal = "SIGINT";
        TimeoutSec = 120;
        Restart = "on-failure";
        RestartSec = "10s";
        # preStart runs as root, needs write access to dataDir
        PermissionsStartOnly = true;
      };
    };

    # WAL sync service (syncs WAL files from S3)
    systemd.services.postgresql-replica-wal-sync = {
      description = "PostgreSQL Replica WAL Sync from S3";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      path = [
        pkgs.awscli2
        pkgs.gzip
        pkgs.coreutils
        pkgs.findutils
        pkgs.gnugrep
        pkgs.gawk
        cfg.package
      ];

      environment = {
        HOME = "/root";
        AWS_PROFILE = cfg.awsProfile;
      };

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = "${walSyncPackage}/bin/pg17-wal-sync";
        TimeoutSec = 3600;
      };
    };

    systemd.timers.postgresql-replica-wal-sync = {
      description = "PostgreSQL Replica WAL Sync Timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.walSyncSchedule;
        Persistent = true;
        RandomizedDelaySec = "30min";
      };
    };

    # WAL retention/cleanup service
    systemd.services.postgresql-replica-wal-retention = {
      description = "PostgreSQL Replica WAL Retention Cleanup";
      after = [ "postgresql-replica-wal-sync.service" ];

      path = [
        pkgs.coreutils
        pkgs.findutils
        pkgs.zfs
      ];

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = "${walSyncPackage}/bin/pg17-wal-retention";
      };
    };

    # Base snapshot service
    systemd.services.postgresql-replica-snapshot = {
      description = "PostgreSQL Replica Base Snapshot";
      after = [ "postgresql-replica-wal-sync.service" ];

      path = [
        pkgs.zfs
        pkgs.coreutils
        pkgs.gnugrep
        pkgs.gawk
        cfg.package
      ];

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = "${walSyncPackage}/bin/pg17-create-snapshot";
      };
    };

    systemd.timers.postgresql-replica-snapshot = {
      description = "PostgreSQL Replica Base Snapshot Timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.snapshotSchedule;
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };

    # Add management scripts to system packages
    environment.systemPackages = [
      walSyncPackage
    ];
  };
}
