#!/usr/bin/env bash
# Test script for theme cycling without deploying
# Usage: ./test-theme-cycle.sh [theme-name] [--apply]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME_NAME="${1:-tokyo-night}"
APPLY_CHANGES="${2:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Theme Cycling Test Script ===${NC}"
echo -e "Theme: ${YELLOW}$THEME_NAME${NC}"
echo -e "Mode: $([ "$APPLY_CHANGES" = "--apply" ] && echo "${GREEN}APPLY${NC}" || echo "${YELLOW}DRY-RUN${NC}")"
echo ""

# Check if theme exists
THEME_FILE="$SCRIPT_DIR/modules/home-manager/hyprland/themes/$THEME_NAME.nix"
if [[ ! -f "$THEME_FILE" ]]; then
    echo -e "${RED}Error: Theme file not found: $THEME_FILE${NC}"
    echo ""
    echo "Available themes:"
    for theme in "$SCRIPT_DIR/modules/home-manager/hyprland/themes"/*.nix; do
        basename "$theme" .nix
    done
    exit 1
fi

# Test 1: VSCode/Cursor theme mapping
echo -e "${BLUE}--- Test 1: VSCode/Cursor Theme Mapping ---${NC}"

# Use the deployed vscode-themes.json if available
VSCODE_THEMES_FILE="$HOME/.config/themes/vscode-themes.json"
if [[ -f "$VSCODE_THEMES_FILE" ]]; then
    VSCODE_THEME=$(jq -r ".[\"$THEME_NAME\"]" "$VSCODE_THEMES_FILE")
else
    # Fallback to hardcoded mapping
    case "$THEME_NAME" in
        tokyo-night) VSCODE_THEME="Tokyo Night" ;;
        catppuccin) VSCODE_THEME="Catppuccin Mocha" ;;
        catppuccin-latte) VSCODE_THEME="Catppuccin Latte" ;;
        gruvbox) VSCODE_THEME="Gruvbox Dark Hard" ;;
        nord) VSCODE_THEME="Nord" ;;
        rose-pine) VSCODE_THEME="Rosé Pine" ;;
        everforest) VSCODE_THEME="Everforest Dark" ;;
        kanagawa) VSCODE_THEME="Kanagawa" ;;
        matte-black) VSCODE_THEME="One Dark Pro Darker" ;;
        osaka-jade) VSCODE_THEME="Tokyo Night" ;;
        ristretto) VSCODE_THEME="Monokai Pro (Filter Ristretto)" ;;
        flexoki-light) VSCODE_THEME="Flexoki Light" ;;
        *) VSCODE_THEME="Unknown" ;;
    esac
fi
echo -e "${GREEN}VSCode theme for $THEME_NAME: $VSCODE_THEME${NC}"
echo ""

# Test 2: VSCode settings.json update
echo -e "${BLUE}--- Test 2: VSCode Settings Update ---${NC}"

VSCODE_SETTINGS="$HOME/Library/Application Support/Code/User/settings.json"
if [[ -f "$VSCODE_SETTINGS" ]]; then
    echo "Current VSCode theme:"
    jq -r '.["workbench.colorTheme"] // "Not set"' <(grep -v '^\s*//' "$VSCODE_SETTINGS") 2>/dev/null || echo "Error parsing settings"

    echo ""
    echo "Testing JSONC -> JSON conversion and theme update:"

    # Strip comments and apply theme
    TEMP_SETTINGS=$(mktemp)
    grep -v '^\s*//' "$VSCODE_SETTINGS" > "$TEMP_SETTINGS"

    # Test jq command
    if jq --arg theme "$VSCODE_THEME" '.["workbench.colorTheme"] = $theme' "$TEMP_SETTINGS" > "${TEMP_SETTINGS}.new"; then
        echo -e "${GREEN}✓ jq command succeeded${NC}"

        # Show diff
        echo ""
        echo "Changes that would be made:"
        diff -u <(jq '.["workbench.colorTheme"]' "$TEMP_SETTINGS" 2>/dev/null || echo "null") \
                <(jq '.["workbench.colorTheme"]' "${TEMP_SETTINGS}.new" 2>/dev/null || echo "null") || true

        if [[ "$APPLY_CHANGES" = "--apply" ]]; then
            cp "${TEMP_SETTINGS}.new" "$VSCODE_SETTINGS"
            echo -e "${GREEN}✓ Applied changes to VSCode settings${NC}"
        fi
    else
        echo -e "${RED}✗ jq command failed${NC}"
    fi

    rm -f "$TEMP_SETTINGS" "${TEMP_SETTINGS}.new"
