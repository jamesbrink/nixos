# Keep GitHub CLI consistent across stable NixOS and unstable Darwin package sets.
final: prev: {
  gh = final.callPackage ../pkgs/gh { };
}
