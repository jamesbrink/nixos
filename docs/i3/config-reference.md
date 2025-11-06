# i3 Window Manager - Configuration Reference

## Configuration File Location

i3 searches for configuration files in this order:

1. `~/.config/i3/config` (preferred)
2. `~/.i3/config` (deprecated)
3. `/etc/xdg/i3/config`
4. `/etc/i3/config`

Generate a default config:

```bash
i3-config-wizard
```

## Basic Syntax

### Comments

```bash
# This is a comment
bindsym $mod+Return exec i3-sensible-terminal  # Inline comment
```

### Variables

```bash
set $mod Mod4
set $terminal alacritty
set $browser firefox

# Use variables
bindsym $mod+Return exec $terminal
```

### Include Files

Since i3 v4.20, split configuration across multiple files:

```bash
include ~/.config/i3/workspaces.conf
include ~/.config/i3/keybindings/*.conf
include /etc/i3/config.d/*.conf
```

Supports globbing and allows conditional includes.

## Window Appearance

### Border Styles

```bash
# Default border for new windows
default_border normal|none|pixel
default_border pixel 2

# Default border for new floating windows
default_floating_border normal|pixel
default_floating_border pixel 1

# Hide edge borders
hide_edge_borders none|vertical|horizontal|both|smart
hide_edge_borders smart
```

### Title Alignment

```bash
title_align left|center|right
title_align center
```

### Window Colors

Format: `colorclass border background text indicator child_border`

```bash
# Class definitions
client.focused          #4c7899 #285577 #ffffff #2e9ef4 #285577
client.focused_inactive #333333 #5f676a #ffffff #484e50 #5f676a
client.focused_tab_title #333333 #5f676a #ffffff
client.unfocused        #333333 #222222 #888888 #292d2e #222222
client.urgent           #2f343a #900000 #ffffff #900000 #900000
client.placeholder      #000000 #0c0c0c #ffffff #000000 #0c0c0c
client.background       #ffffff
```

**Color classes:**

- `focused` - Window with focus
- `focused_inactive` - Focused window in unfocused container
- `focused_tab_title` - Tab title in focused container
- `unfocused` - Window without focus
- `urgent` - Window with urgency hint
- `placeholder` - Background/text for placeholder windows
- `background` - Background color for bar (if not specified in bar block)

## Gaps

Available since i3 v4.22:

```bash
# Inner gaps between windows
gaps inner 5
gaps inner 10px

# Outer gaps along screen edges
gaps outer 5
gaps horizontal 10
gaps vertical 5
gaps top 10
gaps right 5
gaps bottom 10
gaps left 5

# Smart gaps - disable when single window
smart_gaps on
smart_gaps inverse_outer

# Per-workspace gaps
workspace 1 gaps inner 10
workspace 2 gaps outer 5
```

## Font Configuration

```bash
# Pango font with size
font pango:DejaVu Sans Mono 8
font pango:Monospace 10

# Legacy X11 font
font -misc-fixed-medium-r-normal--13-120-75-75-C-70-iso10646-1
```

## Focus Behavior

### Focus Follows Mouse

```bash
focus_follows_mouse yes|no
focus_follows_mouse yes  # default
```

### Mouse Warping

```bash
mouse_warping output|none
mouse_warping output  # default - cursor moves to new window
mouse_warping none    # cursor stays in place
```

### Focus Wrapping

```bash
focus_wrapping yes|no|force|workspace
focus_wrapping yes        # default - wrap at container edges
focus_wrapping no         # stop at edges
focus_wrapping force      # always wrap
focus_wrapping workspace  # wrap only within workspace
```

### Focus on Window Activation

```bash
focus_on_window_activation smart|urgent|focus|none
focus_on_window_activation smart  # default
```

- `smart` - Focus if on active workspace
- `urgent` - Set urgency hint instead of focusing
- `focus` - Always focus
- `none` - Ignore activation request

### Popup Handling

```bash
popup_during_fullscreen smart|ignore|leave_fullscreen
popup_during_fullscreen smart  # default
```

## Floating Windows

### Floating Modifier

```bash
floating_modifier $mod
floating_modifier Mod1
```

Hold modifier + left-click to drag, right-click to resize floating windows.

### Default Floating

Make specific windows float by default:

```bash
for_window [class="Pavucontrol"] floating enable
for_window [window_role="pop-up"] floating enable
for_window [window_role="task_dialog"] floating enable
for_window [title="Preferences$"] floating enable
```

### Floating Size Constraints

```bash
floating_minimum_size 75 x 50
floating_maximum_size 1920 x 1080
floating_minimum_size -1 x -1  # disable
```

## Tiling Configuration

### Tiling Drag

