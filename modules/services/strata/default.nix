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
  modelId = "orcarouter-qwen3.8-flash-next-uncensored-iq3_xxs";
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
      model_name = modelId;
      log = "${cfg.dataDir}/strata.log";
      host = "127.0.0.1";
      # llama-swap preserves the client Host header when proxying.
      allowed_hosts = cfg.allowedHosts;
      port = cfg.port;
    }
  );
  launcher = pkgs.writeShellApplication {
    name = "strata-orca-launch";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      config.hardware.nvidia.package
    ];
    text = ''
      available=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)
      if [ "$available" -lt 58720256 ]; then
        echo "Orca requires at least 56 GiB MemAvailable before startup; found $available KiB." >&2
        exit 1
      fi
      gpu_pids=$(nvidia-smi --query-compute-apps=pid --format=csv,noheader)
      if [ -n "$gpu_pids" ]; then
        echo "Refusing startup while another GPU compute process is resident: $gpu_pids" >&2
        exit 1
      fi
      test -s '${cfg.dataDir}/pack/native_experts.txt'
      test -s '${cfg.dataDir}/mtp/rt/draft_vocab.bin'
      test -s '${shard}'
      # exec preserves llama-swap's process group; the Strata engine inherits it.
      export LD_LIBRARY_PATH="/run/opengl-driver/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      exec ${package}/bin/strata-server --engine strata --config ${serverConfig} --host 127.0.0.1 --port ${toString cfg.port}
    '';
  };
in
{
  options.services.strata-orca = {
    enable = lib.mkEnableOption "on-demand Orca backend managed by llama-swap";
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/storage-fast/llm/strata-orca";
      description = "Mutable model, compatibility pack and MTP data directory";
    };
    allowedHosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "hal9000"
        "hal9000.home.urandom.io"
      ];
      description = "Trusted DNS names accepted from llama-swap's preserved Host header; IP and localhost are accepted upstream";
    };
    readinessTimeout = lib.mkOption {
      type = lib.types.ints.positive;
      default = 900;
      description = "Global llama-swap readiness timeout in seconds, including cold Strata loading";
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
    systemd.tmpfiles.rules = [ "d ${cfg.dataDir} 0770 strata-orca strata-orca -" ];
    environment.etc."strata-orca.json".source = serverConfig;
    services.llama-swap.settings.models.${modelId} = {
      cmd = "${launcher}/bin/strata-orca-launch";
      proxy = "http://127.0.0.1:${toString cfg.port}";
      checkEndpoint = "/health";
      ttl = 600;
      unloadTimeout = 75;
      concurrencyLimit = 64;
      useModelName = modelId;
    };
    # The existing default group swaps one resident model at a time. Strata is
    # eager inside that child: its HTTP listener appears only after model load.
    services.llama-swap.settings.healthCheckTimeout = lib.mkForce cfg.readinessTimeout;
    systemd.services.llama-swap.serviceConfig = {
      SupplementaryGroups = [ "strata-orca" ];
      # PrivateUsers remaps supplementary GIDs; use the host model-data group.
      PrivateUsers = lib.mkForce false;
      ReadWritePaths = [ cfg.dataDir ];
      LimitMEMLOCK = "infinity";
      TimeoutStopSec = 90;
    };
  };
}
