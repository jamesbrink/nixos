# llama.cpp with DiffusionGemma support: the open PR ggml-org/llama.cpp#24423
# (danielhanchen/llama.cpp, branch diffusion-visual-updates). Stock llama.cpp
# rejects the `diffusion-gemma` architecture. Linux only, CUDA pinned to the
# RTX 4090's sm_89 target like overlays/llama-cpp-prism.nix.
#
# The patch lets a request switch thinking off; the engine otherwise always
# renders the chat template with enable_thinking = true.
{ src, nixpkgs }:
final: prev:
let
  buildPkgs = import nixpkgs {
    inherit (prev.stdenv.hostPlatform) system;
    config = {
      allowUnfree = true;
      cudaSupport = true;
      cudaCapabilities = [ "8.9" ];
    };
  };
in
{
  llama-cpp-diffusiongemma =
    (buildPkgs.callPackage "${src}/.devops/nix/package.nix" {
      llamaVersion = "diffusiongemma-${src.shortRev or "dirty"}";
      # The branch names the package as nixpkgs-unstable does; 26.05 still
      # calls it cuda_cccl.
      cudaPackages = buildPkgs.cudaPackages // {
        cccl = buildPkgs.cudaPackages.cccl or buildPkgs.cudaPackages.cuda_cccl;
      };
    }).overrideAttrs
      (old: {
        patches = (old.patches or [ ]) ++ [ ./llama-cpp-diffusiongemma-thinking.patch ];
      });
}
