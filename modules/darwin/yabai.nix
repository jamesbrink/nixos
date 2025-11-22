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
# IMPORTANT: macOS 26.1+ Accessibility Permissions (TCC)
# -----------------------------------------------------
# macOS 26.1 introduced a bug where binary executables don't appear in
# System Settings > Privacy & Security > Accessibility UI, even when TCC
# database entries exist. This affects yabai and skhd.
#
# Solution: tccutil (jacobsalmela/tccutil)
#   This module automatically installs tccutil via Homebrew, which can
#   properly grant accessibility permissions on macOS 26.1+.
#
# Automatic TCC Grant (via themectl):
#   Run: themectl doctor
#   This uses tccutil to grant accessibility permissions to yabai/skhd.
#
# Requirements:
#   - tccutil installed (added to homebrew.brews below)
#   - SIP filesystem protection disabled (tccutil requirement)
#   - Administrator privileges
#
# Symptoms of TCC Issues:
#   - "yabai: could not access accessibility features! abort.."
#   - "skhd: must be run with accessibility access! abort.."
#   - Binaries missing from System Settings accessibility list
#
# References:
#   - https://github.com/koekeishiya/yabai/issues/2688 (macOS 26.1 TCC bug)
#   - https://github.com/jacobsalmela/tccutil (TCC manipulation tool)
#
{
  config,
  pkgs,
  lib,
  hotkeysBundle ? null,
  ...
}:

