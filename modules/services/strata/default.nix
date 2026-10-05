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
  bounded = cfg.memoryMode == "bounded-mmap";
  minimumAvailableGiB = if bounded then cfg.residentBudgetGiB + cfg.residentHeadroomGiB + 4 else 56;
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
        (toString cfg.prefillTokens)
        "--spec"
        (toString cfg.specWindow)
        "--spec-min-p"
        "0.5"
        "--mtp"
        "${cfg.dataDir}/mtp/rt"
        "--max-context"
        (toString cfg.contextTokens)
        "--mtp-window"
        (toString (lib.min cfg.contextTokens cfg.mtpWindowTokens))
        "--mtp-max-t"
        (toString cfg.mtpMaxT)
        "--suffix-draft"
        (toString cfg.suffixDraft)
        "--pool-affinity"
        cfg.poolAffinity
        "--vram-reserve-mib"
        (toString cfg.vramReserveMiB)
        "--kv"
        cfg.kvType
      ]
      ++ lib.optionals (cfg.poolWorkers != null) [
        "--pool-workers"
        (toString cfg.poolWorkers)
      ]
      ++ lib.optionals (cfg.pcieFraction != null) [
        "--pcie-frac"
        (toString cfg.pcieFraction)
      ]
      ++ lib.optionals bounded [
        "--mmap-experts"
        "--resident-budget-gib"
        (toString cfg.residentBudgetGiB)
      ];
      allowed_desktop_compute_processes = cfg.allowedDesktopComputeProcesses;
      maximum_desktop_compute_mib = cfg.maximumDesktopComputeMiB;
      minimum_free_vram_mib = cfg.minimumFreeVRAMMiB;
      memory_mode = cfg.memoryMode;
      resident_budget_gib = if bounded then cfg.residentBudgetGiB else null;
      resident_headroom_gib = if bounded then cfg.residentHeadroomGiB else null;
      minimum_available_gib = minimumAvailableGiB;
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
      if [ "$available" -lt ${toString (minimumAvailableGiB * 1048576)} ]; then
        echo "Orca ${cfg.memoryMode} requires at least ${toString minimumAvailableGiB} GiB MemAvailable before startup; found $available KiB." >&2
        exit 1
      fi
      ${pkgs.python3}/bin/python3 ${../../../scripts/strata-gpu-guard.py} --config ${serverConfig} --nvidia-smi ${lib.getBin config.hardware.nvidia.package}/bin/nvidia-smi
      test -s '${cfg.dataDir}/pack/native_experts.txt'
      test -s '${cfg.dataDir}/mtp/rt/draft_vocab.bin'
      test -s '${shard}'
      # exec preserves llama-swap's process group; the Strata engine inherits it.
      ${lib.optionalString bounded "export STRATA_RESIDENT_HEADROOM_GIB=${toString cfg.residentHeadroomGiB}"}
      export LD_LIBRARY_PATH="/run/opengl-driver/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      exec ${package}/bin/strata-server --engine strata --config ${serverConfig} --host 127.0.0.1 --port ${toString cfg.port}
    '';
  };
in
{
  options.services.strata-orca = {
    enable = lib.mkEnableOption "on-demand Orca backend managed by llama-swap";
    contextTokens = lib.mkOption {
      type = lib.types.ints.positive;
      default = 32768;
      description = "Native maximum context tokens; select only a resource-validated size";
    };
    prefillTokens = lib.mkOption {
      type = lib.types.ints.positive;
      default = 512;
      description = "Native prompt prefill chunk size in tokens";
    };
    kvType = lib.mkOption {
      type = lib.types.enum [
        "fp16"
        "int8"
        "q4_0"
        "k8v4"
      ];
      default = "int8";
      description = "Source-supported KV storage format; quantized formats require quality validation";
    };
    specWindow = lib.mkOption {
      type = lib.types.ints.between 2 8;
      default = 4;
      description = "Verification window T, allowing at most T-1 MTP draft tokens; this native pack requires MTP";
    };
    mtpMaxT = lib.mkOption {
      type = lib.types.ints.between 0 8;
      default = 0;
      description = "MTP verification-window cap; zero uses specWindow, longer windows can use suffix drafts";
    };
    suffixDraft = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 3;
      description = "Prompt suffix lookup threshold; zero disables suffix drafting";
    };
    mtpWindowTokens = lib.mkOption {
      type = lib.types.ints.positive;
      default = 32768;
      description = "MTP context window, capped at contextTokens in generated arguments";
    };
    poolWorkers = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      description = "Explicit CPU expert worker count; null preserves upstream automatic sizing";
    };
    poolAffinity = lib.mkOption {
      type = lib.types.enum [
        "auto"
        "p-cores"
        "all"
      ];
      default = "auto";
      description = "Native CPU worker placement policy; Linux P/E detection requires cpu_capacity, absent on HAL";
    };
    pcieFraction = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.addCheck (lib.types.either lib.types.int lib.types.float) (
          value: value >= 0 && value <= 1
        )
      );
      default = null;
      description = "PCIe share of GPU-cache misses routed to GPU; null preserves native bandwidth probing";
    };
    allowedDesktopComputeProcesses = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Explicit executable basenames allowed as small desktop CUDA clients; all other compute processes are refused";
    };
    maximumDesktopComputeMiB = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 512;
      description = "Aggregate VRAM ceiling for all allowlisted desktop compute processes";
    };
    minimumFreeVRAMMiB = lib.mkOption {
      type = lib.types.ints.positive;
      default = 20480;
      description = "Minimum actual free VRAM on GPU0 before loading Orca";
    };
    vramReserveMiB = lib.mkOption {
      type = lib.types.ints.positive;
      default = 2048;
      description = "Explicit native expert-cache reserve; prevents upstream automatic reserve reduction";
    };
    memoryMode = lib.mkOption {
      type = lib.types.enum [
        "resident"
        "bounded-mmap"
      ];
      default = "resident";
      description = "Full resident arena or explicitly budgeted source-supported mmap experts; bounded mode requires real inference validation";
    };
    residentBudgetGiB = lib.mkOption {
      type = lib.types.ints.positive;
      default = 24;
      description = "Expert resident budget in bounded-mmap mode; uncached experts remain disk-backed";
    };
    residentHeadroomGiB = lib.mkOption {
      type = lib.types.ints.positive;
      default = 8;
      description = "RAM reserved from expert allocation in bounded-mmap mode; preflight additionally reserves 4 GiB for runtime buffers";
    };
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
      default = 18081;
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
