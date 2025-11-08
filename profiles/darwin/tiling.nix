# Tiling window manager profile for macOS Darwin
# Provides Hyprland-like experience with yabai + SketchyBar
{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ../../modules/darwin/yabai.nix
    ../../modules/darwin/sketchybar.nix
    ../../modules/darwin/productivity-apps.nix
  ];

  # Dock auto-hide by default (yabai starts in BSP/tiling mode)
  system.defaults.dock.autohide = lib.mkForce true;

  # Auto-hide native macOS menu bar (SketchyBar replaces it)
  # Note: macOS doesn't support completely removing the menu bar, only auto-hide
  # The bar will slide down when cursor touches top edge - this is a macOS limitation
  # Use cmd+ctrl+r to restart yabai/SKHD if menu bar breaks focus
  system.defaults.NSGlobalDomain._HIHideMenuBar = true;

  # Hide desktop icons by default (yabai starts in BSP/tiling mode)
  system.defaults.finder.CreateDesktop = false;
}
