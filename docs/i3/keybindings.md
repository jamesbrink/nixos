# i3 Window Manager - Keybindings Reference

## Default Modifier Key

The default modifier key is **Alt (Mod1)**. Many users prefer the **Windows/Command key (Mod4)** as an alternative.

To change the modifier in your config:

```bash
set $mod Mod1  # Alt key (default)
set $mod Mod4  # Windows/Command key
```

## Keybinding Syntax

### Using Keysyms (Recommended)

Keysyms are the symbolic names for keys, making configs human-readable:

```bash
bindsym $mod+Return exec i3-sensible-terminal
bindsym $mod+Shift+q kill
bindsym $mod+d exec dmenu_run
```

**Modifiers available:**

- `Mod1` - Alt key
- `Mod4` - Windows/Super/Command key
- `Shift` - Shift key
- `Control` - Control/Ctrl key
- `Mod2`, `Mod3`, `Mod5` - NumLock, etc.

### Using Keycodes

Keycodes are physical key positions, useful for layout-independent bindings:

```bash
bindcode $mod+44 exec dmenu_run  # 44 is 'j' key position
bindcode 214 exec /home/user/toggle_beamer.sh
```

Use `xev` or `xmodmap -pke` to discover keycodes.

### Multiple Modifiers

Combine multiple modifiers with `+`:

```bash
bindsym $mod+Shift+r restart
bindsym Control+$mod+x nop
bindsym $mod+Shift+Control+t exec special_tool
```

### Release Bindings

Execute commands on key release instead of press:

```bash
bindsym --release $mod+x exec xdotool key --clearmodifiers ctrl+v
bindsym --release Print exec scrot
```

Useful for screenshot tools and clipboard utilities.

### Border Control

Control when bindings activate based on window borders:

```bash
bindsym --border button1 nop
bindsym --exclude-titlebar button1 nop
bindsym --whole-window $mod+button2 kill
```

## Default Keybindings Reference

### Basic Navigation

| Keybinding   | Action                               |
| ------------ | ------------------------------------ |
| `$mod+Enter` | Open new terminal                    |
| `$mod+j`     | Focus left window                    |
| `$mod+k`     | Focus down window                    |
| `$mod+l`     | Focus up window                      |
| `$mod+;`     | Focus right window                   |
| `$mod+a`     | Focus parent container               |
| `$mod+Space` | Toggle focus between tiling/floating |

**Alternative navigation (arrow keys):**

```bash
bindsym $mod+Left focus left
bindsym $mod+Down focus down
bindsym $mod+Up focus up
bindsym $mod+Right focus right
```

### Moving Windows

| Keybinding     | Action            |
| -------------- | ----------------- |
| `$mod+Shift+j` | Move window left  |
| `$mod+Shift+k` | Move window down  |
| `$mod+Shift+l` | Move window up    |
| `$mod+Shift+;` | Move window right |

**Alternative (arrow keys):**

```bash
bindsym $mod+Shift+Left move left
bindsym $mod+Shift+Down move down
bindsym $mod+Shift+Up move up
bindsym $mod+Shift+Right move right
```

### Window Modification

| Keybinding         | Action                                        |
| ------------------ | --------------------------------------------- |
| `$mod+f`           | Toggle fullscreen mode                        |
| `$mod+v`           | Split window vertically (next window below)   |
| `$mod+h`           | Split window horizontally (next window right) |
| `$mod+r`           | Enter resize mode                             |
| `$mod+Shift+q`     | Close/kill focused window                     |
| `$mod+Shift+Space` | Toggle floating mode                          |

### Layout Control

| Keybinding | Layout Type                               |
| ---------- | ----------------------------------------- |
| `$mod+e`   | Toggle split layout (horizontal/vertical) |
| `$mod+s`   | Stacking layout                           |
| `$mod+w`   | Tabbed layout                             |

### Workspace Management

| Keybinding                            | Action                       |
| ------------------------------------- | ---------------------------- |
| `$mod+1` through `$mod+9`             | Switch to workspace 1-9      |
| `$mod+0`                              | Switch to workspace 10       |
| `$mod+Shift+1` through `$mod+Shift+9` | Move window to workspace 1-9 |
| `$mod+Shift+0`                        | Move window to workspace 10  |

**Example custom workspace bindings:**

```bash
bindsym $mod+1 workspace 1: web
bindsym $mod+2 workspace 2: mail
bindsym $mod+3 workspace 3: dev
bindsym $mod+Shift+1 move container to workspace 1: web
```

### Application Launcher

| Keybinding | Action                            |
| ---------- | --------------------------------- |
| `$mod+d`   | Open dmenu (application launcher) |

**Alternative launchers:**

```bash
bindsym $mod+d exec rofi -show run
bindsym $mod+d exec --no-startup-id i3-dmenu-desktop
```

### System Control

| Keybinding     | Action                                         |
| -------------- | ---------------------------------------------- |
| `$mod+Shift+c` | Reload i3 configuration file                   |
| `$mod+Shift+r` | Restart i3 in-place (preserves layout/session) |
| `$mod+Shift+e` | Exit i3 (with confirmation prompt)             |

**Exit binding example:**

```bash
bindsym $mod+Shift+e exec "i3-nagbar -t warning -m 'Exit i3?' -B 'Yes' 'i3-msg exit'"
```

### Resize Mode

Enter resize mode with `$mod+r`, then use:

