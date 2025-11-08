#!/usr/bin/env bash
# Test script for macOS dark mode switching

set -e

echo "=== macOS Dark Mode Test Script ==="
echo ""

# Function to check current dark mode status
check_dark_mode() {
    echo "Checking current dark mode status..."

    # Check via osascript
    OSASCRIPT_STATUS=$(osascript -e 'tell application "System Events" to tell appearance preferences to get dark mode')
    echo "  osascript reports: $OSASCRIPT_STATUS"

    # Check via defaults
    DEFAULTS_STATUS=$(defaults read NSGlobalDomain AppleInterfaceStyle 2>/dev/null || echo "Light")
    echo "  defaults reports: $DEFAULTS_STATUS"

    # Check System Preferences plist directly
    PLIST_STATUS=$(defaults read -g AppleInterfaceStyle 2>/dev/null || echo "Light")
    echo "  plist reports: $PLIST_STATUS"

    echo ""
}

# Initial status
echo "--- Initial State ---"
check_dark_mode

# Test 1: Enable dark mode
echo "--- Test 1: Enabling Dark Mode ---"
echo "Running: osascript + defaults write..."
osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to true'
defaults write NSGlobalDomain AppleInterfaceStyle -string "Dark"
sleep 1
check_dark_mode

echo "Restarting Dock and SystemUIServer..."
killall Dock 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true
sleep 2
check_dark_mode

# Test 2: Disable dark mode (light mode)
echo "--- Test 2: Enabling Light Mode ---"
echo "Running: osascript + defaults delete..."
osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to false'
defaults delete NSGlobalDomain AppleInterfaceStyle 2>/dev/null || true
sleep 1
check_dark_mode

echo "Restarting Dock and SystemUIServer..."
killall Dock 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true
sleep 2
check_dark_mode

# Test 3: Enable dark mode again
echo "--- Test 3: Re-enabling Dark Mode ---"
echo "Running: osascript + defaults write..."
osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to true'
defaults write NSGlobalDomain AppleInterfaceStyle -string "Dark"
sleep 1
check_dark_mode

echo "Restarting Dock and SystemUIServer..."
killall Dock 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true
sleep 2
check_dark_mode

echo "=== Test Complete ==="
echo ""
echo "If dark mode isn't switching visually:"
echo "1. Check System Settings > Appearance"
echo "2. Try manually toggling it there once"
echo "3. Check if 'Auto' mode is enabled (disable it)"
echo "4. Verify the script has accessibility permissions"
echo ""
echo "Current final state:"
check_dark_mode