```bash
tiling_drag modifier|titlebar|modifier titlebar
tiling_drag_threshold 10  # pixels
tiling_drag modifier titlebar
tiling_drag off  # disable

# Swap modifier for tiling drag swap
tiling_drag swap_modifier Shift
```

### Default Orientation

```bash
default_orientation horizontal|vertical|auto
default_orientation auto  # based on window dimensions
```

### Workspace Layout

```bash
workspace_layout default|stacking|tabbed
workspace_layout default
```

## Workspace Configuration

### Naming Workspaces

```bash
# Static names
bindsym $mod+1 workspace 1: web
bindsym $mod+2 workspace 2: mail
bindsym $mod+3 workspace 3: dev

# Numbers only (strip in bar)
bindsym $mod+1 workspace number 1
```

### Workspace Assignment

```bash
# Assign applications to specific workspaces
assign [class="Firefox"] 2
assign [class="^Thunderbird$"] 3: mail
assign [title="Spotify"] 4

# Assign to specific output
assign [class="URxvt"] → output HDMI1
assign [class="Firefox"] → output left
```

### Workspace-Output Assignment

```bash
workspace 1 output LVDS1
workspace 2 output primary
workspace "3: mail" output VGA1 LVDS1  # uses first available
workspace 5 output left
```

### Automatic Back-and-Forth

```bash
workspace_auto_back_and_forth yes|no
workspace_auto_back_and_forth yes
```

Press workspace key twice to return to previous workspace.

### Force Display Update

```bash
force_display_urgency_hint 500 ms
force_display_urgency_hint 0  # disable
```

## Window Rules

### For Window Criteria

Apply commands to windows matching criteria:

```bash
for_window [class="XTerm"] floating enable
for_window [class="urxvt"] border pixel 1
for_window [title="^scratchpad$"] move scratchpad
for_window [workspace="3"] floating enable
for_window [urgent="latest"] focus
```

### No Focus

Prevent windows from stealing focus:

```bash
no_focus [window_role="pop-up"]
no_focus [class="Pavucontrol"]
```

## Criteria Syntax

### Available Criteria

```bash
[class="^value$"]              # Window class (exact regex match)
[instance="value"]             # Window instance
[window_role="value"]          # Window role
[window_type="value"]          # Window type (normal, dialog, utility, toolbar, etc.)
[title="value"]                # Window title
[urgent="latest|oldest"]       # Urgent windows
[workspace="name"]             # Current workspace
[con_mark="mark"]              # Windows with mark
[con_id="id"]                  # Container ID
[id="x11_id"]                  # X11 window ID
[floating]                     # Floating windows only
[tiling]                       # Tiling windows only
[floating_from="auto|user"]    # How window became floating
[tiling_from="auto|user"]      # How window became tiling
[machine="hostname"]           # Client machine hostname
[all]                          # Match all windows
```

### Criteria Examples

```bash
# Case-insensitive matching
[class="(?i)firefox"]

# Multiple criteria (AND logic)
[class="Firefox" title="Mozilla Firefox"] kill

# Negation
[class="^.*$" title="^(?!Firefox).*$"] floating enable

# Using criteria in commands
[con_mark="important"] focus
[workspace="1"] kill
[urgent=latest] focus
```

## Bar Configuration

### Basic Bar Block

```bash
bar {
    status_command i3status
    position top|bottom
    mode dock|hide|invisible
    modifier Mod4
    workspace_buttons yes|no
    binding_mode_indicator yes|no
    strip_workspace_numbers yes|no
    strip_workspace_name yes|no
}
```

### Bar Position and Display

```bash
bar {
    position top
    output primary           # Show on primary output only
    output HDMI-1           # Show on specific output
    tray_output primary     # Tray icons on primary
    tray_output none        # Disable tray
    tray_padding 2          # Pixels between tray icons
}
```

### Bar Colors

```bash
bar {
    colors {
        background #000000
        statusline #ffffff
        separator #666666

        # Format: border background text
        focused_workspace  #4c7899 #285577 #ffffff
        active_workspace   #333333 #5f676a #ffffff
        inactive_workspace #333333 #222222 #888888
        urgent_workspace   #2f343a #900000 #ffffff
        binding_mode       #2f343a #900000 #ffffff
    }
}
```

### Bar Font

```bash
bar {
    font pango:DejaVu Sans Mono 10
    font pango:FontAwesome 9, Monospace 10  # Multiple fonts
}
```

### Bar Visibility

```bash
bar {
    mode dock              # Always visible
    mode hide              # Show on modifier press
    mode invisible         # Never shown
    hidden_state hide      # hide or show
    modifier Mod4          # Key to show/hide
}
```

### Status Command

```bash
bar {
    status_command i3status
    status_command i3status --config ~/.config/i3status/config
    status_command i3blocks
    status_command ~/bin/custom-status.sh
}
```

