#!/bin/bash
# Simple toggle between BSP tiling and native macOS mode

STATE_FILE="$HOME/.bsp-mode-state"

# Check current mode from state file
if [ -f "$STATE_FILE" ]; then
    CURRENT_MODE=$(cat "$STATE_FILE")
else
    # Default to BSP if no state file
    CURRENT_MODE="bsp"
fi

echo "Current mode: $CURRENT_MODE"

if [ "$CURRENT_MODE" = "bsp" ]; then
    echo "==> Switching to NATIVE macOS mode"

    # Stop services via launchctl
    launchctl unload ~/Library/LaunchAgents/org.nixos.yabai.plist 2>/dev/null || true
    launchctl unload ~/Library/LaunchAgents/org.nixos.skhd.plist 2>/dev/null || true
    launchctl unload ~/Library/LaunchAgents/org.nixos.sketchybar.plist 2>/dev/null || true

    # Force kill any remaining processes
    killall yabai 2>/dev/null || true
    killall skhd 2>/dev/null || true
    killall sketchybar 2>/dev/null || true

    # Show macOS UI - completely remove the auto-hide setting
    defaults delete com.apple.NSGlobalDomain _HIHideMenuBar 2>/dev/null || true

    # Also ensure menu bar is set to always show (not auto-hide)
    defaults write NSGlobalDomain AppleMenuBarAutoHide -bool false 2>/dev/null || true
    defaults write com.apple.dock autohide -bool false
    defaults write com.apple.finder CreateDesktop -bool true

    # Apply changes - restart UI components in order
    killall Dock
    sleep 0.3
    killall Finder
    sleep 0.3
    killall SystemUIServer 2>/dev/null || true

    # Give UI time to restart
    sleep 1

    # Save state
    echo "macos" > "$STATE_FILE"

    osascript -e 'display notification "Native macOS mode" with title "Window Manager"'
    echo "✓ Switched to native macOS mode"

else
    echo "==> Switching to BSP TILING mode"

    # Hide macOS UI first
    defaults write com.apple.NSGlobalDomain _HIHideMenuBar -bool true
    defaults write com.apple.dock autohide -bool true
    defaults write com.apple.finder CreateDesktop -bool false

    # Apply changes
    killall Dock
    killall Finder
    killall SystemUIServer

    # Start services via launchctl (ensures proper config loading)
    launchctl load -w ~/Library/LaunchAgents/org.nixos.sketchybar.plist 2>/dev/null || true
    launchctl load -w ~/Library/LaunchAgents/org.nixos.yabai.plist 2>/dev/null || true
    launchctl load -w ~/Library/LaunchAgents/org.nixos.skhd.plist 2>/dev/null || true

    sleep 2

    # Save state
    echo "bsp" > "$STATE_FILE"

    osascript -e 'display notification "BSP tiling mode" with title "Window Manager"'
    echo "✓ Switched to BSP tiling mode"
fi
