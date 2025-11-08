# Yabai tiling window manager for macOS
# Mirrors Hyprland configuration from Linux setup
#
# IMPORTANT: Scripting Addition Requirements
# -----------------------------------------
# The yabai scripting addition (SA) is required for space focus commands (cmd+1,2,3...).
#
# Automatic SA Loading (fully managed by Nix):
# This configuration automatically loads the SA when:
#   1. Yabai service starts (via extraConfig line 73)
#   2. Toggling to BSP mode via Hammerspoon (cmd+shift+space)
#   3. Manually restarting yabai (cmd+ctrl+r)
#
# Sudoers Configuration (Nix-managed, fully reproducible):
#   A sudoers file is created at /etc/sudoers.d/010-yabai-sa by nix-darwin
#   This allows passwordless execution of: sudo yabai --load-sa
#   Configuration: environment.etc."sudoers.d/010-yabai-sa" (see lines 276-278)
#   Scope: All users in %admin group can load SA without password
#
# Boot Arguments (required for SA on Apple Silicon):
#   The scripting addition requires boot args to disable certain protections.
#   If space switching doesn't work, verify boot args with:
#     sudo nvram boot-args
#   Required args may include: amfi_get_out_of_my_way=1 (or similar)
#
#   CAUTION: Modifying boot args reduces system security. Only use if needed.
#
# Verification:
#   Check sudoers file: cat /etc/sudoers.d/010-yabai-sa
#   Check sudo permissions: sudo -l | grep yabai
#   Test SA loading: sudo yabai --load-sa (should work without password)
#
# Manual SA Loading:
#   If automatic loading fails, run: sudo yabai --load-sa
#
{
  config,
  pkgs,
  lib,
  ...
}:

