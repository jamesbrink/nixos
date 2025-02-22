{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.ai-starter-kit;
in
{
  options.services.ai-starter-kit = {
    enable = mkEnableOption "AI Starter Kit";

    storagePath = mkOption {
      type = types.str;
      description = "Base path for all persistent storage";
      example = "/mnt/storage-fast/n8n";
    };

    n8n = {
      enable = mkEnableOption "n8n workflow automation";
      port = mkOption {
        type = types.port;
        default = 5678;
        description = "Port for n8n web interface";
      };
      backupPath = mkOption {
        type = types.str;
        default = "${cfg.storagePath}/backup";
        description = "Path for n8n backup files";
      };
    };

    qdrant = {
      enable = mkEnableOption "Qdrant vector database";
      port = mkOption {
        type = types.port;
        default = 6333;
        description = "Port for Qdrant API";
      };
    };

    postgres = {
      user = mkOption {
        type = types.str;
        default = "n8n";
        description = "PostgreSQL user for n8n";
      };
      password = mkOption {
        type = types.str;
        default = "n8n";
        description = "PostgreSQL password for n8n";
      };
      database = mkOption {
        type = types.str;
        default = "n8n";
        description = "PostgreSQL database name for n8n";
      };
    };
  };

  config = mkIf cfg.enable {
    # Create required directories
    systemd.tmpfiles.rules = [
      "d ${cfg.storagePath}/postgres 0755 root root"
      "d ${cfg.storagePath}/n8n 0755 root root"
      "d ${cfg.storagePath}/qdrant 0755 root root"
      "d ${cfg.storagePath}/backup 0755 root root"
    ];

    # Create the network before containers start
    systemd.services.create-ai-starter-network = {
      description = "Create AI Starter Kit podman network";
      path = [ pkgs.podman ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.bash}/bin/bash -c 'podman network exists ai-starter || podman network create ai-starter'";
      };
      restartIfChanged = false;
      wantedBy = [ "multi-user.target" ];
      before = [
        "podman-postgres.service"
        "podman-n8n.service"
        "podman-qdrant.service"
      ];
      conflicts = [ "shutdown.target" ];
      partOf = [
        "podman-postgres.service"
        "podman-n8n.service"
        "podman-qdrant.service"
      ];
    };

    virtualisation.oci-containers.containers = {
      postgres = {
        image = "docker.io/postgres:16-alpine";
        autoStart = true;
        environment = {
          POSTGRES_USER = cfg.postgres.user;
          POSTGRES_PASSWORD = cfg.postgres.password;
          POSTGRES_DB = cfg.postgres.database;
        };
        volumes = [
          "${cfg.storagePath}/postgres:/var/lib/postgresql/data"
        ];
        extraOptions = [
          "--network=ai-starter"
        ];
      };

      n8n = {
        image = "docker.io/n8nio/n8n:latest";
        autoStart = true;
        environment = {
          DB_TYPE = "postgresdb";
          DB_POSTGRESDB_HOST = "postgres";
          DB_POSTGRESDB_USER = cfg.postgres.user;
          DB_POSTGRESDB_PASSWORD = cfg.postgres.password;
          DB_POSTGRESDB_DATABASE = cfg.postgres.database;
          OLLAMA_HOST = "host.containers.internal:11434";
          N8N_DIAGNOSTICS_ENABLED = "false";
          N8N_PERSONALIZATION_ENABLED = "false";
        };
        volumes = [
          "${cfg.storagePath}/n8n:/home/node/.n8n"
          "${cfg.n8n.backupPath}:/backup"
        ];
        ports = [
          "${toString cfg.n8n.port}:5678"
        ];
        extraOptions = [
          "--network=ai-starter"
        ];
      };

      qdrant = mkIf cfg.qdrant.enable {
        image = "docker.io/qdrant/qdrant";
        autoStart = true;
        volumes = [
          "${cfg.storagePath}/qdrant:/qdrant/storage"
        ];
        ports = [
          "${toString cfg.qdrant.port}:6333"
        ];
        extraOptions = [
          "--network=ai-starter"
        ];
      };
    };
  };
}
