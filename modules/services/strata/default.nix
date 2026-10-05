{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.strata-orca;
  package = pkgs.callPackage ../../../pkgs/strata.nix { };
  shard = "${cfg.dataDir}/models/Qwen3.8-Flash-Next-Uncensored-IQ3_XXS-00001-of-00002.gguf";
  serverConfig = pkgs.writeText "strata-orca.json" (
    builtins.toJSON {
      exe = "${package}/bin/strata";
      args = [
        "--pack"
        "${cfg.dataDir}/pack"
        "--native"
        shard
        "--ple-gguf"
        shard
        "--expert-profile"
        "${package}/share/strata/data/expert-profile.bin"
        "--expert-cache"
        "auto"
        "--prefill"
        "512"
        "--spec"
        "4"
        "--spec-min-p"
        "0.5"
        "--mtp"
        "${cfg.dataDir}/mtp/rt"
        "--max-context"
        "32768"
        "--kv"
        "int8"
      ];
      cwd = cfg.dataDir;
      tokenizer = "${cfg.dataDir}/pack/tokenizer";
      model_name = "orcarouter-qwen3.8-flash-next-uncensored-iq3_xxs";
      log = "${cfg.dataDir}/strata.log";
      host = "127.0.0.1";
      port = cfg.port;
    }
  );
in
{
  options.services.strata-orca = {
    enable = lib.mkEnableOption "manually started, loopback-only Orca Strata backend";
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/storage-fast/llm/strata-orca";
      description = "Mutable model, compatibility pack and MTP data directory";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 8081;
      description = "Loopback API port; separate from llama-swap on 8080";
    };
  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ package ];
    users.groups.strata-orca = { };
    users.users.strata-orca = {
      isSystemUser = true;
      group = "strata-orca";
      extraGroups = [
        "video"
        "render"
      ];
    };
    systemd.tmpfiles.rules = [ "d ${cfg.dataDir} 0750 strata-orca strata-orca -" ];
    environment.etc."strata-orca.json".source = serverConfig;
    # Intentionally no wantedBy: activation installs the unit but never starts it.
    # It is not registered in llama-swap: a request must not evict production LLMs.
    systemd.services.strata-orca = {
      description = "Orca Flash Next IQ3_XXS (manual experiment, no automatic startup)";
      after = [ "network.target" ];
      path = [
        pkgs.coreutils
        pkgs.gawk
        pkgs.systemd
        config.hardware.nvidia.package
      ];
      environment.LD_LIBRARY_PATH = "/run/opengl-driver/lib";
      preStart = ''
        for service in llama-swap ollama mold comfyui invokeai; do
          if systemctl is-active --quiet "$service.service"; then
            echo "Refusing to compete with active $service; arrange a maintenance window first." >&2
            exit 1
          fi
        done
        available=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)
        if [ "$available" -lt 58720256 ]; then
          echo "Orca requires at least 56 GiB MemAvailable before startup; found $available KiB." >&2
          exit 1
        fi
        if [ -n "$(nvidia-smi --query-compute-apps=pid --format=csv,noheader)" ]; then
          echo "Refusing startup while another GPU compute process is resident." >&2
          exit 1
        fi
        test -s '${cfg.dataDir}/pack/native_experts.txt'
        test -s '${cfg.dataDir}/mtp/rt/draft_vocab.bin'
        test -s '${shard}'
      '';
      serviceConfig = {
        Type = "simple";
        User = "strata-orca";
        Group = "strata-orca";
        WorkingDirectory = cfg.dataDir;
        ExecStart = "${package}/bin/strata-server --engine strata --config ${serverConfig} --host 127.0.0.1 --port ${toString cfg.port}";
        Restart = "no";
        LimitMEMLOCK = "infinity";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.dataDir ];
        UMask = "0027";
      };
    };
  };
}
