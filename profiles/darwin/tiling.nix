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
  #
  # IMPORTANT: After extensive testing, discovered menu bar auto-hide is controlled by FOUR settings:
  #
  # 1. NSGlobalDomain._HIHideMenuBar (LEGACY)
  #    - false (0) = Menu bar VISIBLE (don't auto-hide)
  #    - true (1)  = Menu bar AUTO-HIDES
  #
  # 2. NSGlobalDomain.AppleMenuBarAutoHide (PRIMARY CONTROL)
  #    - false (0) = Menu bar visible
  #    - true (1)  = Menu bar auto-hides
  #
  # 3. com.apple.Dock.autohide-menu-bar (VENTURA/SONOMA)
  #    - false (0) = Menu bar visible
  #    - true (1)  = Menu bar auto-hides
  #
  # 4. com.apple.controlcenter.AutoHideMenuBarOption (TAHOE 26.x UI VALUE)
  #    - 0 = Always auto-hide
  #    - 1 = On Desktop Only
  #    - 2 = In Full Screen Only
  #    - 3 = Never auto-hide ← What we want
  #    - 4+ = In Full Screen Only (wraps back)
  #
  # CRITICAL: Per-host settings (defaults -currentHost) override global settings!
  # macOS checks: -currentHost first, then global domain
  #
  system.defaults.NSGlobalDomain._HIHideMenuBar = false; # false = visible
  system.defaults.CustomUserPreferences = {
    "NSGlobalDomain" = {
      AppleMenuBarAutoHide = false; # false = visible
    };
    "com.apple.Dock" = {
      "autohide-menu-bar" = false; # false = visible
    };
    "com.apple.controlcenter" = {
      AutoHideMenuBarOption = 3; # 3 = Never auto-hide
    };
  };

  # Disable macOS built-in screenshot shortcuts so skhd can handle them
  # This prevents conflicts with workspace switching (cmd+shift+3/4) and
  # allows skhd to manage all screenshot bindings via cmd+shift+ctrl+1-5
  system.defaults.CustomUserPreferences."com.apple.symbolichotkeys" = {
    AppleSymbolicHotKeys = {
      # Disable cmd+shift+3 (Save picture of screen as a file)
      "28" = {
        enabled = false;
      };
      # Disable cmd+shift+ctrl+3 (Copy picture of screen to clipboard)
      "29" = {
        enabled = false;
      };
      # Disable cmd+shift+4 (Save picture of selected area as a file)
      "30" = {
        enabled = false;
      };
      # Disable cmd+shift+ctrl+4 (Copy picture of selected area to clipboard)
      "31" = {
        enabled = false;
      };
      # Disable cmd+shift+5 (Screenshot and recording options)
      "184" = {
        enabled = false;
      };
    };
  };

  # Hide desktop icons by default (yabai starts in BSP/tiling mode)
  system.defaults.finder.CreateDesktop = false;
}
