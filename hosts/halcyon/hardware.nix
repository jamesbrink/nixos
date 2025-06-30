{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Hardware configuration for M4 Mac (minimal for darwin)
  # Most hardware is managed by macOS directly

  # Enable Rosetta for x86_64 emulation
  nix.extraOptions = ''
    extra-platforms = x86_64-darwin aarch64-darwin
  '';
}