let
  resolvedHotkeys =
    if hotkeysBundle != null then hotkeysBundle else import ../../lib/hotkeys.nix { inherit pkgs; };
  hotkeysData = resolvedHotkeys.data;
  # Hotkey helper: spawns Alacritty windows using the current workspace's terminal cwd
  alacrittyCwdLauncher = pkgs.writeShellApplication {
    name = "alacritty-cwd-launch";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      set -euo pipefail

      PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

      args=("$@")
      open_bin="/usr/bin/open"
      [[ -x "$open_bin" ]] || open_bin="$(command -v open || true)"

      if [[ -z "$open_bin" ]]; then
        echo "[alacritty-cwd-launch] Unable to find 'open' command" >&2
        exit 1
      fi

      yabai_bin="$(command -v yabai || true)"
      pgrep_bin="$(command -v pgrep || true)"
      lsof_bin="$(command -v lsof || true)"

      determine_workspace_cwd() {
        local windows_json
        windows_json="$("$yabai_bin" -m query --windows --space 2>/dev/null)" || return 1

        mapfile -t candidate_pids < <(
          printf '%s' "$windows_json" | jq -r '
            if type == "array" then
              map(select(.app == "Alacritty"))
            else
              []
            end
            | sort_by(.focused // 0)
            | reverse
            | .[].pid
          '
        )

        if [[ ''${#candidate_pids[@]} -eq 0 ]]; then
          return 1
        fi

        for pid in "''${candidate_pids[@]}"; do
          if dir="$(trace_shell_cwd "$pid")"; then
            printf '%s\n' "$dir"
            return 0
          fi
        done

        return 1
      }

      trace_shell_cwd() {
        local root_pid="$1"
        local queue=("$root_pid")
        local visited=" $root_pid "

        while [[ ''${#queue[@]} -gt 0 ]]; do
          local current="''${queue[0]}"
          queue=("''${queue[@]:1}")

          local children
          children="$("$pgrep_bin" -P "$current" 2>/dev/null || true)"
          if [[ -z "$children" ]]; then
            continue
          fi

          for child in $children; do
            if [[ " $visited " == *" $child "* ]]; then
              continue
            fi
            visited+=" $child "

            local cwd
            cwd="$("$lsof_bin" -a -d cwd -p "$child" -Fn 2>/dev/null | sed -n 's/^n//p' | head -n1 || true)"
            if [[ -n "$cwd" && -d "$cwd" && "$cwd" != "/" ]]; then
              printf '%s\n' "$cwd"
              return 0
            fi

            queue+=("$child")
          done
        done

        return 1
      }

      target_dir="$HOME"
      if [[ -n "$yabai_bin" && -n "$pgrep_bin" && -n "$lsof_bin" ]]; then
        if workspace_dir="$(determine_workspace_cwd)"; then
          target_dir="$workspace_dir"
        fi
      fi

      exec "$open_bin" -na Alacritty --args --working-directory "$target_dir" "''${args[@]}"
    '';
  };

  macScreenshotHelper = pkgs.writeShellApplication {
    name = "macos-screenshot";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      set -euo pipefail

      PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

      mode="full"
      save_mode="both"  # Default to both file AND clipboard

      while [[ $# -gt 0 ]]; do
        case "$1" in
          full|selection|window|ui)
            mode="$1"
            ;;
          --clipboard)
            save_mode="clipboard"  # Only clipboard
            ;;
          --file)
            save_mode="file"  # Only file
            ;;
          --both)
            save_mode="both"  # Both file and clipboard
            ;;
          *)
            echo "Usage: macos-screenshot [full|selection|window|ui] [--clipboard|--file|--both]" >&2
            exit 1
            ;;
        esac
        shift
      done

      if [[ "$mode" == "ui" ]]; then
        open -a Screenshot
        exit 0
      fi

      screencapture_bin="$(command -v screencapture || true)"
      if [[ -z "$screencapture_bin" ]]; then
        echo "[macos-screenshot] 'screencapture' not found" >&2
        exit 1
      fi

      screenshot_dir="$HOME/Pictures/Screenshots"
      mkdir -p "$screenshot_dir"
      timestamp="$(${pkgs.coreutils}/bin/date +'%Y-%m-%d_%H-%M-%S')"
      output="$screenshot_dir/Screenshot-$timestamp.png"

      args=(-x)
      case "$mode" in
        selection|window)
          args+=(-i)
          ;;
        *)
          ;;
      esac

      # Handle both file and clipboard
      if [[ "$save_mode" == "both" ]]; then
        # First save to file
        if "$screencapture_bin" "''${args[@]}" "$output"; then
          # Then copy file to clipboard
          /usr/bin/osascript -e "set the clipboard to (read (POSIX file \"$output\") as «class PNGf»)"
          /usr/bin/osascript -e 'display notification "Saved to file and clipboard" with title "Screenshot"'
        else
          exit 1
        fi
      elif [[ "$save_mode" == "clipboard" ]]; then
        args+=(-c)
        if "$screencapture_bin" "''${args[@]}"; then
          /usr/bin/osascript -e 'display notification "Copied screenshot to clipboard" with title "Screenshot"'
        else
          exit 1
        fi
      else  # file only
        args+=("$output")
        if "$screencapture_bin" "''${args[@]}"; then
          /usr/bin/osascript -e 'display notification "Saved to Pictures/Screenshots" with title "Screenshot"'
        else
          exit 1
        fi
      fi
    '';
  };

  # Smart window close helper - passes through Cmd+W to browsers/editors for tab closing
  windowCloseHelper = pkgs.writeShellApplication {
    name = "window-close-smart";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      set -euo pipefail

      PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

      # Get the currently focused application
      focused_app=$(yabai -m query --windows --window | jq -r '.app')

      # Apps that should handle Cmd+W themselves (tab closing)
      case "$focused_app" in
        "Google Chrome"|"Brave Browser"|"Firefox"|"Safari"|"Microsoft Edge")
          # Let browser handle it (close tab, not window)
          # Use skhd to pass through the key
          skhd -k "cmd - w"
          ;;
        "Visual Studio Code"|"Cursor"|"Code")
          # Let editor handle it (close file/tab)
          skhd -k "cmd - w"
          ;;
        *)
          # For other apps, use yabai to close the window
          yabai -m window --close
          ;;
      esac
    '';
  };

  yabaiSpaceHelper = pkgs.runCommandLocal "yabai-space-helper" { } ''
    mkdir -p $out/bin
    ${pkgs.coreutils}/bin/install -m755 ${../../scripts/themectl/themectl/contrib/yabai-space-helper.sh} $out/bin/yabai-space-helper
  '';
  darwinPlatform = hotkeysData.platforms.darwin;
  darwinMode = darwinPlatform.default_mode or "bsp";
  expandBindings =
    bindings:
    lib.foldl' (
      acc: name:
      let
        value = bindings.${name};
        path = lib.splitString "." name;
      in
      lib.recursiveUpdate acc (lib.setAttrByPath path value)
    ) { } (builtins.attrNames bindings);
  darwinBindings = expandBindings darwinPlatform.modes.${darwinMode}.bindings;
  hasBinding = path: lib.attrsets.hasAttrByPath path darwinBindings;
  bindingOrDefault =
    path: default:
    if hasBinding path then lib.attrsets.attrByPath path null darwinBindings else default;
  skhdBinding =
    chord: command:
    lib.optionalString (chord != null) ''
      ${skhdChord chord} : ${command}
    '';
  skhdBindingFromPath =
    path: default: command:
    skhdBinding (bindingOrDefault path default) command;
  workspaceFocusChord = bindingOrDefault [ "workspace" "focus" "chord" ] "cmd+{digit}";
  workspaceMoveChord = bindingOrDefault [ "workspace" "move" "chord" ] "cmd+shift+{digit}";
  defaultDigits = [
    "1"
    "2"
    "3"
    "4"
    "5"
    "6"
    "7"
    "8"
    "9"
    "0"
  ];
  workspaceFocusDigits = lib.attrsets.attrByPath [
    "actions"
    "workspace"
    "focus"
    "template"
    "digits"
  ] defaultDigits hotkeysData;
  workspaceMoveDigits = lib.attrsets.attrByPath [
    "actions"
    "workspace"
    "move"
    "template"
    "digits"
  ] defaultDigits hotkeysData;
  spaceIndex = digit: if digit == "0" then "10" else digit;
  skhdDigitBindings =
    chordTemplate: digits: commandBuilder:
    if chordTemplate == null then
      ""
    else
      lib.concatStringsSep "\n" (
        map (
          digit:
          let
            chord = lib.replaceStrings [ "{digit}" ] [ digit ] chordTemplate;
          in
          ''
            ${skhdChord chord} : ${commandBuilder digit}
          ''
        ) digits
      )
      + "\n";
  workspaceFocusBindings = skhdDigitBindings workspaceFocusChord workspaceFocusDigits (
    digit: "${yabaiSpaceHelper}/bin/yabai-space-helper focus ${spaceIndex digit}"
  );
  workspaceMoveBindings = skhdDigitBindings workspaceMoveChord workspaceMoveDigits (
    digit: "${yabaiSpaceHelper}/bin/yabai-space-helper move ${spaceIndex digit}"
  );
  restartWmScript = pkgs.writeShellScript "restart-wm.sh" ''
    #!/bin/bash
    launchctl kickstart -k "gui/''${UID}/org.nixos.yabai"
    launchctl kickstart -k "gui/''${UID}/org.nixos.skhd"
    sleep 1
    sudo yabai --load-sa 2>/dev/null || true
    osascript -e 'display notification "Restarted window manager" with title "Yabai"'
  '';
  toLower = lib.strings.toLower;
  formatKey =
    key:
    let
      lower = toLower key;
      isHex = lib.hasPrefix "0x" lower;
      uppercaseHex =
        let
          hexPart = lib.substring 2 ((lib.stringLength key) - 2) key;
        in
        "0x" + lib.toUpper hexPart;
    in
    if isHex then
      uppercaseHex
    else if lower == "space" then
      "space"
    else if lower == "return" then
      "return"
    else
      lower;
  formatMod = mod: toLower mod;
  skhdChord =
    chord:
    let
      parts = map toLower (lib.splitString "+" chord);
      key = formatKey (lib.last parts);
      mods = map formatMod (lib.init parts);
      modPart = lib.concatStringsSep " + " mods;
    in
    if mods == [ ] then key else "${modPart} - ${key}";
