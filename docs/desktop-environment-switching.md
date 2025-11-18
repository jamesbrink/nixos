# Desktop Environment Switching Guide

This guide shows how to easily switch between desktop environments in your NixOS configuration.

## Available Desktop Profiles

- **GNOME** (default): `profiles/desktop/default.nix` or `profiles/desktop/default-stable.nix`
- **Hyprland**: `profiles/desktop/hyprland.nix`

## How to Switch Desktop Environments

### Method 1: Edit Host Configuration

In your host configuration file (e.g., `hosts/alienware/default.nix`), change the import:

**For GNOME:**

```nix
imports = [
  ../../profiles/desktop/default.nix  # or default-stable.nix
  # ... other imports
];
```

**For Hyprland:**

```nix
imports = [
  ../../profiles/desktop/hyprland.nix
  # ... other imports
];
```

### Method 2: Quick Command Line Switch

```bash
# Switch to Hyprland on alienware
sed -i 's|profiles/desktop/default.nix|profiles/desktop/hyprland.nix|' hosts/alienware/default.nix

# Switch back to GNOME
sed -i 's|profiles/desktop/hyprland.nix|profiles/desktop/default.nix|' hosts/alienware/default.nix
```

### Deploy the Changes

After changing the desktop profile:

```bash
# Format the configuration
format

# Test the deployment
deploy-test alienware

# Deploy the changes
deploy alienware
```

### Reboot

After deployment, reboot to use the new desktop environment:

```bash
ssh alienware sudo reboot
```

## Desktop Profile Comparison

| Feature          | GNOME       | Hyprland        |
| ---------------- | ----------- | --------------- |
| Display Protocol | X11/Wayland | Wayland only    |
| Display Manager  | GDM         | SDDM            |
| Resource Usage   | Higher      | Lower           |
| Customization    | Moderate    | High            |
| Tiling           | No (manual) | Yes (automatic) |
| Stability        | Very stable | Stable          |
| Remote Desktop   | xRDP        | Screen sharing  |

## Hyprland Configuration

After switching to Hyprland, you'll need to configure it. The default config location is:

- System: `/etc/hypr/hyprland.conf` (if configured system-wide)
- User: `~/.config/hypr/hyprland.conf` (recommended)

### Example User Config

Create `~/.config/hypr/hyprland.conf`:

```conf
# Monitor configuration
monitor=,preferred,auto,1

# Execute apps at launch
exec-once = waybar
exec-once = dunst
exec-once = hyprpaper
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1

# Input configuration
input {
    kb_layout = us
    follow_mouse = 1
    touchpad {
        natural_scroll = true
    }
    sensitivity = 0
}

# General settings
general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
    col.inactive_border = rgba(595959aa)
    layout = dwindle
}

# Decoration
decoration {
    rounding = 8
    blur {
        enabled = true
        size = 3
        passes = 1
    }
    drop_shadow = true
    shadow_range = 4
    shadow_render_power = 3
    col.shadow = rgba(1a1a1aee)
}

# Animations
animations {
    enabled = true
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    animation = windows, 1, 7, myBezier
    animation = windowsOut, 1, 7, default, popin 80%
    animation = border, 1, 10, default
    animation = borderangle, 1, 8, default
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}

# Layout
dwindle {
    pseudotile = true
    preserve_split = true
}

# Key bindings
$mainMod = SUPER

# Applications
bind = $mainMod, RETURN, exec, alacritty
bind = $mainMod, Q, killactive,
bind = $mainMod, M, exit,
bind = $mainMod, E, exec, thunar
bind = $mainMod, V, togglefloating,
bind = $mainMod, D, exec, rofi -show drun
bind = $mainMod, P, pseudo,
bind = $mainMod, J, togglesplit,

# Move focus
bind = $mainMod, left, movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up, movefocus, u
bind = $mainMod, down, movefocus, d

# Switch workspaces
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod, 6, workspace, 6
bind = $mainMod, 7, workspace, 7
bind = $mainMod, 8, workspace, 8
bind = $mainMod, 9, workspace, 9
bind = $mainMod, 0, workspace, 10

# Move active window to workspace
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5
bind = $mainMod SHIFT, 6, movetoworkspace, 6
bind = $mainMod SHIFT, 7, movetoworkspace, 7
bind = $mainMod SHIFT, 8, movetoworkspace, 8
bind = $mainMod SHIFT, 9, movetoworkspace, 9
bind = $mainMod SHIFT, 0, movetoworkspace, 10

# Mouse bindings
bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow

# Screenshots
bind = , PRINT, exec, hyprshot -m region
bind = SHIFT, PRINT, exec, hyprshot -m window
bind = CTRL, PRINT, exec, hyprshot -m output

# Volume control
bind = , XF86AudioRaiseVolume, exec, pamixer -i 5
bind = , XF86AudioLowerVolume, exec, pamixer -d 5
bind = , XF86AudioMute, exec, pamixer -t

# Brightness control
bind = , XF86MonBrightnessUp, exec, brightnessctl set +10%
bind = , XF86MonBrightnessDown, exec, brightnessctl set 10%-
```

## Tips

- **GNOME to Hyprland**: You'll need to configure Hyprland manually, but you'll get better tiling and performance
- **Hyprland to GNOME**: All GNOME settings are preserved in dconf/gsettings
- **Keep both**: You can install both profiles and choose at login (not recommended for production)
