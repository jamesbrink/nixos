# A second quantization of the same Orca model, sharing the tested tuning policy.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.orca-q4;
  primary = config.services.strata-orca;
  package = pkgs.callPackage ../../../pkgs/strata.nix { };
  originalText = config.environment.etc."strata-orca.json".source.text;
  # JSON parsing requires a context-free string; reattach the original store
  # dependencies when writing the variant so its closure remains complete.
  original = builtins.fromJSON (builtins.unsafeDiscardStringContext originalText);
  modelId = "orcarouter-qwen3.8-flash-next-uncensored-q4_k_m";
  shard = "${cfg.dataDir}/models/Qwen3.8-Flash-Next-Uncensored-Q4_K_M-00001-of-00003.gguf";
  oldShard = "${primary.dataDir}/models/Qwen3.8-Flash-Next-Uncensored-IQ3_XXS-00001-of-00002.gguf";
  serverConfig = pkgs.writeText "strata-orca-q4.json" (
    builtins.appendContext (builtins.toJSON (
      original
      // {
        # Keep all tuning/guards, including the shared 64K target and 32K draft.
        # The verified original-model MTP runtime is shared by both variants.
        args = map (
          arg:
          if arg == oldShard then
            shard
          else if arg == "${primary.dataDir}/pack" then
            "${cfg.dataDir}/pack"
          else
            arg
        ) original.args;
        cwd = cfg.dataDir;
        tokenizer = "${cfg.dataDir}/pack/tokenizer";
        log = "${cfg.dataDir}/strata.log";
        model_name = modelId;
        port = cfg.port;
      }
    )) (builtins.getContext originalText)
  );
  provision = pkgs.writeShellApplication {
    name = "strata-orca-q4-provision";
    runtimeInputs = [
      package
      pkgs.curl
      pkgs.coreutils
    ];
    text = ''
      exec ${pkgs.bash}/bin/bash ${../../../scripts/strata-orca-q4-provision.sh} "$@"
    '';
  };
  launcher = pkgs.writeShellApplication {
    name = "orca-q4-launch";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      config.hardware.nvidia.package
    ];
    text = ''
      available=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)
      if [ "$available" -lt ${toString (original.minimum_available_gib * 1048576)} ]; then
        echo "Orca Q4 requires ${toString original.minimum_available_gib} GiB MemAvailable before startup." >&2
        exit 1
      fi
      ${pkgs.python3}/bin/python3 ${../../../scripts/strata-gpu-guard.py} --config ${serverConfig} --nvidia-smi ${lib.getBin config.hardware.nvidia.package}/bin/nvidia-smi
      test -s '${shard}'
      test -s '${cfg.dataDir}/pack/native_experts.txt'
      test -s '${primary.dataDir}/mtp/rt/draft_vocab.bin'
      export LD_LIBRARY_PATH="/run/opengl-driver/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      ${lib.optionalString (
        primary.memoryMode == "bounded-mmap"
      ) "export STRATA_RESIDENT_HEADROOM_GIB=${toString primary.residentHeadroomGiB}"}
      exec ${package}/bin/strata-server --engine strata --config ${serverConfig} --host 127.0.0.1 --port ${toString cfg.port}
    '';
  };
in
{
  options.services.orca-q4 = {
    enable = lib.mkEnableOption "Orca Q4_K_M through shared llama-swap";
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/strata-orca-q4_k_m";
      description = "Root-SSD directory containing verified Q4_K_M shards and its own compatibility pack";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 18082;
      description = "Private Strata backend port";
    };
  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ provision ];
    assertions = [
      {
        assertion = primary.enable;
        message = "Orca Q4 shares tuning and admission policy with the enabled IQ3 backend.";
      }
      {
        assertion = cfg.port != primary.port;
        message = "Orca quantizations require separate backend ports.";
      }
      {
        assertion = cfg.dataDir != primary.dataDir;
        message = "Orca quantizations require separate model and pack directories.";
      }
    ];
    systemd.tmpfiles.rules = [ "d ${cfg.dataDir} 0770 strata-orca strata-orca -" ];
    environment.etc."strata-orca-q4.json".source = serverConfig;
    systemd.services.llama-swap.serviceConfig.ReadWritePaths = [ cfg.dataDir ];
    services.llama-swap.settings.models.${modelId} = {
      cmd = "${launcher}/bin/orca-q4-launch";
      proxy = "http://127.0.0.1:${toString cfg.port}";
      checkEndpoint = "/health";
      ttl = 600;
      unloadTimeout = 75;
      concurrencyLimit = 64;
      useModelName = modelId;
    };
  };
}
