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
  modelFileName = "Ternary-Bonsai-2-27B-PQ2_0.gguf";
  modelSha256 = "3907dc1658db1f78a9826bf8d5bcb8dc65db0d466388937af57f2294fae62ec1";
  mmprojFileName = "Ternary-Bonsai-2-27B-mmproj-Q8_0.gguf";
  mmprojSha256 = "6807ede61d570bb86ba34b756a0fa109edc33668604de867c6ea6d8f1d631903";
  modelPath = "${cfg.dataDir}/${modelFileName}";
  mmprojPath = "${cfg.dataDir}/${mmprojFileName}";

  backendCommand = builtins.concatStringsSep " " [
    "${lib.getExe' cfg.package "llama-server"}"
    "--port \${PORT}"
    "--host 127.0.0.1"
    "--model ${modelPath}"
    "--mmproj ${mmprojPath}"
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

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/Users/${cfg.user}/.local/share/bonsai2";
      description = ''
        Mutable model directory. Disabling this module removes the directory so
        the downloaded model and vision projector do not survive the redeploy.
      '';
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

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = lib.hasPrefix "/Users/${cfg.user}/" cfg.dataDir;
          message = "services.bonsai2.dataDir must be inside /Users/${cfg.user}/";
        }
      ];

      system.activationScripts.preActivation.text =
        if cfg.enable then
          ''
            bonsai2_download() {
              local url="$1"
              local expected_sha256="$2"
              local target="$3"

              if test -f "$target" \
                && echo "$expected_sha256  $target" | ${pkgs.coreutils}/bin/sha256sum --check --status
              then
                return
              fi

              rm -f -- "$target"
              ${pkgs.curl}/bin/curl \
                --fail \
                --location \
                --retry 5 \
                --retry-all-errors \
                --continue-at - \
                --output "$target.part" \
                "$url"
              if ! echo "$expected_sha256  $target.part" \
                | ${pkgs.coreutils}/bin/sha256sum --check --status
              then
                rm -f -- "$target.part"
                return 1
              fi
              mv -f -- "$target.part" "$target"
            }

            echo "provisioning Bonsai 2 model data..." >&2
            install -d -m 0755 -o ${lib.escapeShellArg cfg.user} -g staff ${lib.escapeShellArg cfg.dataDir}
            bonsai2_download \
              ${lib.escapeShellArg "${modelRepository}/${modelFileName}"} \
              ${lib.escapeShellArg modelSha256} \
              ${lib.escapeShellArg modelPath}
            bonsai2_download \
              ${lib.escapeShellArg "${modelRepository}/${mmprojFileName}"} \
              ${lib.escapeShellArg mmprojSha256} \
              ${lib.escapeShellArg mmprojPath}
            chown -R ${lib.escapeShellArg "${cfg.user}:staff"} ${lib.escapeShellArg cfg.dataDir}
          ''
        else
          ''
            echo "removing disabled Bonsai 2 model data..." >&2
            rm -rf -- ${lib.escapeShellArg cfg.dataDir}
            rm -f -- /tmp/bonsai2.log
          '';
    }

    (lib.mkIf cfg.enable {
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
    })
  ];
}
