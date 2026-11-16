# DiffusionGemma 26B-A4B (Google's block-diffusion Gemma 4: 25.2B total, 3.8B
# active) as an on-demand llama-swap model.
#
# Runtime: llama.cpp's open PR #24423 (overlays/llama-cpp-diffusiongemma.nix).
# Its engine, llama-diffusion-gemma-visual-server, keeps the GGUF resident but
# only speaks a stdin/stdout line protocol, so server.py puts
# /v1/chat/completions in front of it. vLLM is the only runtime with a server
# of its own, and it needs 64 GB for BF16 and 24 GB free for NVFP4, which a
# 24 GB card that also drives a desktop does not have.
#
# Text arrives one 256-token block at a time. Text only: the engine loads no
# vision projector. One request at a time; others queue.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.diffusiongemma;
in
{
  options.services.diffusiongemma = {
    enable = lib.mkEnableOption "DiffusionGemma behind llama-swap";
    contextTokens = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 0;
      description = "Prompt plus output budget in tokens; 0 lets the engine take the largest window that fits free VRAM at load, up to 65536";
    };
    defaultMaxTokens = lib.mkOption {
      type = lib.types.ints.positive;
      default = 4096;
      description = "Output limit for requests that set none, rounded up to whole 256-token blocks";
    };
    flashAttention = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Run the engine with flash attention (its own default is off)";
    };
    modelFile = lib.mkOption {
      type = lib.types.str;
      description = "DiffusionGemma GGUF";
    };
    modelId = lib.mkOption {
      type = lib.types.str;
      default = "diffusiongemma-26b-a4b-it";
      description = "llama-swap model ID";
    };
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.llama-cpp-diffusiongemma;
      defaultText = lib.literalExpression "pkgs.llama-cpp-diffusiongemma";
      description = "llama.cpp build providing llama-diffusion-gemma-visual-server";
    };
    thinking = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Think unless a request says otherwise (chat_template_kwargs.enable_thinking or reasoning_effort)";
    };
    ttl = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 600;
      description = "Idle seconds before llama-swap unloads the model";
    };
  };

  config = lib.mkIf cfg.enable {
    services.llama-swap.settings.models.${cfg.modelId} = {
      cmd = builtins.concatStringsSep " " (
        [
          (lib.getExe pkgs.python3)
          "${./server.py}"
          "--engine ${lib.getExe' cfg.package "llama-diffusion-gemma-visual-server"}"
          "--model ${cfg.modelFile}"
          "--port \${PORT}"
          "--model-id ${cfg.modelId}"
          "--context ${toString cfg.contextTokens}"
          "--default-max-tokens ${toString cfg.defaultMaxTokens}"
        ]
        ++ lib.optional cfg.flashAttention "--flash-attention"
        ++ lib.optional cfg.thinking "--thinking"
      );
      inherit (cfg) ttl;
      # Requests queue in server.py; llama-swap answers 429 past 10 otherwise.
      concurrencyLimit = 64;
    };
  };
}
