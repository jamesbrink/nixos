# Strata MoE models behind the shared llama-swap endpoint. One set of tuning
# and admission guards applies to every model; each model only declares its
# pinned GGUF shards and backend port. Provision files with strata-provision.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.strata;
  package = pkgs.callPackage ../../../pkgs/strata.nix { };
  visionPackage = pkgs.callPackage ../../../pkgs/strata-vision.nix { strata = package; };
  bounded = cfg.memoryMode == "bounded-mmap";
  minimumAvailableGiB = if bounded then cfg.residentBudgetGiB + cfg.residentHeadroomGiB + 4 else 56;
  # Shared by every model: the original Qwen MTP draft head and the base
  # model's vision projector (ISTA-DASLab BF16, as upstream setup uses).
  mtpDir = "${cfg.stateDir}/mtp";
  mtpRevision = "de4b8e4d43b917e7706784d8bb445c9af86a3540";
  mmproj = {
    url = "https://huggingface.co/ISTA-DASLab/Qwen3.8-Flash-Next-GSQ-RCO-GGUF/resolve/ed59f92082b1e93c0e96d60a8b11aab089b52f09/mmproj-Qwen3.8-Flash-Next-BF16.gguf";
    file = "${cfg.stateDir}/mmproj-Qwen3.8-Flash-Next-BF16.gguf";
    sha256 = "b1a82259702816a5330d7bd7607cd9676b11780e79ff7348c21103ff3ce49bd0";
    size = 907543008;
  };

  modelType = lib.types.submodule (
    { name, ... }:
    {
      options = {
        port = lib.mkOption {
          type = lib.types.port;
          description = "Loopback backend port; llama-swap proxies to it";
        };
        dataDir = lib.mkOption {
          type = lib.types.str;
          default = "${cfg.stateDir}/${name}";
          description = "Directory holding this model's shards, pack and log";
        };
        url = lib.mkOption {
          type = lib.types.str;
          description = "Pinned download folder (Hugging Face resolve/<revision>/...) for the shards";
        };
        shards = lib.mkOption {
          type = lib.types.listOf (
            lib.types.submodule {
              options = {
                file = lib.mkOption { type = lib.types.str; };
                sha256 = lib.mkOption { type = lib.types.str; };
                size = lib.mkOption { type = lib.types.ints.positive; };
              };
            }
          );
          description = "GGUF shards in order; the first is --native";
        };
        pleShard = lib.mkOption {
          type = lib.types.nullOr lib.types.ints.unsigned;
          default = null;
          description = "Index of the shard holding the PLE table, passed as --ple-gguf; null lets the engine find it (upstream does for 3+ shards)";
        };
        packArgs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Extra strata-iq_pack arguments (Unsloth files need --compat-bf16)";
        };
      };
    }
  );

  shardPath = m: s: "${m.dataDir}/${s.file}";
  native = m: shardPath m (builtins.head m.shards);

  serverConfig =
    name: m:
    pkgs.writeText "strata-${name}.json" (
      builtins.toJSON (
        {
          exe = "${package}/bin/strata";
          args = [
            "--pack"
            "${m.dataDir}/pack"
            "--native"
            (native m)
          ]
          ++ lib.optionals (m.pleShard != null) [
            "--ple-gguf"
            (shardPath m (builtins.elemAt m.shards m.pleShard))
          ]
          ++ [
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
            "${mtpDir}/rt"
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
          ]
          # The engine accepts image embeddings only with --vision (#1322); the
          # server also adds it for a vision config, but keep it explicit.
          ++ lib.optional cfg.vision.enable "--vision";
          allowed_desktop_compute_processes = cfg.allowedDesktopComputeProcesses;
          maximum_desktop_compute_mib = cfg.maximumDesktopComputeMiB;
          minimum_free_vram_mib = cfg.minimumFreeVRAMMiB;
          memory_mode = cfg.memoryMode;
          resident_budget_gib = if bounded then cfg.residentBudgetGiB else null;
          resident_headroom_gib = if bounded then cfg.residentHeadroomGiB else null;
          minimum_available_gib = minimumAvailableGiB;
          cwd = m.dataDir;
          tokenizer = "${m.dataDir}/pack/tokenizer";
          model_name = name;
          log = "${m.dataDir}/strata.log";
          host = "127.0.0.1";
          # llama-swap preserves the client Host header when proxying.
          allowed_hosts = cfg.allowedHosts;
          port = m.port;
        }
        // lib.optionalAttrs cfg.vision.enable {
          # The server starts the encoder before the engine, so the expert
          # cache sizes itself around the encoder's VRAM. The encoder reads
          # this model's vocabulary from its first shard.
          vision = {
            exe = "${visionPackage}/bin/strata-vision";
            mmproj = mmproj.file;
            model = native m;
            gpu = cfg.vision.gpu;
            max_tokens = cfg.vision.maxTokens;
          };
        }
      )
    );

  launcher =
    name: m:
    let
      conf = serverConfig name m;
    in
    pkgs.writeShellApplication {
      name = "strata-launch-${name}";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.gawk
        config.hardware.nvidia.package
      ];
      text = ''
        available=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)
        if [ "$available" -lt ${toString (minimumAvailableGiB * 1048576)} ]; then
          echo "${name} (${cfg.memoryMode}) requires at least ${toString minimumAvailableGiB} GiB MemAvailable before startup; found $available KiB." >&2
          exit 1
        fi
        ${pkgs.python3}/bin/python3 ${../../../scripts/strata-gpu-guard.py} --config ${conf} --nvidia-smi ${lib.getBin config.hardware.nvidia.package}/bin/nvidia-smi
        ${lib.concatMapStringsSep "\n" (s: "test -s '${shardPath m s}'") m.shards}
        test -s '${m.dataDir}/pack/native_experts.txt'
        test -s '${mtpDir}/rt/draft_vocab.bin'
        ${lib.optionalString cfg.vision.enable "test -s '${mmproj.file}'"}
        ${lib.optionalString bounded "export STRATA_RESIDENT_HEADROOM_GIB=${toString cfg.residentHeadroomGiB}"}
        export LD_LIBRARY_PATH="/run/opengl-driver/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        # exec preserves llama-swap's process group; the engine inherits it.
        exec ${package}/bin/strata-server --engine strata --config ${conf} --host 127.0.0.1 --port ${toString m.port}
      '';
    };

  manifest = pkgs.writeText "strata-models.json" (
    builtins.toJSON {
      inherit mtpDir mtpRevision mmproj;
      inherit (cfg) stateDir;
      draftVocab = "${package}/share/strata/data/draft_vocab.bin";
      models = lib.mapAttrs (_: m: {
        inherit (m)
          dataDir
          url
          shards
          packArgs
          ;
      }) cfg.models;
    }
  );

  provision = pkgs.writeShellApplication {
    name = "strata-provision";
    runtimeInputs = [
      package
      pkgs.curl
      pkgs.jq
      pkgs.coreutils
      pkgs.findutils
      pkgs.gawk
    ];
    text = ''
      export STRATA_MANIFEST=${manifest}
      exec ${pkgs.bash}/bin/bash ${../../../scripts/strata-provision.sh} "$@"
    '';
  };

  # Follows whichever Strata model llama-swap has loaded.
  monitor = pkgs.writeShellApplication {
    name = "strata-monitor";
    runtimeInputs = [
      package
      pkgs.curl
      pkgs.jq
      pkgs.coreutils
      pkgs.ncurses
    ];
    text = ''
      export STRATA_PORTS="${
        lib.concatMapStringsSep " " (m: toString m.port) (lib.attrValues cfg.models)
      }"
      export STRATA_SWAP_URL="http://127.0.0.1:${toString config.services.llama-swap.port}"
      exec ${pkgs.bash}/bin/bash ${../../../scripts/strata-monitor.sh} "$@"
    '';
  };

  ports = map (m: m.port) (lib.attrValues cfg.models);
  dirs = [ cfg.stateDir ] ++ map (m: m.dataDir) (lib.attrValues cfg.models);
