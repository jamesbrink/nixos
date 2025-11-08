# macOS Theme System TODO

Goal: Match Linux Hyprland look and feel on macOS Darwin as closely as possible.

## High Priority

- None currently - See Completed section for recently finished items

## Medium Priority

- [ ] **Karabiner-Elements configuration** - Configure advanced keyboard remapping

  - Already installed, needs configuration
  - More powerful than SKHD for complex mappings
  - Can layer on top of SKHD
  - Useful for Hyper key, per-app shortcuts

- [ ] **AltTab configuration** - Configure window previews

  - Already installed, needs configuration
  - Shows window previews (more visual than yabai's cycling)
  - Customizable appearance
  - https://alt-tab-macos.netlify.app/

- [ ] **CustomShortcuts or CheatSheet** - Keybindings overlay
  - Shows available shortcuts (like show-keybindings in Hyprland)
  - CheatSheet: Hold ⌘ to see app shortcuts
  - Could create custom overlay with SketchyBar

## Nice to Have

- [ ] **Übersicht** - Desktop widgets (alternative to SketchyBar)
  - More like Conky/eww
  - HTML/CSS/JS based widgets
  - Alternative approach to status bar if SketchyBar doesn't work out

## In Progress

- [ ] **VSCode/Cursor theme switching** - Themes not applying despite JSONC fixes

  - JSONC parsing works but themes don't apply to running instances
  - May need to trigger VSCode reload or use different method

- [ ] **Finder appearance** - Does not update with light/dark mode changes
  - Finder colors/theme should match system appearance
  - May require additional defaults or Finder restart

## Completed ✓

- [x] **SketchyBar** - Waybar equivalent status bar

  - Workspace indicators (1-10) on left
  - Window title display
  - Date/time in center
  - CPU/Memory/Network/Theme on right
  - Tokyo Night color scheme matching yabai
  - Integrates with yabai via signals
  - Configured in `modules/darwin/sketchybar.nix`

- [x] **Maccy** - Clipboard manager (cliphist equivalent)

  - Cmd+Shift+V hotkey for clipboard history
  - 200 item history with fuzzy search
  - Paste by default enabled
  - Configured in `modules/darwin/productivity-apps.nix`
  - **Note:** Hotkey must be set manually in Maccy preferences after first install

- [x] **AltTab** - Windows-style alt-tab with previews

  - Installed via `modules/darwin/productivity-apps.nix`
  - Configuration pending

- [x] **Karabiner-Elements** - Advanced keyboard remapping

  - Installed via `modules/darwin/productivity-apps.nix`
  - Configuration pending

- [x] **HOTKEYS.md** - macOS hotkeys documentation

  - Comprehensive Yabai/SKHD keybindings at top of file
  - Matches Hyprland reference section format
  - Documents all window management, workspace, and productivity hotkeys

- [x] **Yabai window manager** - Tiling window manager with Hyprland keybindings

  - BSP layout (similar to Hyprland's dwindle)
  - SKHD hotkey daemon with cmd as mod key
  - Window borders: 2px with Tokyo Night colors
  - Window opacity: active 0.97, inactive 0.90
  - Workspace management (1-10) - cmd+1 through cmd+0 working ✓
  - All Hyprland-compatible keybindings
  - Requires SIP disabled for borders/opacity
  - Scripting addition enabled with boot-args for workspace switching
  - Desktop icons hidden in BSP mode, shown in float mode
  - Dock auto-hides in BSP mode, visible in float mode
  - macOS menu bar hidden (SketchyBar replaces it)
  - Alacritty title bar hidden (buttonless decorations)

- [x] **Light/Dark mode switching** - System appearance changes work correctly

  - AppleInterfaceStyle preference
  - osascript appearance preferences

- [x] **Icon appearance (macOS Tahoe 26)** - Icons update with AppleIconAppearanceTheme

  - RegularLight for light themes
  - RegularDark for dark themes
  - ControlCenter restart for menu bar icons

- [x] **Alacritty theme cycling** - Terminal themes switch correctly

  - TOML color configuration
  - 0.97 opacity support

- [x] **Ghostty theme cycling** - Built-in theme names work

  - Theme mapping for all 12 themes
  - Background opacity support

- [x] **Neovim theme cycling** - Colorscheme updates via theme.lua

- [x] **Tmux theme cycling** - Status bar colors update dynamically

- [x] **Wallpaper switching** - Desktop backgrounds change per theme using desktoppr

- [x] **Hammerspoon integration** - Cmd+Shift+T hotkey for theme cycling

## Missing from Linux Hyprland Setup

### Window Management

- [x] **Waybar equivalent** - Status bar with system info

  - ✓ Implemented with SketchyBar
  - ✓ System stats (CPU, RAM, network)
  - ✓ Workspace indicators
  - ✓ Clock/date

- [ ] **Walker launcher** - Rofi/dmenu equivalent for macOS
  - Currently using Alfred (GUI)
  - Consider: Raycast API, custom solution

### GTK/Qt Theming

- [ ] **GTK theme support** - Not applicable on macOS (native Cocoa apps)

  - Some cross-platform apps (GIMP, Inkscape) use GTK
  - May need separate GTK configuration

- [ ] **Icon theme consistency** - SF Symbols vs custom icon packs
  - Hyprland uses Papirus/Tela icons
  - macOS uses SF Symbols (system icons)

### Additional Features

- [ ] **Dunst notifications** - Notification styling

  - macOS has native notification center
  - Limited customization available

- [ ] **Hyprpaper wallpapers** - Already handled by desktoppr

- [ ] **Terminal transparency** - Already implemented (0.97 opacity)

## Notes

- macOS limitations: Native Cocoa apps don't follow GTK themes
- Yabai requires SIP disabled for some features (borders, window manipulation)
- Some Hyprland features have no macOS equivalent (tiling, workspace animations)
- Consider using SketchyBar for comprehensive status bar similar to Waybar
