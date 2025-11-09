#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
}

# Default values
MODE="detect"
TARGET="."
CONFIG_FILE=""
VERBOSE=""
LOG_LEVEL="info"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --protect)
            MODE="protect"
            shift
            ;;
        --target)
            TARGET="$2"
            shift 2
            ;;
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE="--verbose"
            LOG_LEVEL="debug"
            shift
            ;;
        --baseline)
            MODE="baseline"
            shift
            ;;
        --help)
            cat << EOF
Usage: scan-gitleaks.sh [OPTIONS]

Scan for secrets using GitLeaks with various modes.

Options:
    --protect        Scan uncommitted changes (pre-commit mode)
    --baseline       Generate a baseline file for existing leaks
    --target PATH    Target repository path (default: current directory)
    --config FILE    Use custom gitleaks config file
    --verbose        Enable verbose output
    --help           Show this help message

Modes:
    detect (default) - Scan entire git history for secrets
    protect         - Scan uncommitted changes only
    baseline        - Create baseline of existing issues

Examples:
    scan-gitleaks.sh                      # Scan entire repository
    scan-gitleaks.sh --protect            # Scan uncommitted changes
    scan-gitleaks.sh --baseline           # Generate baseline file
    scan-gitleaks.sh --config custom.toml # Use custom config

EOF
            exit 0
            ;;
        *)
            print_color "$RED" "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Create default config if not provided
if [ -z "$CONFIG_FILE" ]; then
    CONFIG_FILE="/tmp/gitleaks-config-$$.toml"
    cat > "$CONFIG_FILE" << 'EOF'
# GitLeaks Configuration
title = "NixOS GitLeaks Config"

[extend]
useDefault = true

[allowlist]
description = "NixOS specific allowlist"
paths = [
    '''^secrets/''',
    '''^nix-secrets/''',
    '''^nixos-old/''',
    '''\.age$''',
    '''^result''',
    '''^result-''',
    '''flake\.lock$'''
]

# Ignore common Nix patterns
regexes = [
    '''/nix/store/[a-z0-9]{32}-'''
]
EOF
    trap 'rm -f "$CONFIG_FILE"' EXIT
fi

print_color "$YELLOW" "Starting GitLeaks scan..."
print_color "$BLUE" "Mode: $MODE"
print_color "$BLUE" "Target: $TARGET"
print_color "$BLUE" "Log level: $LOG_LEVEL"
echo

# Build the gitleaks command
GITLEAKS_CMD="gitleaks"

case "$MODE" in
    detect)
        print_color "$GREEN" "Scanning git history for secrets..."
        GITLEAKS_CMD="$GITLEAKS_CMD detect"
        ;;
    protect)
        print_color "$GREEN" "Scanning uncommitted changes..."
        GITLEAKS_CMD="$GITLEAKS_CMD protect"
        ;;
    baseline)
        print_color "$GREEN" "Generating baseline file..."
        GITLEAKS_CMD="$GITLEAKS_CMD detect --baseline-path=gitleaks-baseline.json"
        print_color "$YELLOW" "Baseline will be saved to: gitleaks-baseline.json"
        ;;
esac

# Add common options
GITLEAKS_CMD="$GITLEAKS_CMD --source=$TARGET --config=$CONFIG_FILE --log-level=$LOG_LEVEL $VERBOSE"

# Run GitLeaks
if eval "$GITLEAKS_CMD"; then
    print_color "$GREEN" "✓ GitLeaks scan completed successfully"
    if [ "$MODE" == "baseline" ]; then
        print_color "$YELLOW" "Baseline saved. Use --baseline-path=gitleaks-baseline.json in future scans"
    fi
else
    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 1 ]; then
        print_color "$RED" "✗ Secrets detected! Please review the findings above."
        print_color "$YELLOW" "To ignore false positives, update the config or use inline comments:"
        print_color "$YELLOW" "  # gitleaks:allow"
    else
        print_color "$RED" "✗ GitLeaks scan failed with error code: $EXIT_CODE"
    fi
    exit $EXIT_CODE
fi