in
{
  options.services.strata = {
    enable = lib.mkEnableOption "on-demand Strata models managed by llama-swap";
    models = lib.mkOption {
      type = lib.types.attrsOf modelType;
      default = { };
      description = "Strata models by llama-swap model ID";
    };
    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/strata";
      description = "Shared MTP runtime, vision projector and default model directories";
    };
    contextTokens = lib.mkOption {
      type = lib.types.ints.positive;
      default = 32768;
      description = "Native maximum context tokens for every model; select only a resource-validated size";
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
      description = "Verification window T, allowing at most T-1 MTP draft tokens";
    };
    mtpMaxT = lib.mkOption {
      type = lib.types.ints.between 0 8;
      default = 0;
      description = "MTP verification-window cap; zero uses specWindow";
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
      description = "Native CPU worker placement policy";
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
      description = "Executable basenames allowed as small desktop CUDA clients; all other compute processes are refused";
    };
    maximumDesktopComputeMiB = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 512;
      description = "Aggregate VRAM ceiling for all allowlisted desktop compute processes";
    };
    minimumFreeVRAMMiB = lib.mkOption {
      type = lib.types.ints.positive;
      default = 20480;
      description = "Minimum actual free VRAM on GPU0 before loading a model";
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
      description = "Full resident arena or budgeted mmap experts";
    };
    residentBudgetGiB = lib.mkOption {
      type = lib.types.ints.positive;
      default = 24;
      description = "Expert resident budget in bounded-mmap mode; uncached experts stay disk-backed";
    };
    residentHeadroomGiB = lib.mkOption {
      type = lib.types.ints.positive;
      default = 8;
      description = "RAM reserved from expert allocation in bounded-mmap mode; preflight reserves 4 GiB more";
    };
    allowedHosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "hal9000"
        "hal9000.home.urandom.io"
      ];
      description = "Trusted DNS names accepted from llama-swap's preserved Host header";
    };
    readinessTimeout = lib.mkOption {
      type = lib.types.ints.positive;
      default = 900;
      description = "Global llama-swap readiness timeout in seconds, including cold Strata loading";
    };
    vision = {
      enable = lib.mkEnableOption "image input through strata-vision and the base model's mmproj";
      gpu = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Encode images on the GPU (~1.2-1.4 GiB VRAM) instead of the CPU";
      };
      maxTokens = lib.mkOption {
        type = lib.types.ints.positive;
        default = 1024;
        description = "Most context tokens one image becomes";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.length ports == lib.length (lib.unique ports);
        message = "services.strata.models need distinct ports.";
      }
      {
        assertion = !(lib.elem config.services.llama-swap.port ports);
        message = "services.strata.models ports must differ from llama-swap's.";
      }
    ];
    environment.systemPackages = [
      package
      provision
      monitor
    ];
    users.groups.strata = { };
    users.users.strata = {
      isSystemUser = true;
      group = "strata";
      extraGroups = [
        "video"
        "render"
      ];
    };
    systemd.tmpfiles.rules = map (d: "d ${d} 0770 strata strata -") dirs;
    # Generated configs, for inspection (the launchers use store paths).
    environment.etc =
      lib.mapAttrs' (
        name: m: lib.nameValuePair "strata/${name}.json" { source = serverConfig name m; }
      ) cfg.models
      // {
        "strata/models.json".source = manifest;
      };
    services.llama-swap.settings.models = lib.mapAttrs (name: m: {
      cmd = "${launcher name m}/bin/strata-launch-${name}";
      proxy = "http://127.0.0.1:${toString m.port}";
      checkEndpoint = "/health";
      ttl = 600;
      unloadTimeout = 75;
      concurrencyLimit = 64;
      useModelName = name;
    }) cfg.models;
    # The default group swaps one resident model at a time. Strata's HTTP
    # listener appears only after the model has loaded.
    services.llama-swap.settings.healthCheckTimeout = lib.mkForce cfg.readinessTimeout;
    systemd.services.llama-swap.serviceConfig = {
      SupplementaryGroups = [ "strata" ];
      # PrivateUsers remaps supplementary GIDs; use the host model-data group.
      PrivateUsers = lib.mkForce false;
      # The GPU guard matches desktop compute clients by name; with
      # ProtectProc=invisible nvidia-smi reports "[Not Found]" for them.
      ProtectProc = lib.mkForce "default";
      ReadWritePaths = dirs;
      LimitMEMLOCK = "infinity";
      TimeoutStopSec = 90;
    };
  };
}
