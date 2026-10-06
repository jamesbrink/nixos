# PrismML's llama.cpp fork (github:PrismML-Eng/llama.cpp, branch `prism`).
# Carries the ternary PQ2_0/PTQ1_0 kernels the Bonsai 2 GGUFs need; stock
# llama.cpp rejects those files. Linux builds use CUDA pinned to the RTX 4090's
# sm_89 target; aarch64-darwin builds use the package's native Metal backend.
{ src, nixpkgs }:
final: prev:
let
  buildPkgs =
    if prev.stdenv.hostPlatform.isLinux then
      import nixpkgs {
        inherit (prev.stdenv.hostPlatform) system;
        config = {
          allowUnfree = true;
          cudaSupport = true;
          cudaCapabilities = [ "8.9" ];
        };
      }
    else
      prev;
  packageSrc =
    if prev.stdenv.hostPlatform.isDarwin then
      prev.applyPatches {
        name = "llama-cpp-prism-source";
        inherit src;
        patches = [ ./llama-cpp-prism-darwin.patch ];
      }
    else
      src;
in
{
  llama-cpp-prism = buildPkgs.callPackage "${packageSrc}/.devops/nix/package.nix" {
    llamaVersion = "prism-${src.shortRev or "dirty"}";
  };
}