{
  # Enable yabai service
  services.yabai = {
    enable = true;
    enableScriptingAddition = true;
    config = {
      # Layout
      layout = "bsp"; # Binary space partitioning (similar to Hyprland dwindle)

      # New window spawns to the right (Hyprland force_split = 2)
      window_placement = "second_child";

      # Window appearance
      window_border = "on";
      window_border_width = 2;
      active_window_border_color = "0xff7aa2f7"; # Tokyo Night blue (matches Hyprland)
      normal_window_border_color = "0xff3b4261"; # Tokyo Night dark gray

      # Gaps (Hyprland style - minimal)
      window_gap = 8;
      top_padding = 8;
      bottom_padding = 8;
      left_padding = 8;
      right_padding = 8;

      # Mouse settings
      mouse_follows_focus = "off";
      focus_follows_mouse = "off";
      mouse_modifier = "cmd"; # $mod equivalent
      mouse_action1 = "move"; # Cmd + left click to move
      mouse_action2 = "resize"; # Cmd + right click to resize

      # Window opacity (Hyprland has 0.97/0.9)
      window_opacity = "on";
      active_window_opacity = "0.97";
      normal_window_opacity = "0.90";

      # Split ratio
      split_ratio = "0.50";
      auto_balance = "off"; # Don't auto-balance (manual control like Hyprland)
    };

    extraConfig = ''
      # Load scripting addition on startup
      sudo yabai --load-sa 2>/dev/null || true

      # Rules for specific applications (similar to Hyprland windowrules)

      # Float specific apps
      yabai -m rule --add app="^System Settings$" manage=off
      yabai -m rule --add app="^Archive Utility$" manage=off
      yabai -m rule --add app="^Finder$" manage=off
      yabai -m rule --add app="^Alfred$" manage=off
      yabai -m rule --add app="^Raycast$" manage=off
      yabai -m rule --add app="^Calculator$" manage=off
      yabai -m rule --add app="^Activity Monitor$" manage=off
      yabai -m rule --add app="^App Store$" manage=off

      # Float dialogs and preferences
      yabai -m rule --add title="(Preferences|Settings)" manage=off
      yabai -m rule --add title="^(Open|Save)" manage=off

      # Picture-in-picture (similar to Hyprland PIP rules)
      yabai -m rule --add title="Picture in Picture" manage=off sticky=on layer=above

      # Browsers should tile properly
      yabai -m rule --add app="^(Google Chrome|Firefox|Safari|Microsoft Edge|Brave Browser)$" manage=on

      # Development tools
      yabai -m rule --add app="^(Alacritty|Ghostty|iTerm|Visual Studio Code|Cursor)$" manage=on

      # Signals for window events
      yabai -m signal --add event=window_focused action="sketchybar --trigger window_focus"
      yabai -m signal --add event=window_created action="sketchybar --trigger windows_on_spaces"
      yabai -m signal --add event=window_destroyed action="sketchybar --trigger windows_on_spaces"

      echo "yabai configuration loaded"
    '';
  };

  # SKHD hotkey daemon (maps Hyprland keybindings)
  services.skhd = {
    enable = true;
    skhdConfig = ''
      # ====================
      # APPLICATION LAUNCHES
      # ====================
      # $mod = cmd (macOS equivalent of SUPER)

      # Terminal (cmd + return)
      cmd - return : open -na Alacritty

      # File manager (cmd + shift + f)
      cmd + shift - f : open -a Finder

      # Browser (cmd + shift + b)
      cmd + shift - b : open -a "Google Chrome"
      cmd + shift + alt - b : open -na "Google Chrome" --args --incognito

      # Apps
      cmd + shift - m : open -a Spotify
      cmd + shift - n : open -na Alacritty --args -e nvim
      cmd + shift - o : open -a Obsidian
      cmd + shift - y : open -na "Google Chrome" --args --new-window https://youtube.com

      # Theme cycling (cmd + shift + t)
      cmd + shift - t : /Users/jamesbrink/.local/bin/cycle-theme

      # System monitor (cmd + alt + t)
      cmd + alt - t : open -na Alacritty --args -e btop

      # Application launcher (cmd + d) - fzf-based launcher (Rofi/Walker equivalent)
      cmd - d : open -na Alacritty --args -e macos-launcher

      # Alternative launchers available:
      # cmd + space - macOS Spotlight (default)
      # cmd + space - Alfred (if configured to override Spotlight)
      # cmd + space - Raycast (if configured to override Spotlight)

      # ====================
      # WINDOW MANAGEMENT
      # ====================

      # Close window (cmd + w)
      cmd - w : yabai -m window --close

      # Toggle float (cmd + t)
      cmd - t : yabai -m window --toggle float

      # Toggle fullscreen (cmd + f)
      cmd - f : yabai -m window --toggle zoom-fullscreen

      # Toggle native fullscreen (cmd + ctrl + f)
      cmd + ctrl - f : yabai -m window --toggle native-fullscreen

      # Toggle split orientation (cmd + j)
      cmd - j : yabai -m window --toggle split

      # ====================
      # FOCUS WINDOWS
      # ====================

      # Focus window in direction (cmd + arrows)
      cmd - left : yabai -m window --focus west
      cmd - right : yabai -m window --focus east
      cmd - up : yabai -m window --focus north
      cmd - down : yabai -m window --focus south

      # ====================
      # SWAP WINDOWS
      # ====================

      # Swap windows (cmd + shift + arrows)
      cmd + shift - left : yabai -m window --swap west
      cmd + shift - right : yabai -m window --swap east
      cmd + shift - up : yabai -m window --swap north
      cmd + shift - down : yabai -m window --swap south

      # ====================
      # WORKSPACES (SPACES)
      # ====================

      # Switch to workspace (cmd + 1-9,0)
      cmd - 1 : yabai -m space --focus 1
      cmd - 2 : yabai -m space --focus 2
      cmd - 3 : yabai -m space --focus 3
      cmd - 4 : yabai -m space --focus 4
      cmd - 5 : yabai -m space --focus 5
      cmd - 6 : yabai -m space --focus 6
      cmd - 7 : yabai -m space --focus 7
      cmd - 8 : yabai -m space --focus 8
      cmd - 9 : yabai -m space --focus 9
      cmd - 0 : yabai -m space --focus 10

      # Move window to workspace (cmd + shift + 1-9,0)
      cmd + shift - 1 : yabai -m window --space 1
      cmd + shift - 2 : yabai -m window --space 2
      cmd + shift - 3 : yabai -m window --space 3
      cmd + shift - 4 : yabai -m window --space 4
      cmd + shift - 5 : yabai -m window --space 5
      cmd + shift - 6 : yabai -m window --space 6
      cmd + shift - 7 : yabai -m window --space 7
      cmd + shift - 8 : yabai -m window --space 8
      cmd + shift - 9 : yabai -m window --space 9
      cmd + shift - 0 : yabai -m window --space 10

      # Cycle workspaces (cmd + tab / cmd + shift + tab)
      cmd - tab : yabai -m space --focus next || yabai -m space --focus first
      cmd + shift - tab : yabai -m space --focus prev || yabai -m space --focus last

      # ====================
      # WINDOW CYCLING
      # ====================

      # Cycle windows (alt + tab)
      alt - tab : yabai -m window --focus next || yabai -m window --focus first
      alt + shift - tab : yabai -m window --focus prev || yabai -m window --focus last

      # ====================
      # WINDOW RESIZING
      # ====================

      # Resize windows (cmd + minus/equal)
      cmd - 0x1B : yabai -m window --resize right:-40:0 || yabai -m window --resize left:-40:0  # minus
      cmd - 0x18 : yabai -m window --resize right:40:0 || yabai -m window --resize left:40:0    # equal
      cmd + shift - 0x1B : yabai -m window --resize bottom:0:-40 || yabai -m window --resize top:0:-40  # shift+minus
      cmd + shift - 0x18 : yabai -m window --resize bottom:0:40 || yabai -m window --resize top:0:40    # shift+equal

      # ====================
      # LAYOUT MANAGEMENT
      # ====================

      # Note: BSP/macOS mode toggle moved to Hammerspoon (cmd + shift + space)
      # This provides full toggle between yabai and native macOS window management

      # Rotate tree (cmd + r)
      cmd - r : yabai -m space --rotate 90

      # Mirror tree (cmd + x / cmd + y)
      cmd - x : yabai -m space --mirror x-axis
      cmd - y : yabai -m space --mirror y-axis

      # Balance windows (cmd + e)
      cmd - e : yabai -m space --balance

      # ====================
      # YABAI CONTROL
      # ====================

      # Restart yabai and SKHD (cmd + ctrl + r) - fixes focus issues after menu bar appears
      cmd + ctrl - r : ${pkgs.writeShellScript "restart-wm.sh" ''
        #!/bin/bash
        launchctl kickstart -k "gui/''${UID}/org.nixos.yabai"
        launchctl kickstart -k "gui/''${UID}/org.nixos.skhd"
        sleep 1
        sudo yabai --load-sa 2>/dev/null || true
        osascript -e 'display notification "Restarted window manager" with title "Yabai"'
      ''}

      # Stop/start yabai (cmd + ctrl + q)
      cmd + ctrl - q : yabai --stop-service && yabai --start-service
    '';
  };

  # Install yabai and skhd via Homebrew (nix-darwin manages config only)
  homebrew.brews = [
    "koekeishiya/formulae/yabai"
    "koekeishiya/formulae/skhd"
  ];

  # Allow yabai to load scripting addition without password
  # This enables automatic SA loading on startup and toggle
  environment.etc."sudoers.d/010-yabai-sa".text = ''
    %admin ALL=(root) NOPASSWD: /opt/homebrew/bin/yabai --load-sa
  '';
}
