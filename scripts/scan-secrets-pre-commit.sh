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

print_color "$YELLOW" "Running pre-commit secret scan on staged files..."

# Get list of staged files
STAGED_FILES=$(git diff --cached --name-only)

if [ -z "$STAGED_FILES" ]; then
    print_color "$GREEN" "✓ No staged files to scan"
    exit 0
fi

# Create a temporary directory for scanning
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Copy staged files to temp directory
for file in $STAGED_FILES; do
    if [ -f "$file" ]; then
        mkdir -p "$TEMP_DIR/$(dirname "$file")"
        git show ":$file" > "$TEMP_DIR/$file" 2>/dev/null || true
    fi
done

# Run TruffleHog on the temporary directory
print_color "$GREEN" "Scanning staged files for secrets..."
trufflehog filesystem "$TEMP_DIR" --only-verified --no-update \
    --exclude-paths=secrets/ \
    --exclude-paths=nix-secrets/ \
    --exclude-paths=nixos-old/ \
    --exclude-paths=.git/ \
    --exclude-paths=result \
    --exclude-paths=result-*

# Check exit code
if [ $? -eq 0 ]; then
    print_color "$GREEN" "✓ No secrets detected in staged files"
    exit 0
else
    print_color "$RED" "✗ Potential secrets detected! Please review and remove them before committing."
    exit 1
fi