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

  # ==========================================================================
  # MODE-RELATED SETTINGS - ALL MANAGED BY themectl macos-mode
  # ==========================================================================
  # The following settings are NOT set here because they are dynamically
  # controlled by `themectl macos-mode` (toggle with Cmd+Shift+Space):
  #
  # - dock.autohide: BSP=true, Native=false
  # - finder.CreateDesktop: BSP=false, Native=true
  # - Menu bar auto-hide settings (_HIHideMenuBar, AppleMenuBarAutoHide, etc.)
  #
  # Setting them here would override the user's mode preference on every deploy.
  # The current mode is persisted in ~/.bsp-mode-state
  # ==========================================================================

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
}
