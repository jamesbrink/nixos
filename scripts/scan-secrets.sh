#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
}

# Default values
MODE="git"
TARGET="."
EXCLUDE_PATHS="secrets/,nix-secrets/,nixos-old/,.git/,result,result-*"
ONLY_VERIFIED="--only-verified"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --filesystem)
            MODE="filesystem"
            shift
            ;;
        --all)
            ONLY_VERIFIED=""
            shift
            ;;
        --target)
            TARGET="$2"
            shift 2
            ;;
        --help)
            cat << EOF
Usage: scan-secrets.sh [OPTIONS]

Scan for secrets in the repository using TruffleHog.

Options:
    --filesystem     Scan filesystem instead of git history (default: git)
    --all            Show all potential secrets, not just verified ones
    --target PATH    Target path to scan (default: current directory)
    --help           Show this help message

Examples:
    scan-secrets.sh                    # Scan git history for verified secrets
    scan-secrets.sh --all              # Scan git history for all potential secrets
    scan-secrets.sh --filesystem       # Scan current filesystem
    scan-secrets.sh --target /path     # Scan specific path

EOF
            exit 0
            ;;
        *)
            print_color "$RED" "Unknown option: $1"
            exit 1
            ;;
    esac
done

print_color "$YELLOW" "Starting TruffleHog secret scan..."
print_color "$YELLOW" "Mode: $MODE"
print_color "$YELLOW" "Target: $TARGET"
if [ -n "$ONLY_VERIFIED" ]; then
    print_color "$YELLOW" "Showing: Verified secrets only"
else
    print_color "$YELLOW" "Showing: All potential secrets"
fi
echo

# Create temporary exclude file
EXCLUDE_FILE=$(mktemp)
trap "rm -f $EXCLUDE_FILE" EXIT

# Write exclude patterns to file
IFS=',' read -ra EXCLUDES <<< "$EXCLUDE_PATHS"
for path in "${EXCLUDES[@]}"; do
    echo "$path" >> "$EXCLUDE_FILE"
done

# Build exclude arguments
EXCLUDE_ARGS=""
if [ -s "$EXCLUDE_FILE" ]; then
    EXCLUDE_ARGS="--exclude-paths=$EXCLUDE_FILE"
fi

# Run TruffleHog based on mode
if [ "$MODE" == "git" ]; then
    print_color "$GREEN" "Scanning git history..."
    trufflehog git file://"$TARGET" $ONLY_VERIFIED $EXCLUDE_ARGS
else
    print_color "$GREEN" "Scanning filesystem..."
    trufflehog filesystem "$TARGET" $ONLY_VERIFIED $EXCLUDE_ARGS
fi

# Check exit code
if [ $? -eq 0 ]; then
    print_color "$GREEN" "✓ Scan completed successfully"
else
    print_color "$RED" "✗ Scan found potential issues or failed"
    exit 1
fi