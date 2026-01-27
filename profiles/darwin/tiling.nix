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
  #
  # NOTE: Must include full structure (enabled + value + parameters) or macOS
  # will reset the keys on login. The parameters encode the key combo:
  #   - param[0]: ASCII keycode (51='3', 52='4', 53='5')
  #   - param[1]: virtual keycode
  #   - param[2]: modifier flags (1179648=cmd+shift, 1441792=cmd+shift+ctrl, 262144=ctrl)
  system.defaults.CustomUserPreferences."com.apple.symbolichotkeys" = {
    AppleSymbolicHotKeys = {
      # Enable native macOS Space switching with Ctrl+1-9,0
      # These work WITHOUT yabai scripting addition!
      # 118-127 are "Switch to Desktop 1-10"
      "118" = {
        enabled = true;
        value = {
          type = "standard";
          parameters = [
            49 # '1' key
            18 # virtual keycode
            262144 # ctrl modifier
          ];
        };
      };
      "119" = {
        enabled = true;
        value = {
          type = "standard";
          parameters = [
            50 # '2' key
            19
            262144
          ];
        };
      };
      "120" = {
        enabled = true;
        value = {
          type = "standard";
          parameters = [
            51 # '3' key
            20
            262144
          ];
        };
      };
      "121" = {
        enabled = true;
        value = {
          type = "standard";
          parameters = [
            52 # '4' key
            21
            262144
          ];
        };
      };
      "122" = {
        enabled = true;
        value = {
          type = "standard";
          parameters = [
            53 # '5' key
            23
            262144
          ];
        };
      };
      "123" = {
        enabled = true;
        value = {
          type = "standard";
          parameters = [
            54 # '6' key
            22
            262144
          ];
        };
      };
      "124" = {
        enabled = true;
        value = {
          type = "standard";
          parameters = [
            55 # '7' key
            26
            262144
          ];
        };
      };
      "125" = {
        enabled = true;
        value = {
          type = "standard";
          parameters = [
            56 # '8' key
            28
            262144
          ];
        };
      };
      "126" = {
        enabled = true;
        value = {
          type = "standard";
          parameters = [
            57 # '9' key
            25
            262144
          ];
        };
      };
      "127" = {
        enabled = true;
        value = {
          type = "standard";
          parameters = [
            48 # '0' key
            29
            262144
          ];
        };
      };

      # Disable cmd+shift+3 (Save picture of screen as a file)
      "28" = {
        enabled = false;
        value = {
          type = "standard";
          parameters = [
            51
            20
            1179648
          ];
        };
      };
      # Disable cmd+shift+ctrl+3 (Copy picture of screen to clipboard)
      "29" = {
        enabled = false;
        value = {
          type = "standard";
          parameters = [
            51
            20
            1441792
          ];
        };
      };
      # Disable cmd+shift+4 (Save picture of selected area as a file)
      "30" = {
        enabled = false;
        value = {
          type = "standard";
          parameters = [
            52
            21
            1179648
          ];
        };
      };
      # Disable cmd+shift+ctrl+4 (Copy picture of selected area to clipboard)
      "31" = {
        enabled = false;
        value = {
          type = "standard";
          parameters = [
            52
            21
            1441792
          ];
        };
      };
      # Disable cmd+shift+5 (Screenshot and recording options)
      "184" = {
        enabled = false;
        value = {
          type = "standard";
          parameters = [
            53
            23
            1179648
          ];
        };
      };
    };
  };

  # Apply symbolic hotkeys changes immediately after activation
  # macOS caches these settings, so we need to restart the service
  system.activationScripts.postActivation.text = ''
    echo "Reloading symbolic hotkeys..."
    /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u 2>/dev/null || true
  '';
}
