# Yabai Window Manager Setup

Yabai is a tiling window manager for macOS that mirrors Hyprland functionality from our Linux setup.

## Configuration

- **Module**: `modules/darwin/yabai.nix`
- **Hotkeys**: SKHD (mirrors Hyprland keybindings)
- **Layout**: BSP (Binary Space Partitioning) - similar to Hyprland's dwindle

## Keybindings (Hyprland-compatible)

All keybindings use `cmd` (⌘) as the modifier (equivalent to Hyprland's `SUPER/mod` key).

### Applications

- `cmd + return` - Terminal (Alacritty)
- `cmd + shift + f` - File manager (Finder)
- `cmd + shift + b` - Browser (Chrome)
- `cmd + shift + m` - Spotify
- `cmd + shift + n` - Neovim (in Alacritty)
- `cmd + shift + t` - Btop (system monitor)
- `cmd + shift + o` - Obsidian
- `cmd + shift + y` - YouTube in Chrome

### Window Management

- `cmd + w` - Close window
- `cmd + t` - Toggle float
- `cmd + f` - Toggle fullscreen
- `cmd + ctrl + f` - Toggle native fullscreen
- `cmd + j` - Toggle split orientation

### Focus Windows

- `cmd + arrows` - Focus window in direction
- `alt + tab` - Cycle to next window
- `alt + shift + tab` - Cycle to previous window

### Move/Swap Windows

- `cmd + shift + arrows` - Swap windows in direction

### Workspaces (Spaces)

- `cmd + 1-9,0` - Switch to workspace
- `cmd + shift + 1-9,0` - Move window to workspace
- `cmd + tab` - Next workspace
- `cmd + shift + tab` - Previous workspace

### Window Resizing

- `cmd + -` - Decrease width
- `cmd + =` - Increase width
- `cmd + shift + -` - Decrease height
- `cmd + shift + =` - Increase height

### Layout Management

- `cmd + r` - Rotate tree 90°
- `cmd + x` - Mirror X-axis
- `cmd + y` - Mirror Y-axis
- `cmd + e` - Balance windows

### System

- `cmd + ctrl + r` - Restart yabai

## Features

### Working WITHOUT SIP Disabled:

- ✅ Window tiling (BSP layout)
- ✅ Window focus management
- ✅ Window swapping
- ✅ Workspace switching
- ✅ Window resizing
- ✅ Layout rotation/mirroring
- ✅ Opacity settings
- ✅ Gaps and padding
- ✅ Application rules

### Requires SIP Disabled:

- ❌ Window borders (colored)
- ❌ Window opacity changes (active)
- ❌ Scripting additions
- ❌ Window animations

## macOS Setup Requirements

### 1. Grant Accessibility Permissions

After deployment:

1. Open **System Settings** → **Privacy & Security** → **Accessibility**
2. Add and enable both:
   - `yabai`
   - `skhd`

### 2. Create Workspaces (Spaces)

Yabai needs existing workspaces to function:

1. Open **Mission Control** (F3 or swipe up with 3-4 fingers)
2. Click **+** at the top to create 10 spaces total
3. Go to **System Settings** → **Desktop & Dock** → **Mission Control**
4. Disable "Automatically rearrange Spaces based on most recent use"

### 3. Start Services

Services are managed by nix-darwin and will start automatically after deployment:

```bash
# Check status
launchctl list | grep yabai
launchctl list | grep skhd

# Manual restart if needed
launchctl kickstart -k "gui/${UID}/org.nixos.yabai"
launchctl kickstart -k "gui/${UID}/org.nixos.skhd"
```

## Disabling SIP (Optional - Advanced Features)

**Warning**: Disabling SIP reduces system security. Only do this if you understand the risks.

### Steps to Disable SIP:

1. Restart your Mac in Recovery Mode:

   - **Intel Mac**: Restart and hold `cmd + R`
   - **Apple Silicon**: Shutdown, then press and hold power button until "Loading startup options" appears

2. Open Terminal from the Utilities menu

3. Disable SIP:

   ```bash
   csrutil disable
   ```

4. Restart your Mac

5. Install scripting addition:

   ```bash
   sudo yabai --install-sa
   sudo yabai --load-sa
   ```

6. Verify:
   ```bash
   csrutil status  # Should show "disabled"
   ```

### After Disabling SIP:

Window borders and active opacity will work. The configuration already includes:

- Border width: 2px
- Active border: Tokyo Night blue (#7aa2f7)
- Inactive border: Dark gray (#3b4261)
- Active opacity: 0.97
- Inactive opacity: 0.90

## Troubleshooting

### Yabai not working

1. Check accessibility permissions
2. Verify services are running: `launchctl list | grep yabai`
3. Check logs: `tail -f /tmp/yabai_*.log`

### SKHD hotkeys not working

1. Check accessibility permissions for skhd
2. Verify service: `launchctl list | grep skhd`
3. Test manually: `skhd -V` (verbose mode)

### Windows not tiling

1. Ensure you have multiple spaces created
2. Some apps ignore tiling (see `manage=off` rules in config)
3. Check if window is floated: `cmd + t` to toggle

## Differences from Hyprland

| Feature            | Hyprland         | Yabai                    |
| ------------------ | ---------------- | ------------------------ |
| Compositor         | Wayland          | macOS Quartz             |
| Window borders     | Always available | Requires SIP disabled    |
| Animations         | Built-in         | Limited                  |
| Workspace creation | Dynamic          | Manual (Mission Control) |
| Gaps               | Configurable     | Configurable             |
| Transparency       | Full control     | Limited without SIP      |
| Rules              | Extensive        | Good                     |
| Status bar         | Waybar           | Need SketchyBar          |

## Next Steps

After yabai is working:

1. Consider adding SketchyBar for status bar (Waybar equivalent)
2. Configure additional window rules for your apps
3. Customize colors to match your theme system
4. Add window border color changes to theme cycling script