else
    echo -e "${YELLOW}VSCode settings not found${NC}"
fi
echo ""

# Test 3: Cursor settings.json update
echo -e "${BLUE}--- Test 3: Cursor Settings Update ---${NC}"

CURSOR_SETTINGS="$HOME/Library/Application Support/Cursor/User/settings.json"
if [[ -f "$CURSOR_SETTINGS" ]]; then
    echo "Current Cursor theme:"
    jq -r '.["workbench.colorTheme"] // "Not set"' <(grep -v '^\s*//' "$CURSOR_SETTINGS") 2>/dev/null || echo "Error parsing settings"

    echo ""
    echo "Testing JSONC -> JSON conversion and theme update:"

    # Strip comments and apply theme
    TEMP_SETTINGS=$(mktemp)
    grep -v '^\s*//' "$CURSOR_SETTINGS" > "$TEMP_SETTINGS"

    # Test jq command
    if jq --arg theme "$VSCODE_THEME" '.["workbench.colorTheme"] = $theme' "$TEMP_SETTINGS" > "${TEMP_SETTINGS}.new"; then
        echo -e "${GREEN}✓ jq command succeeded${NC}"

        # Show diff
        echo ""
        echo "Changes that would be made:"
        diff -u <(jq '.["workbench.colorTheme"]' "$TEMP_SETTINGS" 2>/dev/null || echo "null") \
                <(jq '.["workbench.colorTheme"]' "${TEMP_SETTINGS}.new" 2>/dev/null || echo "null") || true

        if [[ "$APPLY_CHANGES" = "--apply" ]]; then
            cp "${TEMP_SETTINGS}.new" "$CURSOR_SETTINGS"
            echo -e "${GREEN}✓ Applied changes to Cursor settings${NC}"
        fi
    else
        echo -e "${RED}✗ jq command failed${NC}"
    fi

    rm -f "$TEMP_SETTINGS" "${TEMP_SETTINGS}.new"
else
    echo -e "${YELLOW}Cursor settings not found${NC}"
fi
echo ""

# Test 4: Dark mode and icon appearance detection (macOS Tahoe 26)
echo -e "${BLUE}--- Test 4: Dark Mode and Icon Appearance ---${NC}"

if [[ "$THEME_NAME" =~ (latte|light) ]]; then
    echo -e "Theme is light mode: ${GREEN}YES${NC}"
    EXPECTED_MODE="light"
    EXPECTED_ICON_THEME="RegularLight"
else
    echo -e "Theme is dark mode: ${GREEN}YES${NC}"
    EXPECTED_MODE="dark"
    EXPECTED_ICON_THEME="RegularDark"
fi

# Check current dark mode (empty string means light mode)
DARK_MODE_VALUE=$(defaults read NSGlobalDomain AppleInterfaceStyle 2>/dev/null || echo "")
if [[ -n "$DARK_MODE_VALUE" ]]; then
    CURRENT_MODE="dark"
else
    CURRENT_MODE="light"
fi

# Check current icon appearance theme (macOS Tahoe 26)
CURRENT_ICON_THEME=$(defaults read NSGlobalDomain AppleIconAppearanceTheme 2>/dev/null || echo "Not set")

echo "Current macOS appearance: $CURRENT_MODE"
echo "Current icon theme: $CURRENT_ICON_THEME"

