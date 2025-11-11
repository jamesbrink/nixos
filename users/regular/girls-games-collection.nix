# Curated collection of free, safe, ad-free games for kids ages 8 and under
# All games are from nixpkgs and installable on macOS via nix-darwin
#
# To enable these games, import this file in your girls-darwin.nix module
{
  config,
  pkgs,
  lib,
  ...
}:

{
  home-manager.users.girls =
    { pkgs, lib, ... }:
    {
      home.packages = with pkgs; [
        # ==========================================
        # EDUCATIONAL & CREATIVE APPS
        # ==========================================

        # NOTE: Most open-source games in nixpkgs are Linux-only (require X11/Wayland)
        # For macOS, games are better installed via Homebrew casks or Mac App Store
        # See GAMES-GUIDE.md for recommended games to install via other methods

        # For now, this is an empty list - games will be added via Homebrew
        # or other macOS-native installation methods
      ];
    };
}
