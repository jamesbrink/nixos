#!/usr/bin/env bash
set -euo pipefail

# Toggle macOS menu bar auto-hide setting

# Read current state
current=$(defaults read NSGlobalDomain _HIHideMenuBar 2>/dev/null || echo "0")

if [ "$current" = "1" ]; then
    # Currently hidden, make it visible
    echo "Making menu bar visible..."
    defaults write NSGlobalDomain _HIHideMenuBar -int 0
    defaults write NSGlobalDomain AppleMenuBarAutoHide -bool false
    defaults write com.apple.Dock autohide-menu-bar -bool false
    defaults write com.apple.controlcenter AutoHideMenuBarOption -int 3
else
    # Currently visible, hide it
    echo "Hiding menu bar..."
    defaults write NSGlobalDomain _HIHideMenuBar -int 1
    defaults write NSGlobalDomain AppleMenuBarAutoHide -bool true
    defaults write com.apple.Dock autohide-menu-bar -bool true
    defaults write com.apple.controlcenter AutoHideMenuBarOption -int 0
fi

# Apply changes
echo "Applying changes..."

# Post the same darwin notifications that System Preferences uses
if [ "$current" = "1" ]; then
    # Showing menu bar
    notifyutil -p com.apple.HIToolbox.showFrontMenuBar
else
    # Hiding menu bar
    notifyutil -p com.apple.HIToolbox.hideFrontMenuBar
fi

echo "Done!"
