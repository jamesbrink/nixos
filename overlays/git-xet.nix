# git-xet (Hugging Face Xet transfer agent for Git LFS) is not in our nixpkgs
# 25.11 pin, so source it from the nixos-unstable input. Home Manager builds its
# own package set here (no useGlobalPkgs), which is why this is an overlay rather
# than a `pkgs.unstablePkgs` reference.
inputs: final: prev: {
  git-xet =
    prev.git-xet or inputs.nixos-unstable.legacyPackages.${prev.stdenv.hostPlatform.system}.git-xet;
}
