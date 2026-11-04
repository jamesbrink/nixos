# ISTA-DASLab's original (non-fine-tuned) Qwen3.8-Flash-Next GSQ-RCO Q2_0,
# Strata's fastest pack, sharing the tested Orca tuning and admission policy.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.qwen-flash-q2;
  primary = config.services.strata-orca;
  package = pkgs.callPackage ../../../pkgs/strata.nix { };
  originalText = config.environment.etc."strata-orca.json".source.text;
  # JSON parsing requires a context-free string; reattach the original store
  # dependencies when writing the variant so its closure remains complete.
  original = builtins.fromJSON (builtins.unsafeDiscardStringContext originalText);
  modelId = "qwen3.8-flash-next-q2_0";
  shard = "${cfg.dataDir}/models/Qwen3.8-Flash-Next-GSQ-RCO-Q2_0-00001-of-00002.gguf";
  # Unlike Orca, ISTA's PLE table lives in shard 2 (the shared n-gram table).
  pleShard = "${cfg.dataDir}/models/Qwen3.8-Flash-Next-GSQ-RCO-Q2_0-00002-of-00002.gguf";
  oldShard = "${primary.dataDir}/models/Qwen3.8-Flash-Next-Uncensored-IQ3_XXS-00001-of-00002.gguf";
  args = lib.imap0 (
    i: arg:
    if arg == oldShard then
      (if i > 0 && builtins.elemAt original.args (i - 1) == "--ple-gguf" then pleShard else shard)
    else if arg == "${primary.dataDir}/pack" then
      "${cfg.dataDir}/pack"
    else
      arg
  ) original.args;
  serverConfig = pkgs.writeText "strata-qwen-flash-q2.json" (
    builtins.appendContext (builtins.toJSON (
      original
      // {
        # Keep all tuning/guards; the original-model MTP runtime is shared.
        inherit args;
        cwd = cfg.dataDir;
        tokenizer = "${cfg.dataDir}/pack/tokenizer";
        log = "${cfg.dataDir}/strata.log";
        model_name = modelId;
        port = cfg.port;
      }
      // lib.optionalAttrs (original ? vision) {
        # Same vision tower; the encoder reads this model's vocabulary.
        vision = original.vision // {
          model = shard;
        };
      }
    )) (builtins.getContext originalText)
  );
  provision = pkgs.writeShellApplication {
    name = "strata-qwen-flash-q2-provision";
    runtimeInputs = [
      package
      pkgs.curl
      pkgs.coreutils
      pkgs.gawk
    ];
    text = ''
      export STRATA_QWEN_Q2_DATA_DIR="''${STRATA_QWEN_Q2_DATA_DIR:-${cfg.dataDir}}"
      exec ${pkgs.bash}/bin/bash ${../../../scripts/strata-qwen-flash-q2-provision.sh} "$@"
    '';
  };
  launcher = pkgs.writeShellApplication {
    name = "qwen-flash-q2-launch";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      config.hardware.nvidia.package
    ];
    text = ''
      available=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)
      if [ "$available" -lt ${toString (original.minimum_available_gib * 1048576)} ]; then
        echo "Qwen Flash Q2_0 requires ${toString original.minimum_available_gib} GiB MemAvailable before startup." >&2
        exit 1
      fi
      ${pkgs.python3}/bin/python3 ${../../../scripts/strata-gpu-guard.py} --config ${serverConfig} --nvidia-smi ${lib.getBin config.hardware.nvidia.package}/bin/nvidia-smi
      test -s '${shard}'
      test -s '${pleShard}'
      test -s '${cfg.dataDir}/pack/native_experts.txt'
      test -s '${primary.dataDir}/mtp/rt/draft_vocab.bin'
      ${lib.optionalString (original ? vision) "test -s '${original.vision.mmproj}'"}
      export LD_LIBRARY_PATH="/run/opengl-driver/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      ${lib.optionalString (
        primary.memoryMode == "bounded-mmap"
      ) "export STRATA_RESIDENT_HEADROOM_GIB=${toString primary.residentHeadroomGiB}"}
      exec ${package}/bin/strata-server --engine strata --config ${serverConfig} --host 127.0.0.1 --port ${toString cfg.port}
    '';
  };
in
{
  options.services.qwen-flash-q2 = {
    enable = lib.mkEnableOption "original Qwen3.8-Flash-Next Q2_0 through shared llama-swap";
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/strata-qwen-flash-q2_0";
      description = "Directory containing the verified Q2_0 shards and its own compatibility pack";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 18083;
      description = "Private Strata backend port";
    };
  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ provision ];
    services.strata-orca.monitorPorts = [ cfg.port ];
    assertions = [
      {
        assertion = primary.enable;
        message = "Qwen Flash Q2_0 shares tuning, admission policy and the MTP runtime with services.strata-orca.";
      }
      {
        assertion = cfg.port != primary.port && cfg.port != config.services.orca-q4.port;
        message = "Strata models require separate backend ports.";
      }
      {
        assertion = cfg.dataDir != primary.dataDir;
        message = "Strata models require separate model and pack directories.";
      }
    ];
    systemd.tmpfiles.rules = [ "d ${cfg.dataDir} 0770 strata-orca strata-orca -" ];
    environment.etc."strata-qwen-flash-q2.json".source = serverConfig;
    systemd.services.llama-swap.serviceConfig.ReadWritePaths = [ cfg.dataDir ];
    services.llama-swap.settings.models.${modelId} = {
      cmd = "${launcher}/bin/qwen-flash-q2-launch";
      proxy = "http://127.0.0.1:${toString cfg.port}";
      checkEndpoint = "/health";
      ttl = 600;
      unloadTimeout = 75;
      concurrencyLimit = 64;
      useModelName = modelId;
    };
  };
}
