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

  # Keep macOS menu bar visible (set to Never auto-hide)
  # Note: Even though SketchyBar is available in BSP mode, keep native menu bar visible
  # Setting all three keys for cross-version compatibility:
  # - Legacy (pre-Ventura): NSGlobalDomain._HIHideMenuBar (bool)
  # - Ventura/Sonoma: com.apple.Dock.autohide-menu-bar (bool)
  # - Tahoe (26.x): com.apple.controlcenter.AutoHideMenuBarOption (int)
  #   Values: 0 = Always, 1 = On Desktop Only, 2 = In Full Screen Only, 3 = Never, 4+ = In Full Screen Only
  system.defaults.NSGlobalDomain._HIHideMenuBar = false;
  system.defaults.CustomUserPreferences = {
    "com.apple.Dock" = {
      "autohide-menu-bar" = false;
    };
    "com.apple.controlcenter" = {
      AutoHideMenuBarOption = 3; # 3 = Never auto-hide
    };
  };

  # Hide desktop icons by default (yabai starts in BSP/tiling mode)
  system.defaults.finder.CreateDesktop = false;
}
