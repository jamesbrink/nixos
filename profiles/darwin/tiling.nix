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
    ../../modules/darwin/fzf-launcher.nix
  ];

  # Mission Control settings for yabai compatibility
  system.defaults.dock.mru-spaces = false; # Don't auto-rearrange spaces by recent use
  system.defaults.spaces.spans-displays = false; # Displays have separate Spaces (false = separate, true = unified)

  # Dock auto-hide by default (yabai starts in BSP/tiling mode)
  # NOTE: Commented out - now managed dynamically by themectl macos-mode
  # system.defaults.dock.autohide = lib.mkForce true;

  # Keep macOS menu bar visible (set to default)
  # Note: Even though SketchyBar is available in BSP mode, keep native menu bar visible
  system.defaults.NSGlobalDomain._HIHideMenuBar = false;

  # Hide desktop icons by default (yabai starts in BSP/tiling mode)
  system.defaults.finder.CreateDesktop = false;
}
