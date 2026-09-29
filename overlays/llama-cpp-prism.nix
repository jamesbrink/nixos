# PrismML's llama.cpp fork (github:PrismML-Eng/llama.cpp, branch `prism`).
# Carries the ternary PQ2_0/PTQ1_0 kernels the Bonsai 2 GGUFs need; stock
# llama.cpp rejects those files. Built from the fork's own .devops/nix package
# against a CUDA-enabled nixpkgs pinned to sm_89 (RTX 4090) only: the default
# capability list compiles every kernel for every GPU generation and takes
# many times longer for no gain on hal9000.
{ src, nixpkgs }:
final: prev:
let
  cudaPkgs = import nixpkgs {
    inherit (prev.stdenv.hostPlatform) system;
    config = {
      allowUnfree = true;
      cudaSupport = true;
      cudaCapabilities = [ "8.9" ];
    };
  };
in
{
  llama-cpp-prism = cudaPkgs.callPackage "${src}/.devops/nix/package.nix" {
    llamaVersion = "prism-${src.shortRev or "dirty"}";
  };
}
