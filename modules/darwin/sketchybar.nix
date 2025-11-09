# SketchyBar status bar configuration
# Waybar equivalent for macOS with yabai integration
{
  config,
  pkgs,
  lib,
  ...
}:

let
  # SketchyBar configuration directory
  sketchybarConfig = pkgs.writeTextDir "sketchybarrc" ''
    #!/bin/bash

    # SketchyBar configuration for Hyprland-style status bar
    # Integrates with yabai for workspace indicators

    # ====================
    # BAR APPEARANCE
    # ====================

    sketchybar --bar \
      height=32 \
      blur_radius=30 \
      position=top \
      sticky=on \
      padding_left=10 \
      padding_right=10 \
      color=0xff1a1b26 \
      topmost=window \
      drawing=on

    # ====================
    # DEFAULT SETTINGS
    # ====================

    default=(
      padding_left=5
      padding_right=5
      icon.font="SF Pro:Semibold:15.0"
      label.font="SF Pro:Semibold:13.0"
      icon.color=0xffc0caf5
      label.color=0xffc0caf5
      icon.padding_left=4
      icon.padding_right=4
      label.padding_left=4
      label.padding_right=4
    )
    sketchybar --default "''${default[@]}"

    # ====================
    # LEFT SIDE - SPACES/WORKSPACES
    # ====================

    SPACE_ICONS=("1" "2" "3" "4" "5" "6" "7" "8" "9" "10")

    for i in "''${!SPACE_ICONS[@]}"
    do
      sid=$(($i+1))
      sketchybar --add space space.$sid left \
                 --set space.$sid associated_space=$sid \
                              icon="''${SPACE_ICONS[i]}" \
                              icon.padding_left=8 \
                              icon.padding_right=8 \
                              background.padding_left=5 \
                              background.padding_right=5 \
                              background.color=0xff3b4261 \
                              background.corner_radius=5 \
                              background.height=24 \
                              label.drawing=off \
                              script="${pkgs.writeShellScript "space.sh" ''
                                #!/bin/bash
                                if [ "$SELECTED" = "true" ]; then
                                  sketchybar --set $NAME background.color=0xff7aa2f7
                                else
                                  sketchybar --set $NAME background.color=0xff3b4261
                                fi
                              ''}" \
                              click_script="yabai -m space --focus $sid"
    done

    # Separator
    sketchybar --add item separator_left left \
               --set separator_left icon="│" \
                                    icon.color=0xff3b4261 \
                                    background.padding_left=10 \
                                    background.padding_right=10

    # Window title (current focused window)
    sketchybar --add item window_title left \
               --set window_title script="${pkgs.writeShellScript "window_title.sh" ''
                 #!/bin/bash
                 WINDOW_TITLE=$(yabai -m query --windows --window | jq -r '.title')
                 if [ -z "$WINDOW_TITLE" ] || [ "$WINDOW_TITLE" = "null" ]; then
                   sketchybar --set window_title label="" drawing=off
                 else
                   # Truncate long titles
                   if [ ''${#WINDOW_TITLE} -gt 50 ]; then
                     WINDOW_TITLE="''${WINDOW_TITLE:0:47}..."
                   fi
                   sketchybar --set window_title label="$WINDOW_TITLE" drawing=on
                 fi
               ''}" \
                                  icon.drawing=off \
                                  label.max_chars=50 \
                                  updates=on

    # ====================
    # CENTER - DATE/TIME
    # ====================

    sketchybar --add item clock center \
               --set clock update_freq=10 \
                           icon=󰃰 \
                           script="${pkgs.writeShellScript "clock.sh" ''
                             #!/bin/bash
                             sketchybar --set $NAME label="$(date '+%a %d %b %H:%M')"
                           ''}"

    # ====================
    # RIGHT SIDE - SYSTEM STATS
    # ====================

    # CPU usage
    sketchybar --add item cpu right \
               --set cpu update_freq=2 \
                         icon=󰘚 \
                         script="${pkgs.writeShellScript "cpu.sh" ''
                           #!/bin/bash
                           # Get CPU usage from top command
                           CPU_LINE=$(top -l 1 -n 0 | grep "CPU usage")
                           USER=$(echo "$CPU_LINE" | awk '{print $3}' | sed 's/%//')
                           SYS=$(echo "$CPU_LINE" | awk '{print $5}' | sed 's/%//')
                           TOTAL=$(echo "$USER + $SYS" | bc | awk '{printf "%.0f", $1}')
                           sketchybar --set cpu label="''${TOTAL}%"
                         ''}"

    # Memory usage
    sketchybar --add item memory right \
               --set memory update_freq=10 \
                            icon=󰍛 \
                            script="${pkgs.writeShellScript "memory.sh" ''
                              #!/bin/bash
                              # Simple memory usage display using vm_stat
                              VM_STAT=$(vm_stat | grep "Pages active" | awk '{print $3}' | sed 's/\.//')
                              ACTIVE_GB=$(echo "scale=1; $VM_STAT * 4096 / 1024 / 1024 / 1024" | bc)
                              sketchybar --set memory label="''${ACTIVE_GB}GB"
                            ''}"

    # Network (just indicator, no stats)
    sketchybar --add item network right \
               --set network icon=󰖩 \
                             label.drawing=off

    # Tailscale status
    sketchybar --add item tailscale right \
               --set tailscale update_freq=5 \
                               icon=󰛳 \
                               script="${pkgs.writeShellScript "tailscale.sh" ''
                                 #!/bin/bash
                                 # Check if Tailscale is installed and running
                                 if command -v tailscale &> /dev/null; then
                                   # Get Tailscale status
                                   STATUS=$(tailscale status --json 2>/dev/null | ${pkgs.jq}/bin/jq -r '.BackendState' 2>/dev/null || echo "Stopped")

                                   case "$STATUS" in
                                     "Running")
                                       # Get IP address (first line of status)
                                       IP=$(tailscale ip -4 2>/dev/null | head -n1)
                                       if [ -n "$IP" ]; then
                                         sketchybar --set tailscale label="$IP" icon.color=0xff9ece6a
                                       else
                                         sketchybar --set tailscale label="Connected" icon.color=0xff9ece6a
                                       fi
                                       ;;
                                     "Stopped"|"NeedsLogin")
                                       sketchybar --set tailscale label="Disconnected" icon.color=0xfff7768e
                                       ;;
                                     *)
                                       sketchybar --set tailscale label="$STATUS" icon.color=0xffe0af68
                                       ;;
                                   esac
                                 else
                                   sketchybar --set tailscale label="Not installed" icon.color=0xff565f89
                                 fi
                               ''}"

    # Separator
    sketchybar --add item separator_right right \
               --set separator_right icon="│" \
                                     icon.color=0xff3b4261

    # Theme indicator (shows current theme)
    sketchybar --add item theme right \
               --set theme icon=󰏘 \
                           script="${pkgs.writeShellScript "theme.sh" ''
                             #!/bin/bash
                             THEME_FILE="$HOME/.config/themes/.current-theme"
                             if [ -f "$THEME_FILE" ]; then
                               THEME=$(cat "$THEME_FILE")
                               sketchybar --set theme label="$THEME"
                             else
                               sketchybar --set theme label="tokyo-night"
                             fi
                           ''}" \
                           update_freq=10

    # ====================
    # EVENTS
    # ====================

    # Subscribe to yabai events
    sketchybar --add event window_focus
    sketchybar --add event windows_on_spaces
    sketchybar --add event space_change

    # Trigger space updates when switching spaces
    sketchybar --subscribe space_change space_change

    # Update window title when focus changes
    sketchybar --subscribe window_title window_focus

    # ====================
    # FINALIZE
    # ====================

    sketchybar --update

    echo "SketchyBar initialized"
  '';

in
{
  # Install SketchyBar via Homebrew
  homebrew.taps = [ "FelixKratz/formulae" ];
  homebrew.brews = [ "FelixKratz/formulae/sketchybar" ];

  # Create SketchyBar config directory
  system.activationScripts.postActivation.text = lib.mkAfter ''
    echo "Setting up SketchyBar configuration..."

    # Create config directory
    mkdir -p /Users/jamesbrink/.config/sketchybar

    # Copy configuration
    cp ${sketchybarConfig}/sketchybarrc /Users/jamesbrink/.config/sketchybar/sketchybarrc
    chmod +x /Users/jamesbrink/.config/sketchybar/sketchybarrc
    chown -R jamesbrink:staff /Users/jamesbrink/.config/sketchybar

    echo "SketchyBar configuration complete"
  '';

  # Enable SketchyBar service
  launchd.user.agents.sketchybar = {
    serviceConfig = {
      ProgramArguments = [ "/opt/homebrew/bin/sketchybar" ];
      KeepAlive = true;
      RunAtLoad = true;
      StandardOutPath = "/tmp/sketchybar.log";
      StandardErrorPath = "/tmp/sketchybar.err.log";
      EnvironmentVariables = {
        PATH = "/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      };
    };
  };
}
