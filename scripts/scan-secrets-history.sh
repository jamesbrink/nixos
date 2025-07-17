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
SINCE_COMMIT=""
BRANCH="HEAD"
MAX_DEPTH=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --since)
            SINCE_COMMIT="$2"
            shift 2
            ;;
        --branch)
            BRANCH="$2"
            shift 2
            ;;
        --max-depth)
            MAX_DEPTH="$2"
            shift 2
            ;;
        --help)
            cat << EOF
Usage: scan-secrets-history.sh [OPTIONS]

Deep scan git history for secrets with advanced options.

Options:
    --since COMMIT     Scan from a specific commit onwards
    --branch BRANCH    Scan a specific branch (default: HEAD)
    --max-depth N      Limit scan to N commits deep
    --help             Show this help message

Examples:
    scan-secrets-history.sh                        # Full history scan
    scan-secrets-history.sh --since abc1234        # Scan from commit abc1234
    scan-secrets-history.sh --branch develop       # Scan develop branch
    scan-secrets-history.sh --max-depth 100        # Scan last 100 commits

EOF
            exit 0
            ;;
        *)
            print_color "$RED" "Unknown option: $1"
            exit 1
            ;;
    esac
done

print_color "$YELLOW" "Starting deep git history scan for secrets..."
print_color "$BLUE" "Branch: $BRANCH"

# Build the git command
GIT_CMD="file://."
if [ -n "$SINCE_COMMIT" ]; then
    GIT_CMD="$GIT_CMD --since-commit=$SINCE_COMMIT"
fi
if [ -n "$MAX_DEPTH" ]; then
    GIT_CMD="$GIT_CMD --max-depth=$MAX_DEPTH"
fi

# Show scanning parameters
if [ -n "$SINCE_COMMIT" ]; then
    print_color "$BLUE" "Since commit: $SINCE_COMMIT"
fi
if [ -n "$MAX_DEPTH" ]; then
    print_color "$BLUE" "Max depth: $MAX_DEPTH commits"
fi
echo

print_color "$GREEN" "Scanning git history..."

# Create temporary exclude file
EXCLUDE_FILE=$(mktemp)
trap "rm -f $EXCLUDE_FILE" EXIT
cat > "$EXCLUDE_FILE" << 'EOF'
secrets/
nix-secrets/
nixos-old/
.git/
result
result-*
EOF

# Run TruffleHog with full history scan
if trufflehog git $GIT_CMD \
    --branch="$BRANCH" \
    --only-verified \
    --exclude-paths="$EXCLUDE_FILE"; then
    print_color "$GREEN" "✓ History scan completed successfully"
else
    print_color "$RED" "✗ Potential secrets found in git history!"
    print_color "$YELLOW" "Consider using git-filter-repo or BFG Repo-Cleaner to remove them"
    exit 1
fi