# i3 Window Manager User's Guide

## Overview

i3 is a tiling window manager designed for X11. This guide covers configuration, usage, and command syntax.

## 1. Default Keybindings

The default modifier key is Alt (Mod1), though the Windows key (Mod4) is a popular alternative.

**Basic Navigation:**

- `$mod+Enter` - Open terminal
- `$mod+j/k/l/;` - Navigate left/down/up/right
- `$mod+d` - Open dmenu application launcher

**Window Management:**

- `$mod+f` - Toggle fullscreen
- `$mod+Shift+q` - Close window
- `$mod+Shift+Space` - Toggle floating mode

## 2. Core Concepts

### Workspaces

Workspaces group windows logically. Switch between them with `$mod+num` (where num is 1-9).

> "Workspaces are an easy way to group a set of windows."

Move windows to workspaces using `$mod+Shift+num`.

### Splitting & Layouts

Create split containers before opening new windows:

- `$mod+v` - Vertical split
- `$mod+h` - Horizontal split

Layout modes:

- `$mod+e` - Toggle splith/splitv
- `$mod+s` - Stacking layout
- `$mod+w` - Tabbed layout

### Floating Windows

> "Floating mode is the opposite of tiling mode. The position and size of a window are not managed automatically by i3, but manually by you."

Toggle with `$mod+Shift+Space`. Move using titlebar or `$mod+mouse`.

## 3. Configuration

Configuration files are located at `~/.i3/config` or `~/.config/i3/config`.

### Basic Syntax

```bash
# Comments start with #
set $mod Mod1
bindsym $mod+Enter exec i3-sensible-terminal
```

### Variables

Define custom variables for cleaner configs:

```bash
set $mod Mod1
set $term urxvt
bindsym $mod+Return exec $term
```

### Include Directive

Since i3 v4.20, split configuration across files:

```bash
include ~/.config/i3/assignments.conf
include ~/.config/i3/config.d/*.conf
```

> "The include directive is suitable for organizing large configurations into separate files, possibly selecting files based on conditionals."

## 4. Keyboard Bindings

### Keysym vs Keycode

Use **keysyms** for readable configs when keyboard layout is stable. Use **keycodes** for fixed physical locations across layouts.

```bash
# Keysym binding
bindsym $mod+f fullscreen toggle

# Keycode binding
bindcode 214 exec /home/user/toggle_beamer.sh

# With modifiers
bindsym $mod+Shift+r restart

# Release flag for tools that grab keyboard
bindsym --release $mod+x exec xdotool key --clearmodifiers ctrl+v
```

Available modifiers: `Mod1-Mod5`, `Shift`, `Control`

### Binding Modes

Create custom input modes for related commands:

```bash
set $mode_launcher Launch: [f]irefox [t]hunderbird
bindsym $mod+o mode "$mode_launcher"

mode "$mode_launcher" {
    bindsym f exec firefox
    bindsym t exec thunderbird
    bindsym Escape mode "default"
    bindsym Return mode "default"
}
```

### Mouse Bindings

```bash
# Titlebar clicks
bindsym button1 nop
bindsym button3 floating toggle

# Whole window
bindsym --whole-window $mod+button2 kill
```

## 5. Window Management Commands

### Executing Applications

```bash
exec [--no-startup-id] <command>
exec_always [--no-startup-id] <command>
```

The `--no-startup-id` flag disables startup notification, useful for non-compliant applications.

```bash
bindsym $mod+g exec gimp
bindsym $mod+Return exec --no-startup-id urxvt
```

### Focus Commands

```bash
focus left|right|up|down
focus parent
focus child
focus output HDMI-2
focus output next
```

### Moving Containers

```bash
move left|right|up|down [amount px|ppt]
move position center
move position mouse
move container to workspace 3
move container to output HDMI-2
```

### Resizing

```bash
resize grow|shrink left|right|up|down [10 px]
resize set width 640 height 480
```

## 6. Workspaces

### Naming Workspaces

```bash
bindsym $mod+1 workspace 1: web
bindsym $mod+2 workspace 2: mail
bindsym $mod+Shift+1 move container to workspace 1: web
```

### Renaming Workspaces

```bash
rename workspace 5 to 6
rename workspace 1 to "1: www"
```

Use dynamic renaming:

```bash
bindsym $mod+r exec i3-input -F 'rename workspace to "%s"' \
    -P 'New name: '
```

### Workspace Assignment

Assign specific applications to workspaces:

```bash
assign [class="Firefox"] 2
assign [class="^Thunderbird$"] 3: mail
assign [class="Spotify"] → 4

# Assign to output
assign [class="URxvt"] → output HDMI1
```

## 7. Container Layout

### Default Border Styles

```bash
default_border normal|none|pixel
default_border pixel 2

default_floating_border normal|pixel
default_floating_border pixel 1
```

### Changing Colors

```bash
# Format: colorclass border background text indicator child_border
client.focused          #4c7899 #285577 #ffffff #2e9ef4 #285577
client.focused_inactive #333333 #5f676a #ffffff #484e50 #5f676a
client.unfocused        #333333 #222222 #888888 #292d2e #222222
client.urgent           #2f343a #900000 #ffffff #900000 #900000
```

### Gaps

Available since i3 v4.22:

```bash
# Inner gaps between windows
gaps inner 5px

# Outer gaps along screen edges
gaps outer 5px
gaps top 10px
gaps left 20px

# Per-workspace gaps
workspace 3 gaps inner 0

# Smart gaps - no gaps with single window
smart_gaps on
smart_gaps inverse_outer
```

## 8. Advanced Features

### Floating Modifier

Enable moving/resizing floating windows with keyboard:

```bash
floating_modifier Mod1
```

Hold Mod1 + left-click to move, right-click to resize.

### Tiling Drag

Configure mouse-based tiling container movement:

```bash
tiling_drag modifier titlebar
tiling_drag swap_modifier Shift
tiling_drag off  # disable entirely
```

### Marks (VIM-like Navigation)

Mark windows for quick navigation:

```bash
mark [--add|--replace] [--toggle] identifier
[con_mark="identifier"] focus
unmark identifier

# Interactive marking
bindsym $mod+m exec i3-input -F 'mark %s' -l 1 -P 'Mark: '
bindsym $mod+g exec i3-input -F '[con_mark="%s"] focus' -l 1 -P 'Goto: '
```

### Command Criteria

Match windows by properties for targeted commands:

```bash
[class="Firefox"] kill
[class="(?i)firefox"] kill  # case-insensitive
[window_role="About"] floating enable
[urgent=latest] focus
[workspace="1"] move workspace 2
```

Supported criteria: `all`, `class`, `instance`, `window_role`, `window_type`,
`machine`, `id`, `title`, `urgent`, `workspace`, `con_mark`, `con_id`,
`floating`, `floating_from`, `tiling`, `tiling_from`

### For Window Rules

Apply commands automatically to matching windows:

```bash
for_window [class="XTerm"] floating enable
for_window [class="urxvt"] border pixel 1
for_window [instance="notepad"] sticky enable
for_window [class="Gimp"] move to workspace 4
```

### Automatic Startup

```bash
exec chromium
exec_always ~/my_script.sh
exec --no-startup-id urxvt
```

## 9. i3bar Configuration

Configure the status bar within the main config:

```bash
bar {
    status_command i3status --config ~/.i3status.conf
    position top
    mode dock
    modifier Mod4
}
```

### Bar Display Modes

- `dock` - Always visible (default)
- `hide` - Appears on modifier press or urgency
- `invisible` - Never shown

```bash
bar {
    mode hide
    modifier Mod1
    hidden_state hide
}
```

### Workspace Buttons

```bash
bar {
    workspace_buttons yes
    strip_workspace_numbers no
    binding_mode_indicator yes
}
```

### Bar Colors

```bash
bar {
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

### Tray Icons

```bash
bar {
    tray_output primary
    tray_padding 2px
}

# Disable tray
bar {
    tray_output none
}
```

### Custom Separator

```bash
bar {
    separator_symbol ":|:"
}
```

## 10. Multi-Monitor Setup

### Output Assignment

```bash
workspace 1 output LVDS1
workspace 2 output HDMI1 VGA1  # uses first available
workspace "2: work" output primary
```

Relative positioning:

```bash
assign [class="URxvt"] → output right
assign [class="Firefox"] → output left
```

### Moving Between Outputs

```bash
move container to output next
move container to output HDMI-2
move container to output primary
```

Cycle through specific outputs:

```bash
move workspace to output HDMI1 LVDS1
```

## 11. Focus Behavior

### Focus Following Mouse

```bash
focus_follows_mouse yes  # default
focus_follows_mouse no
```

### Mouse Warping

Control cursor position when switching focus:

```bash
mouse_warping output   # default - warp to new window
mouse_warping none     # disable warping
```

### Focus Wrapping

```bash
focus_wrapping yes      # default - wrap at edges
focus_wrapping no       # stop at edges
focus_wrapping force    # always wrap
focus_wrapping workspace # wrap within workspace only
```

### Focus on Window Activation

Control which windows receive focus from external requests:

```bash
focus_on_window_activation smart|urgent|focus|none
focus_on_window_activation smart  # default
```

## 12. IPC Interface

i3 provides Unix socket communication for external programs:

```bash
ipc-socket ~/.i3/ipc-socket.sock
```

Query and control i3 via `i3-msg`:

```bash
i3-msg 'workspace 2'
i3-msg 'kill'
i3-msg '[class="Firefox"] focus'
```

## Quick Reference: Essential Bindings

| Action                   | Default Binding    |
| ------------------------ | ------------------ |
| New Terminal             | `$mod+Return`      |
| Kill Window              | `$mod+Shift+q`     |
| Focus Left/Down/Up/Right | `$mod+j/k/l/;`     |
| Fullscreen Toggle        | `$mod+f`           |
| Floating Toggle          | `$mod+Shift+Space` |
| Vertical Split           | `$mod+v`           |
| Horizontal Split         | `$mod+h`           |
| Restart i3               | `$mod+Shift+r`     |
| Exit i3                  | `$mod+Shift+e`     |
| Switch Workspace         | `$mod+[1-9]`       |
| Move to Workspace        | `$mod+Shift+[1-9]` |
| Stacking Layout          | `$mod+s`           |
| Tabbed Layout            | `$mod+w`           |

For comprehensive information, consult the official documentation at [i3wm.org/docs](https://i3wm.org/docs).