### Bar ID and Multiple Bars

```bash
bar {
    id bar-1
    position top
    output HDMI-1
}

bar {
    id bar-2
    position bottom
    output eDP-1
}

# Control bars with i3-msg
# i3-msg bar mode hide bar-1
```

### Separator Symbol

```bash
bar {
    separator_symbol " | "
    separator_symbol ""  # disable
}
```

## IPC Socket

```bash
ipc-socket ~/.i3/ipc.sock
ipc-socket /tmp/i3-ipc.sock
```

Most users don't need to set this.

## Automatic Startup

### Exec

Run once at startup:

```bash
exec firefox
exec --no-startup-id nm-applet
exec_always feh --bg-scale ~/wallpaper.png
```

- `exec` - Run on initial startup
- `exec_always` - Run on every restart
- `--no-startup-id` - Disable startup notification

### Example Startup Applications

```bash
exec --no-startup-id nm-applet
exec --no-startup-id picom
exec --no-startup-id dunst
exec --no-startup-id xss-lock -- i3lock -n
exec_always --no-startup-id ~/.config/polybar/launch.sh
```

## Multi-Monitor Configuration

### Output Commands

```bash
# Focus output
focus output left|right|up|down|primary
focus output HDMI-1

# Move to output
move container to output left|right|up|down|primary
move workspace to output left|right|up|down|primary
move container to output HDMI-1
move workspace to output VGA-1
```

## Advanced Configuration

### Force Xinerama

```bash
force_xinerama yes|no
force_xinerama no  # default
```

### Disable Focus Wrapping

```bash
force_focus_wrapping yes|no
force_focus_wrapping no  # deprecated, use focus_wrapping
```

### Show Marks

```bash
show_marks yes|no
show_marks yes  # default - show marks in window titles
```

## Complete Example Config

```bash
# i3 configuration file

# Set modifier key
set $mod Mod4

# Font
font pango:DejaVu Sans Mono 8

# Startup applications
exec --no-startup-id nm-applet
exec --no-startup-id picom
exec_always --no-startup-id feh --bg-scale ~/wallpaper.png

# Window appearance
default_border pixel 2
default_floating_border pixel 2
hide_edge_borders smart
gaps inner 5
gaps outer 2
smart_gaps on

# Colors
client.focused          #4c7899 #285577 #ffffff #2e9ef4 #285577
client.focused_inactive #333333 #5f676a #ffffff #484e50 #5f676a
client.unfocused        #333333 #222222 #888888 #292d2e #222222
client.urgent           #2f343a #900000 #ffffff #900000 #900000

# Behavior
focus_follows_mouse no
mouse_warping none
workspace_auto_back_and_forth yes
floating_modifier $mod

# Keybindings
bindsym $mod+Return exec alacritty
bindsym $mod+Shift+q kill
bindsym $mod+d exec rofi -show run

# Navigation
bindsym $mod+j focus left
bindsym $mod+k focus down
bindsym $mod+l focus up
bindsym $mod+semicolon focus right

# Movement
bindsym $mod+Shift+j move left
bindsym $mod+Shift+k move down
bindsym $mod+Shift+l move up
bindsym $mod+Shift+semicolon move right

# Layouts
bindsym $mod+s layout stacking
bindsym $mod+w layout tabbed
bindsym $mod+e layout toggle split
bindsym $mod+f fullscreen toggle
bindsym $mod+Shift+space floating toggle

# Workspaces
bindsym $mod+1 workspace number 1
bindsym $mod+2 workspace number 2
bindsym $mod+Shift+1 move container to workspace number 1
bindsym $mod+Shift+2 move container to workspace number 2

# Reload/restart
bindsym $mod+Shift+c reload
bindsym $mod+Shift+r restart
bindsym $mod+Shift+e exec "i3-nagbar -t warning -m 'Exit i3?' -B 'Yes' 'i3-msg exit'"

# Resize mode
mode "resize" {
    bindsym j resize shrink width 10 px or 10 ppt
    bindsym k resize grow height 10 px or 10 ppt
    bindsym l resize shrink height 10 px or 10 ppt
    bindsym semicolon resize grow width 10 px or 10 ppt

    bindsym Return mode "default"
    bindsym Escape mode "default"
}
bindsym $mod+r mode "resize"

# Bar
bar {
    status_command i3status
    position top

    colors {
        background #000000
        statusline #ffffff
        separator #666666

        focused_workspace  #4c7899 #285577 #ffffff
        active_workspace   #333333 #5f676a #ffffff
        inactive_workspace #333333 #222222 #888888
        urgent_workspace   #2f343a #900000 #ffffff
    }
}
```

For complete documentation, see [i3wm.org/docs/userguide.html](https://i3wm.org/docs/userguide.html).
