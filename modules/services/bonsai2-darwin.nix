# On-demand Bonsai 2 serving for Apple Silicon through PrismML llama.cpp/Metal.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.bonsai2;
  modelRevision = "b072e1d3b35a0a630cece372c2127528e0994386";
  modelRepository = "https://huggingface.co/prism-ml/Ternary-Bonsai-2-27B-gguf/resolve/${modelRevision}";

  defaultModel = pkgs.fetchurl {
    name = "Ternary-Bonsai-2-27B-PQ2_0.gguf";
    url = "${modelRepository}/Ternary-Bonsai-2-27B-PQ2_0.gguf";
    hash = "sha256-OQfcFljbH3ipgmv41by43GXbDUZjiJN69X8ilPrmLsE=";
  };

  defaultMmproj = pkgs.fetchurl {
    name = "Ternary-Bonsai-2-27B-mmproj-Q8_0.gguf";
    url = "${modelRepository}/Ternary-Bonsai-2-27B-mmproj-Q8_0.gguf";
    hash = "sha256-aAft5h1XC7hro0t1ag+hCe3DNmhgTehnxuptjx1jGQM=";
  };

  backendCommand = builtins.concatStringsSep " " [
    "${lib.getExe' cfg.package "llama-server"}"
    "--port \${PORT}"
    "--host 127.0.0.1"
    "--model ${cfg.model}"
    "--mmproj ${cfg.mmproj}"
    "--alias bonsai-2-27b"
    "--n-gpu-layers 99"
    "--flash-attn on"
    "--jinja"
    "--ctx-size ${toString cfg.contextTokens}"
    "--parallel 1"
    "--cache-type-k f16"
    "--cache-type-v f16"
    "--image-min-tokens 1024"
    "--image-max-tokens 1024"
    "--predict 16384"
    "--reasoning-budget 8192"
    "--temp 1.0"
    "--top-p 0.95"
    "--top-k 20"
    "--min-p 0.05"
  ];

  swapConfig = (pkgs.formats.yaml { }).generate "bonsai2-llama-swap.yaml" {
    healthCheckTimeout = 300;
    models.bonsai-2-27b = {
      cmd = backendCommand;
      concurrencyLimit = 16;
      ttl = cfg.ttlSeconds;
    };
  };
in
{
  options.services.bonsai2 = {
    enable = lib.mkEnableOption "on-demand Bonsai 2 serving on Apple Silicon";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.llama-cpp-prism;
      defaultText = lib.literalExpression "pkgs.llama-cpp-prism";
      description = "PrismML llama.cpp build with Bonsai 2 Metal kernels.";
    };

    swapPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.unstablePkgs.llama-swap;
      defaultText = lib.literalExpression "pkgs.unstablePkgs.llama-swap";
      description = "llama-swap package used for on-demand loading and idle unloading.";
    };

    model = lib.mkOption {
      type = lib.types.path;
      default = defaultModel;
      defaultText = "Pinned official Bonsai 2 27B PQ2_0 GGUF";
      description = "Bonsai 2 language-model GGUF.";
    };

    mmproj = lib.mkOption {
      type = lib.types.path;
      default = defaultMmproj;
      defaultText = "Pinned official Bonsai 2 27B Q8_0 vision projector";
      description = "Bonsai 2 vision projector GGUF.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address on which llama-swap exposes the OpenAI-compatible API.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port on which llama-swap exposes the OpenAI-compatible API.";
    };

    contextTokens = lib.mkOption {
      type = lib.types.ints.between 1024 262144;
      default = 16384;
      description = "Single-slot context capacity. The default is PrismML's safe tier for 16 GB Macs.";
    };

    ttlSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 600;
      description = "Idle time before llama-swap unloads the model and returns unified memory to macOS.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "jamesbrink";
      description = "User under which the model server runs.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    launchd.daemons.bonsai2 = {
      serviceConfig = {
        ProgramArguments = [
          (lib.getExe cfg.swapPackage)
          "--listen"
          "${cfg.host}:${toString cfg.port}"
          "--config"
          (toString swapConfig)
        ];
        EnvironmentVariables = {
          HOME = "/Users/${cfg.user}";
        };
        GroupName = "staff";
        KeepAlive = true;
        ProcessType = "Interactive";
        RunAtLoad = true;
        StandardErrorPath = "/tmp/bonsai2.log";
        StandardOutPath = "/tmp/bonsai2.log";
        ThrottleInterval = 10;
        UserName = cfg.user;
      };
    };
  };
}
