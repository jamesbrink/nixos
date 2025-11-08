# macOS Theme System TODO

Goal: Match Linux Hyprland look and feel on macOS Darwin as closely as possible.

## High Priority

- [ ] **Yabai window manager** - Implement tiling window manager similar to Hyprland
  - [ ] Install and configure yabai via Homebrew
  - [ ] Configure SKHD for hotkey daemon (similar to Hyprland keybindings)
  - [ ] Window borders and focus indicators
  - [ ] Tiling layout rules
  - [ ] Workspace management

## In Progress

- [ ] **VSCode/Cursor theme switching** - Themes not applying despite JSONC fixes

  - JSONC parsing works but themes don't apply to running instances
  - May need to trigger VSCode reload or use different method

- [ ] **Finder appearance** - Does not update with light/dark mode changes
  - Finder colors/theme should match system appearance
  - May require additional defaults or Finder restart

## Completed ✓

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

- [ ] **Waybar equivalent** - Status bar with system info

  - Consider: SketchyBar, Übersicht, or custom solution
  - System stats (CPU, RAM, network)
  - Workspace indicators
  - Clock/date

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