| Key                  | Action           |
| -------------------- | ---------------- |
| `j` or `Left`        | Shrink width     |
| `k` or `Down`        | Grow height      |
| `l` or `Up`          | Shrink height    |
| `;` or `Right`       | Grow width       |
| `Return` or `Escape` | Exit resize mode |

**Resize mode configuration:**

```bash
mode "resize" {
    bindsym j resize shrink width 10 px or 10 ppt
    bindsym k resize grow height 10 px or 10 ppt
    bindsym l resize shrink height 10 px or 10 ppt
    bindsym semicolon resize grow width 10 px or 10 ppt

    # Arrow keys
    bindsym Left resize shrink width 10 px or 10 ppt
    bindsym Down resize grow height 10 px or 10 ppt
    bindsym Up resize shrink height 10 px or 10 ppt
    bindsym Right resize grow width 10 px or 10 ppt

    # Return to default mode
    bindsym Return mode "default"
    bindsym Escape mode "default"
}

bindsym $mod+r mode "resize"
```

## Mouse Bindings

### Basic Mouse Controls

| Binding            | Action                 |
| ------------------ | ---------------------- |
| `$mod+Left Click`  | Drag floating window   |
| `$mod+Right Click` | Resize floating window |

**Configuration:**

```bash
floating_modifier $mod

# Titlebar button bindings
bindsym --border button1 nop
bindsym --border button2 floating toggle
bindsym --border button3 nop

# Whole-window bindings
bindsym --whole-window $mod+button2 kill
bindsym --whole-window $mod+button3 floating toggle
```

### Mouse Button Numbers

| Button    | Description         |
| --------- | ------------------- |
| `button1` | Left mouse button   |
| `button2` | Middle mouse button |
| `button3` | Right mouse button  |
| `button4` | Scroll wheel up     |
| `button5` | Scroll wheel down   |

## Binding Modes

Create custom modes for related commands:

### Power Management Mode Example

```bash
set $mode_system System: (l) lock, (e) logout, (s) suspend, (r) reboot, (p) poweroff
mode "$mode_system" {
    bindsym l exec --no-startup-id i3lock, mode "default"
    bindsym e exec --no-startup-id i3-msg exit, mode "default"
    bindsym s exec --no-startup-id systemctl suspend, mode "default"
    bindsym r exec --no-startup-id systemctl reboot, mode "default"
    bindsym p exec --no-startup-id systemctl poweroff, mode "default"

    # Return to default mode
    bindsym Return mode "default"
    bindsym Escape mode "default"
}

bindsym $mod+Pause mode "$mode_system"
```

### Application Launcher Mode Example

```bash
set $mode_launcher Launch: [f]irefox [t]hunderbird [g]imp
bindsym $mod+o mode "$mode_launcher"

mode "$mode_launcher" {
    bindsym f exec firefox, mode "default"
    bindsym t exec thunderbird, mode "default"
    bindsym g exec gimp, mode "default"

    bindsym Escape mode "default"
    bindsym Return mode "default"
}
```

## Scratchpad Bindings

Move windows to/from the scratchpad (hidden workspace):

```bash
# Move current window to scratchpad
bindsym $mod+Shift+minus move scratchpad

# Show scratchpad window (or hide if already shown)
bindsym $mod+minus scratchpad show
```

## Advanced Keybinding Examples

### Mark and Jump (Vim-like)

```bash
# Mark current window
bindsym $mod+m exec i3-input -F 'mark %s' -l 1 -P 'Mark: '

# Jump to marked window
bindsym $mod+g exec i3-input -F '[con_mark="%s"] focus' -l 1 -P 'Goto: '
```

### Screenshot Bindings

```bash
# Full screen screenshot
bindsym Print exec --no-startup-id scrot '%Y-%m-%d_%H-%M-%S_$wx$h.png' -e 'mv $f ~/Pictures/'

# Window screenshot
bindsym $mod+Print exec --no-startup-id scrot -u '%Y-%m-%d_%H-%M-%S_$wx$h.png' -e 'mv $f ~/Pictures/'

# Selection screenshot
bindsym $mod+Shift+Print exec --no-startup-id scrot -s '%Y-%m-%d_%H-%M-%S_$wx$h.png' -e 'mv $f ~/Pictures/'
```

### Media Keys

```bash
# Volume control
bindsym XF86AudioRaiseVolume exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ +5%
bindsym XF86AudioLowerVolume exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ -5%
bindsym XF86AudioMute exec --no-startup-id pactl set-sink-mute @DEFAULT_SINK@ toggle

# Brightness control
bindsym XF86MonBrightnessUp exec --no-startup-id brightnessctl set +10%
bindsym XF86MonBrightnessDown exec --no-startup-id brightnessctl set 10%-

# Media playback
bindsym XF86AudioPlay exec --no-startup-id playerctl play-pause
bindsym XF86AudioNext exec --no-startup-id playerctl next
bindsym XF86AudioPrev exec --no-startup-id playerctl previous
```

## Quick Reference: Essential Syntax

```bash
# Basic binding
bindsym $mod+key_name command

# With modifiers
bindsym $mod+Shift+key_name command

# Release binding
bindsym --release $mod+key_name command

# Mouse binding
bindsym --whole-window $mod+button2 command

# Create mode
mode "mode_name" {
    bindsym key command
}
bindsym $mod+key mode "mode_name"
```

## Finding Key Names

Use `xev` to discover key names:

```bash
xev | grep keysym
```

Use `xmodmap` to see all keysym mappings:

```bash
xmodmap -pke
```

For comprehensive keybinding documentation, see the [i3 User Guide](https://i3wm.org/docs/userguide.html).