in
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
      ${skhdChord darwinBindings.launcher.terminal} : ${alacrittyCwdLauncher}/bin/alacritty-cwd-launch

      # File manager (cmd + shift + f)
      cmd + shift - f : open -a Finder

      # Browser (cmd + shift + b)
      ${skhdChord darwinBindings.launcher.browser.default} : open -a "Google Chrome"
      ${skhdChord darwinBindings.launcher.browser.incognito} : open -na "Google Chrome" --args --incognito

      # Apps
      cmd + shift - m : open -a Spotify
      cmd + shift - n : ${alacrittyCwdLauncher}/bin/alacritty-cwd-launch -e nvim
      cmd + shift - o : open -a Obsidian
      cmd + shift - y : open -na "Google Chrome" --args --new-window https://youtube.com

      # Theme cycling lives in Hammerspoon so automation + notifications run from a single daemon.

      # System monitor (cmd + alt + t)
      cmd + alt - t : ${alacrittyCwdLauncher}/bin/alacritty-cwd-launch -e btop

      # Application launcher (cmd + d) - fzf-based launcher (Rofi/Walker equivalent)
      ${skhdChord darwinBindings.launcher.walker} : ${alacrittyCwdLauncher}/bin/alacritty-cwd-launch -e macos-launcher

      # Alternative launchers available:
      # cmd + space - macOS Spotlight (default)
      # cmd + space - Alfred (if configured to override Spotlight)
      # cmd + space - Raycast (if configured to override Spotlight)

      # ====================
      # SCREENSHOTS (All save to ~/Pictures/Screenshots AND copy to clipboard)
      # ====================

      # Full screen to clipboard AND file (Cmd+Shift+Ctrl+1)
      ${skhdChord darwinBindings.screenshot.full_save} : ${macScreenshotHelper}/bin/macos-screenshot full --both

      # Region selection to clipboard AND file (Cmd+Shift+Ctrl+2)
      ${skhdChord darwinBindings.screenshot.region_save} : ${macScreenshotHelper}/bin/macos-screenshot selection --both

      # Full screen to clipboard AND file (Cmd+Shift+Ctrl+3)
      ${skhdChord darwinBindings.screenshot.full_clipboard} : ${macScreenshotHelper}/bin/macos-screenshot full --both

      # Region selection to clipboard AND file (Cmd+Shift+Ctrl+4)
      ${skhdChord darwinBindings.screenshot.region_clipboard} : ${macScreenshotHelper}/bin/macos-screenshot selection --both

      # Screenshot UI (Cmd+Shift+Ctrl+5)
      ${skhdChord darwinBindings.screenshot.ui} : ${macScreenshotHelper}/bin/macos-screenshot ui

      # ====================
      # WINDOW MANAGEMENT
      # ====================

      # Close window (smart: passes through for browsers/editors)
      ${skhdBindingFromPath [ "window" "close" ] "cmd+w" "${windowCloseHelper}/bin/window-close-smart"}

      # Toggle float
      ${skhdBindingFromPath [ "window" "float" "toggle" ] "cmd+t" "yabai -m window --toggle float"}

      # Toggle fullscreen
      ${skhdBindingFromPath [
        "window"
        "fullscreen"
        "toggle"
      ] "cmd+f" "yabai -m window --toggle zoom-fullscreen"}

      # Toggle native fullscreen
      ${skhdBindingFromPath [
        "window"
        "native_fullscreen"
        "toggle"
      ] "cmd+ctrl+f" "yabai -m window --toggle native-fullscreen"}

      # Toggle split orientation
      ${skhdBindingFromPath [ "window" "split" "toggle" ] "cmd+j" "yabai -m window --toggle split"}

      # ====================
      # FOCUS WINDOWS
      # ====================

      # Focus window in direction
      ${skhdBindingFromPath [ "window" "focus" "west" ] "cmd+left" "yabai -m window --focus west"}
      ${skhdBindingFromPath [ "window" "focus" "east" ] "cmd+right" "yabai -m window --focus east"}
      ${skhdBindingFromPath [ "window" "focus" "north" ] "cmd+up" "yabai -m window --focus north"}
      ${skhdBindingFromPath [ "window" "focus" "south" ] "cmd+down" "yabai -m window --focus south"}

      # ====================
      # SWAP WINDOWS
      # ====================

      # Swap windows
      ${skhdBindingFromPath [ "window" "swap" "west" ] "cmd+shift+left" "yabai -m window --swap west"}
      ${skhdBindingFromPath [ "window" "swap" "east" ] "cmd+shift+right" "yabai -m window --swap east"}
      ${skhdBindingFromPath [ "window" "swap" "north" ] "cmd+shift+up" "yabai -m window --swap north"}
      ${skhdBindingFromPath [ "window" "swap" "south" ] "cmd+shift+down" "yabai -m window --swap south"}

      # ====================
      # WORKSPACES (SPACES)
      # ====================

      # Switch to workspace (cmd + 1-9,0)
      ${workspaceFocusBindings}

      # Move window to workspace (cmd + shift + 1-9,0)
      ${workspaceMoveBindings}

      # Cycle workspaces
      ${skhdBindingFromPath [
        "space"
        "cycle"
        "next"
      ] "cmd+tab" "yabai -m space --focus next || yabai -m space --focus first"}
      ${skhdBindingFromPath [
        "space"
        "cycle"
        "prev"
      ] "cmd+shift+tab" "yabai -m space --focus prev || yabai -m space --focus last"}

      # ====================
      # WINDOW CYCLING
      # ====================

      # Cycle windows
      ${skhdBindingFromPath [
        "window_cycle"
        "next"
      ] "alt+tab" "yabai -m window --focus next || yabai -m window --focus first"}
      ${skhdBindingFromPath [
        "window_cycle"
        "prev"
      ] "alt+shift+tab" "yabai -m window --focus prev || yabai -m window --focus last"}

      # ====================
      # WINDOW RESIZING
      # ====================

      # Resize windows
      ${skhdBindingFromPath [
        "window"
        "resize"
        "horizontal"
        "decrease"
      ] "cmd+0x1B" "yabai -m window --resize right:-40:0 || yabai -m window --resize left:-40:0"}
      ${skhdBindingFromPath [
        "window"
        "resize"
        "horizontal"
        "increase"
      ] "cmd+0x18" "yabai -m window --resize right:40:0 || yabai -m window --resize left:40:0"}
      ${skhdBindingFromPath [
        "window"
        "resize"
        "vertical"
        "decrease"
      ] "cmd+shift+0x1B" "yabai -m window --resize bottom:0:-40 || yabai -m window --resize top:0:-40"}
      ${skhdBindingFromPath [
        "window"
        "resize"
        "vertical"
        "increase"
      ] "cmd+shift+0x18" "yabai -m window --resize bottom:0:40 || yabai -m window --resize top:0:40"}

      # ====================
      # LAYOUT MANAGEMENT
      # ====================

      # Rotate/mirror/balance layouts
      ${skhdBindingFromPath [ "layout" "rotate" ] "cmd+r" "yabai -m space --rotate 90"}
      ${skhdBindingFromPath [ "layout" "mirror" "x" ] "cmd+x" "yabai -m space --mirror x-axis"}
      ${skhdBindingFromPath [ "layout" "mirror" "y" ] "cmd+y" "yabai -m space --mirror y-axis"}
      ${skhdBindingFromPath [ "layout" "balance" ] "cmd+e" "yabai -m space --balance"}

      # ====================
      # YABAI CONTROL
      # ====================

      # Restart yabai/skhd
      ${skhdBindingFromPath [ "wm" "restart" ] "cmd+ctrl+r" restartWmScript}

      # Stop/start yabai
      ${skhdBindingFromPath [
        "wm"
        "reload"
      ] "cmd+ctrl+q" "yabai --stop-service && yabai --start-service"}
    '';
  };

  # Install tccutil via Homebrew (not available in nixpkgs)
  # yabai and skhd are provided by nix via services.yabai.enable and services.skhd.enable
  homebrew.brews = [
    "tccutil" # TCC database manipulation tool for macOS 26.1+ accessibility permissions
  ];

  # Allow yabai to load scripting addition without password
  # This enables automatic SA loading on startup and toggle
  environment.etc."sudoers.d/010-yabai-sa".text = ''
    %admin ALL=(root) NOPASSWD: ${pkgs.yabai}/bin/yabai --load-sa
  '';
}
