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

  # Mission Control settings for yabai compatibility
  system.defaults.dock.mru-spaces = false; # Don't auto-rearrange spaces by recent use
  system.defaults.spaces.spans-displays = false; # Displays have separate Spaces (false = separate, true = unified)

  # Dock auto-hide by default (yabai starts in BSP/tiling mode)
  system.defaults.dock.autohide = lib.mkForce true;

  # Auto-hide native macOS menu bar (SketchyBar replaces it in BSP mode)
  # Note: macOS 26 Tahoe requires manual setting in System Settings > Desktop & Dock > Menu Bar
  # The _HIHideMenuBar preference seems to be ignored/conflicted in Tahoe
  # system.defaults.NSGlobalDomain._HIHideMenuBar = true;

  # Hide desktop icons by default (yabai starts in BSP/tiling mode)
  system.defaults.finder.CreateDesktop = false;
}