NEEDS_UPDATE=false

if [[ "$CURRENT_MODE" != "$EXPECTED_MODE" ]]; then
    echo -e "${YELLOW}⚠ macOS appearance doesn't match theme${NC}"
    NEEDS_UPDATE=true
fi

if [[ "$CURRENT_ICON_THEME" != "$EXPECTED_ICON_THEME" ]]; then
    echo -e "${YELLOW}⚠ Icon appearance doesn't match theme${NC}"
    NEEDS_UPDATE=true
fi

if [[ "$NEEDS_UPDATE" = true ]]; then
    if [[ "$APPLY_CHANGES" = "--apply" ]]; then
        if [[ "$EXPECTED_MODE" = "dark" ]]; then
            osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to true'
            defaults write NSGlobalDomain AppleInterfaceStyle -string "Dark"
            defaults write NSGlobalDomain AppleIconAppearanceTheme -string "RegularDark"
            echo -e "${GREEN}✓ Switched to dark mode with dark icons${NC}"
        else
            osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to false'
            defaults delete NSGlobalDomain AppleInterfaceStyle 2>/dev/null || true
            defaults write NSGlobalDomain AppleIconAppearanceTheme -string "RegularLight"
            echo -e "${GREEN}✓ Switched to light mode with light icons${NC}"
        fi
    fi
else
    echo -e "${GREEN}✓ Appearance and icons match theme${NC}"
fi
echo ""

# Test 5: Ghostty theme mapping
echo -e "${BLUE}--- Test 5: Ghostty Theme Mapping ---${NC}"

GHOSTTY_MAP='{
  "catppuccin-latte": "catppuccin-latte",
  "catppuccin": "catppuccin-mocha",
  "everforest": "Everforest Dark",
  "flexoki-light": "Flexoki Light",
  "gruvbox": "GruvboxDark",
  "kanagawa": "Kanagawa",
  "matte-black": "Darcula",
  "nord": "nord",
  "osaka-jade": "Material",
  "ristretto": "Monokai Pro Ristretto",
  "rose-pine": "Rosé Pine",
  "tokyo-night": "Tokyo Night"
}'

GHOSTTY_THEME=$(echo "$GHOSTTY_MAP" | jq -r ".[\"$THEME_NAME\"]")
echo -e "${GREEN}Ghostty theme for $THEME_NAME: $GHOSTTY_THEME${NC}"

GHOSTTY_CONFIG="$HOME/.config/ghostty/config"
if [[ -f "$GHOSTTY_CONFIG" ]]; then
    CURRENT_GHOSTTY=$(grep '^theme = ' "$GHOSTTY_CONFIG" | sed 's/theme = //')
    echo "Current Ghostty theme: $CURRENT_GHOSTTY"

    if [[ "$CURRENT_GHOSTTY" != "$GHOSTTY_THEME" && "$APPLY_CHANGES" = "--apply" ]]; then
        if grep -q "^theme = " "$GHOSTTY_CONFIG"; then
            sed -i.bak "s|^theme = .*|theme = $GHOSTTY_THEME|" "$GHOSTTY_CONFIG"
        else
            echo "theme = $GHOSTTY_THEME" >> "$GHOSTTY_CONFIG"
        fi
        echo -e "${GREEN}✓ Updated Ghostty theme${NC}"
    fi
fi
echo ""

# Summary
echo -e "${BLUE}=== Test Summary ===${NC}"
if [[ "$APPLY_CHANGES" = "--apply" ]]; then
    echo -e "${GREEN}✓ Changes applied${NC}"
    echo "Restart Dock and SystemUIServer to see changes:"
    echo "  killall Dock; killall SystemUIServer"
else
    echo -e "${YELLOW}Dry-run mode - no changes applied${NC}"
    echo "Run with --apply to make changes:"
    echo "  ./test-theme-cycle.sh $THEME_NAME --apply"
fi
echo ""
